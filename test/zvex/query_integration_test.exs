defmodule Zvex.QueryIntegrationTest do
  use ExUnit.Case, async: false

  import Zvex.TestDir

  alias Zvex.Collection
  alias Zvex.Collection.Schema
  alias Zvex.Document
  alias Zvex.Query
  alias Zvex.Vector

  setup_all do
    Zvex.initialize()
    on_exit(fn -> if Zvex.initialized?(), do: Zvex.shutdown() end)
    :ok
  end

  setup :create_test_dir

  defp test_schema do
    Schema.new("query_test")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32,
      dimension: 4,
      index: [type: :hnsw, metric: :l2]
    )
    |> Schema.add_field("category", :string, nullable: true)
  end

  defp create_collection(%{test_dir: test_dir}) do
    path = Path.join(test_dir, "coll")
    {:ok, coll} = Collection.create(path, test_schema())
    on_exit(fn -> Collection.drop(coll) end)
    %{collection: coll}
  end

  defp build_doc(id, vec_values, category) do
    doc =
      Document.new()
      |> Document.put_pk(id)
      |> Document.put("id", id)
      |> Document.put("embedding", Vector.from_list(vec_values, :fp32))

    if category, do: Document.put(doc, "category", category), else: doc
  end

  defp seed_and_flush(coll) do
    docs = [
      build_doc("doc-1", [1.0, 0.0, 0.0, 0.0], "science"),
      build_doc("doc-2", [0.0, 1.0, 0.0, 0.0], "tech"),
      build_doc("doc-3", [0.0, 0.0, 1.0, 0.0], "science"),
      build_doc("doc-4", [0.0, 0.0, 0.0, 1.0], "art")
    ]

    assert {:ok, %{success: 4}} = Collection.insert(coll, docs)
    assert :ok = Collection.flush(coll)
  end

  describe "basic query round-trip" do
    setup [:create_collection]

    test "returns results with pk and score", %{collection: coll} do
      seed_and_flush(coll)

      q = Query.new() |> Query.field("embedding") |> Query.vector([1.0, 0.0, 0.0, 0.0])

      assert {:ok, [result | _]} = Query.execute(q, coll)
      assert is_binary(result.pk)
      assert is_float(result.score)
    end

    test "top result pk is doc-1 when querying its own vector", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)

      assert {:ok, [top]} = Query.execute(q, coll)
      assert top.pk == "doc-1"
    end

    test "top_k limits result count", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(2)

      assert {:ok, results} = Query.execute(q, coll)
      assert length(results) <= 2
    end
  end

  describe "filter" do
    setup [:create_collection]

    test "filter restricts results to matching category", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(10)
        |> Query.filter("category = 'art'")

      assert {:ok, results} = Query.execute(q, coll)

      assert results != []
      assert Enum.all?(results, fn r -> match?({:string, "art"}, r.fields["category"]) end)
    end
  end

  describe "output_fields" do
    setup [:create_collection]

    test "output_fields restricts which fields are returned", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)
        |> Query.output_fields(["id"])

      assert {:ok, [result]} = Query.execute(q, coll)
      assert Map.has_key?(result.fields, "id")
      refute Map.has_key?(result.fields, "embedding")
    end
  end

  describe "include_vector" do
    setup [:create_collection]

    test "include_vector: true returns vector data in fields", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)
        |> Query.include_vector(true)

      assert {:ok, [result]} = Query.execute(q, coll)
      assert match?({:vector_fp32, _}, result.fields["embedding"])
    end
  end

  describe "include_doc_id" do
    setup [:create_collection]

    test "include_doc_id: true is accepted and result has integer doc_id", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)
        |> Query.include_doc_id(true)

      assert {:ok, [result]} = Query.execute(q, coll)
      assert is_integer(result.doc_id)
    end
  end

  describe "HNSW params" do
    setup [:create_collection]

    test "hnsw params are accepted without error", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(2)
        |> Query.hnsw(ef: 50)

      assert {:ok, _results} = Query.execute(q, coll)
    end
  end

  describe "flat (brute-force) params" do
    setup [:create_collection]

    test "flat params execute without error on HNSW collection", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(2)
        |> Query.flat()

      assert {:ok, results} = Query.execute(q, coll)
      assert length(results) == 2
    end

    test "flat query returns exact nearest neighbor", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)
        |> Query.flat()

      assert {:ok, [top]} = Query.execute(q, coll)
      assert top.pk == "doc-1"
    end
  end

  describe "error paths" do
    setup [:create_collection]

    test "returns error when collection is closed", %{collection: coll} do
      closed_coll = %{coll | closed: true}

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])

      assert {:error, _err} = Query.execute(q, closed_coll)
    end
  end

  describe "bang variant" do
    setup [:create_collection]

    test "execute!/2 returns result list directly", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)

      results = Query.execute!(q, coll)
      assert is_list(results)
    end

    test "Query.execute/2 works correctly", %{collection: coll} do
      seed_and_flush(coll)

      q =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)

      assert {:ok, _results} = Query.execute(q, coll)
    end
  end
end
