defmodule Zvex.DocumentIntegrationTest do
  use ExUnit.Case, async: false

  import Zvex.TestDir

  alias Zvex.Collection
  alias Zvex.Collection.Schema
  alias Zvex.Document
  alias Zvex.Vector

  setup_all do
    Zvex.initialize()
    on_exit(fn -> if Zvex.initialized?(), do: Zvex.shutdown() end)
    :ok
  end

  setup :create_test_dir

  defp test_schema do
    Schema.new("test_collection")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32, dimension: 4)
    |> Schema.add_field("title", :string, nullable: true)
  end

  defp build_doc(id, embedding_values, title \\ nil) do
    doc =
      Document.new()
      |> Document.put_pk(id)
      |> Document.put("id", id)
      |> Document.put("embedding", Vector.from_list(embedding_values, :fp32))

    if title, do: Document.put(doc, "title", title), else: doc
  end

  defp create_collection(%{test_dir: test_dir}) do
    path = Path.join(test_dir, "coll")
    {:ok, coll} = Collection.create(path, test_schema())
    on_exit(fn -> Collection.close(coll) end)
    %{collection: coll}
  end

  describe "insert + fetch round-trip" do
    setup [:create_collection]

    test "single doc insert and fetch preserves pk and fields", %{collection: coll} do
      doc = build_doc("doc-1", [1.0, 2.0, 3.0, 4.0], "Hello")

      assert {:ok, %{success: 1, errors: 0}} = Document.insert(coll, doc)

      assert {:ok, [fetched]} = Document.fetch(coll, ["doc-1"])
      assert %Document{pk: "doc-1"} = fetched
      assert {"title", {:string, "Hello"}} in Enum.to_list(fetched.fields)
    end
  end

  describe "batch insert" do
    setup [:create_collection]

    test "inserts multiple docs and fetches all", %{collection: coll} do
      docs =
        for i <- 1..5 do
          build_doc("batch-#{i}", [1.0, 2.0, 3.0, Float.parse("#{i}.0") |> elem(0)])
        end

      assert {:ok, %{success: 5, errors: 0}} = Document.insert(coll, docs)

      pks = Enum.map(1..5, &"batch-#{&1}")
      assert {:ok, fetched} = Document.fetch(coll, pks)
      assert length(fetched) == 5
    end
  end

  describe "insert_with_results" do
    setup [:create_collection]

    test "returns per-doc result codes", %{collection: coll} do
      doc = build_doc("res-1", [1.0, 2.0, 3.0, 4.0])

      assert {:ok, results} = Document.insert_with_results(coll, doc)
      assert is_list(results)
      assert [%{code: :ok}] = results
    end
  end

  describe "update + fetch" do
    setup [:create_collection]

    test "updates title and fetch reflects change", %{collection: coll} do
      doc = build_doc("upd-1", [1.0, 2.0, 3.0, 4.0], "Original")
      {:ok, _} = Document.insert(coll, doc)

      updated = build_doc("upd-1", [1.0, 2.0, 3.0, 4.0], "Updated")
      assert {:ok, %{success: 1, errors: 0}} = Document.update(coll, updated)

      assert {:ok, [fetched]} = Document.fetch(coll, ["upd-1"])
      assert {"title", {:string, "Updated"}} in Enum.to_list(fetched.fields)
    end
  end

  describe "upsert" do
    setup [:create_collection]

    test "inserts new and updates existing", %{collection: coll} do
      doc1 = build_doc("ups-1", [1.0, 2.0, 3.0, 4.0], "First")
      {:ok, _} = Document.insert(coll, doc1)

      updated1 = build_doc("ups-1", [1.0, 2.0, 3.0, 4.0], "FirstUpdated")
      new2 = build_doc("ups-2", [5.0, 6.0, 7.0, 8.0], "Second")
      assert {:ok, %{success: 2, errors: 0}} = Document.upsert(coll, [updated1, new2])

      assert {:ok, fetched} = Document.fetch(coll, ["ups-1", "ups-2"])
      assert length(fetched) == 2

      ups1 = Enum.find(fetched, &(&1.pk == "ups-1"))
      assert {"title", {:string, "FirstUpdated"}} in Enum.to_list(ups1.fields)
    end
  end

  describe "delete by pk" do
    setup [:create_collection]

    test "deletes a doc and fetch returns empty", %{collection: coll} do
      doc = build_doc("del-1", [1.0, 2.0, 3.0, 4.0])
      {:ok, _} = Document.insert(coll, doc)

      assert {:ok, %{success: 1, errors: 0}} = Document.delete(coll, ["del-1"])

      assert {:ok, []} = Document.fetch(coll, ["del-1"])
    end
  end

  describe "delete_with_results" do
    setup [:create_collection]

    test "returns per-pk result list", %{collection: coll} do
      doc = build_doc("delr-1", [1.0, 2.0, 3.0, 4.0])
      {:ok, _} = Document.insert(coll, doc)

      assert {:ok, results} = Document.delete_with_results(coll, ["delr-1"])
      assert is_list(results)
      assert [%{code: :ok}] = results
    end
  end

  describe "delete_by_filter" do
    setup [:create_collection]

    test "deletes docs matching filter", %{collection: coll} do
      doc1 = build_doc("filt-1", [1.0, 2.0, 3.0, 4.0], "keep")
      doc2 = build_doc("filt-2", [5.0, 6.0, 7.0, 8.0], "remove")
      {:ok, _} = Document.insert(coll, [doc1, doc2])

      assert :ok = Document.delete_by_filter(coll, "title = 'remove'")

      assert {:ok, remaining} = Document.fetch(coll, ["filt-1", "filt-2"])
      remaining_pks = Enum.map(remaining, & &1.pk)
      assert "filt-1" in remaining_pks
      refute "filt-2" in remaining_pks
    end
  end

  describe "fetch non-existent pk" do
    setup [:create_collection]

    test "returns empty list", %{collection: coll} do
      assert {:ok, []} = Document.fetch(coll, ["nonexistent"])
    end
  end

  describe "error paths" do
    test "insert on closed collection returns error", %{test_dir: test_dir} do
      path = Path.join(test_dir, "closed_coll")
      {:ok, coll} = Collection.create(path, test_schema())
      Collection.close(coll)
      coll = %{coll | closed: true}

      doc = build_doc("err-1", [1.0, 2.0, 3.0, 4.0])
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Document.insert(coll, doc)
    end
  end

  describe "bang variants" do
    setup [:create_collection]

    test "insert! returns result map directly", %{collection: coll} do
      doc = build_doc("bang-1", [1.0, 2.0, 3.0, 4.0])
      assert %{success: 1, errors: 0} = Document.insert!(coll, doc)
    end

    test "fetch! returns docs directly", %{collection: coll} do
      doc = build_doc("bang-2", [1.0, 2.0, 3.0, 4.0], "BangTest")
      Document.insert!(coll, doc)

      assert [%Document{pk: "bang-2"}] = Document.fetch!(coll, ["bang-2"])
    end

    test "insert_with_results! returns results directly", %{collection: coll} do
      doc = build_doc("bangr-1", [1.0, 2.0, 3.0, 4.0])
      assert [%{code: :ok}] = Document.insert_with_results!(coll, doc)
    end

    test "update! returns result map directly", %{collection: coll} do
      doc = build_doc("bangu-1", [1.0, 2.0, 3.0, 4.0])
      Document.insert!(coll, doc)

      updated = build_doc("bangu-1", [1.0, 2.0, 3.0, 4.0], "Updated")
      assert %{success: 1, errors: 0} = Document.update!(coll, updated)
    end

    test "upsert! returns result map directly", %{collection: coll} do
      doc = build_doc("bangups-1", [1.0, 2.0, 3.0, 4.0])
      assert %{success: 1, errors: 0} = Document.upsert!(coll, doc)
    end

    test "delete! returns result map directly", %{collection: coll} do
      doc = build_doc("bangd-1", [1.0, 2.0, 3.0, 4.0])
      Document.insert!(coll, doc)

      assert %{success: 1, errors: 0} = Document.delete!(coll, ["bangd-1"])
    end

    test "delete_by_filter! returns :ok", %{collection: coll} do
      doc = build_doc("bangf-1", [1.0, 2.0, 3.0, 4.0], "test")
      Document.insert!(coll, doc)

      assert :ok = Document.delete_by_filter!(coll, "title = 'test'")
    end
  end
end
