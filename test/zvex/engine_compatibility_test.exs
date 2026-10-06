defmodule Zvex.EngineCompatibilityTest do
  use ExUnit.Case, async: false

  import Zvex.TestDir

  alias Zvex.{Collection, Document, Query, Vector}
  alias Zvex.Collection.Schema

  setup_all do
    :ok = Zvex.initialize()
    on_exit(fn -> if Zvex.initialized?(), do: Zvex.shutdown() end)
    :ok
  end

  setup :create_test_dir

  test "fetch retains scalars, nulls, dense and sparse vectors", %{test_dir: dir} do
    schema =
      Schema.new("fetch_compat")
      |> Schema.add_field("id", :string, primary_key: true)
      |> Schema.add_field("title", :string, nullable: true)
      |> Schema.add_field("embedding", :vector_fp32, dimension: 4)
      |> Schema.add_field("sparse32", :sparse_vector_fp32, dimension: 16)
      |> Schema.add_field("sparse16", :sparse_vector_fp16, dimension: 16)

    {:ok, coll} = Collection.create(Path.join(dir, "fetch"), schema)
    on_exit(fn -> Collection.close(coll) end)

    dense = Vector.from_list([1.0, 0.0, 0.5, -1.0], :fp32)
    sparse32 = Vector.from_sparse([0, 5], [1.0, 0.5], :sparse_fp32)
    sparse16 = Vector.from_sparse([1, 7], [0.5, -1.0], :sparse_fp16)

    doc =
      Document.new()
      |> Document.put_pk("one")
      |> Document.put("id", "one")
      |> Document.put_null("title")
      |> Document.put("embedding", dense)
      |> Document.put("sparse32", sparse32)
      |> Document.put("sparse16", sparse16)

    assert {:ok, %{success: 1}} = Collection.insert(coll, doc)
    assert {:ok, [%Document{pk: "one", fields: fields}]} = Collection.fetch(coll, ["one"])
    assert fields["id"] == {:string, "one"}
    assert fields["title"] == {:null, nil}
    assert fields["embedding"] == {:vector_fp32, dense.data}
    assert fields["sparse32"] == {:sparse_vector_fp32, sparse32.data}
    assert fields["sparse16"] == {:sparse_vector_fp16, sparse16.data}
  end

  test "default query projection and explicit flags preserve result shapes", %{test_dir: dir} do
    coll = indexed_collection(dir, :hnsw)

    query =
      Query.new()
      |> Query.field("embedding")
      |> Query.vector([1.0, 0.0, 0.0, 0.0])
      |> Query.top_k(1)

    assert {:ok, [default]} = Query.execute(query, coll)
    assert default.pk == "one"
    assert default.fields["category"] == {:string, "science"}
    assert is_float(default.score)

    selected =
      query
      |> Query.output_fields(["category"])
      |> Query.include_vector(true)
      |> Query.include_doc_id(true)

    assert {:ok, [result]} = Query.execute(selected, coll)
    assert result.fields["category"] == {:string, "science"}
    assert match?({:vector_fp32, _}, result.fields["embedding"])
    assert is_integer(result.doc_id)
    refute Map.has_key?(result.fields, "id")
  end

  test "query parameters remain tied to HNSW, FLAT, and IVF index types", %{test_dir: dir} do
    for index <- [:hnsw, :flat, :ivf] do
      coll = indexed_collection(dir, index)

      query =
        Query.new()
        |> Query.field("embedding")
        |> Query.vector([1.0, 0.0, 0.0, 0.0])
        |> Query.top_k(1)

      assert {:ok, [top]} = Query.execute(query, coll)
      assert top.pk == "one"
      assert_in_delta top.score, 0.0, 1.0e-5

      case index do
        :hnsw ->
          assert {:ok, [%{pk: "one"}]} = Query.execute(Query.flat(query), coll)
          assert {:ok, [%{pk: "one"}]} = Query.execute(Query.hnsw(query, use_refiner: true), coll)

        :flat ->
          assert {:error, %_{} = _error} = Query.execute(Query.flat(query), coll)

        :ivf ->
          assert {:ok, [%{pk: "one"}]} = Query.execute(Query.ivf(query, nprobe: 1), coll)
          assert {:error, %_{} = _error} = Query.execute(Query.flat(query), coll)
      end
    end
  end

  test "filtering and invalid query inputs keep structured outcomes", %{test_dir: dir} do
    coll = indexed_collection(dir, :hnsw)

    query =
      Query.new()
      |> Query.field("embedding")
      |> Query.vector([1.0, 0.0, 0.0, 0.0])
      |> Query.top_k(1)

    assert {:ok, [%{pk: "two"}]} = Query.execute(Query.filter(query, "category = 'art'"), coll)
    assert {:error, %_{} = _error} = Query.execute(Query.field(query, "missing"), coll)
    assert {:error, %_{} = _error} = Query.execute(Query.vector(query, [1.0, 0.0]), coll)
    assert {:error, %_{} = _error} = Query.execute(Query.ivf(query, nprobe: 1), coll)
  end

  test "fetch handles empty, missing, duplicate, and closed-resource keys", %{test_dir: dir} do
    coll = indexed_collection(dir, :hnsw)

    assert {:ok, []} = Collection.fetch(coll, [])
    assert {:ok, []} = Collection.fetch(coll, ["absent"])
    assert {:ok, fetched} = Collection.fetch(coll, ["absent", "one", "one"])
    assert Enum.map(fetched, & &1.pk) == ["one"]
    assert :ok = Collection.close(coll)
    assert {:error, %Zvex.Error.Invalid.FailedPrecondition{}} = Collection.fetch(coll, ["one"])
  end

  test "bounded optimize, reads, writes, and close leave the VM healthy", %{test_dir: dir} do
    coll = indexed_collection(dir, :hnsw)
    query = Query.new() |> Query.field("embedding") |> Query.vector([1.0, 0.0, 0.0, 0.0])

    extra =
      Document.new()
      |> Document.put_pk("four")
      |> Document.put("id", "four")
      |> Document.put("embedding", Vector.from_list([0.0, 0.0, 0.0, 1.0], :fp32))

    tasks = [
      Task.async(fn -> Collection.optimize(coll) end),
      Task.async(fn -> Collection.fetch(coll, ["one"]) end),
      Task.async(fn -> Collection.insert(coll, extra) end),
      Task.async(fn -> Query.execute(query, coll) end),
      Task.async(fn -> Collection.close(coll) end)
    ]

    assert Enum.all?(Task.await_many(tasks, 15_000), fn
             :ok -> true
             {:ok, _} -> true
             {:error, %_{} = _error} -> true
             _ -> false
           end)

    :erlang.garbage_collect()
    assert {:error, %Zvex.Error.Invalid.FailedPrecondition{}} = Collection.fetch(coll, ["one"])
  end

  defp indexed_collection(dir, index_type) do
    index =
      case index_type do
        :ivf -> [type: :ivf, metric: :l2, n_list: 1, n_iters: 5]
        other -> [type: other, metric: :l2]
      end

    schema =
      Schema.new("search_#{index_type}")
      |> Schema.add_field("id", :string, primary_key: true)
      |> Schema.add_field("embedding", :vector_fp32, dimension: 4, index: index)
      |> Schema.add_field("category", :string, nullable: true, index: [type: :invert])

    {:ok, coll} = Collection.create(Path.join(dir, Atom.to_string(index_type)), schema)
    on_exit(fn -> Collection.close(coll) end)

    docs = [
      {"one", [1.0, 0.0, 0.0, 0.0], "science"},
      {"two", [0.0, 1.0, 0.0, 0.0], "art"},
      {"three", [0.0, 0.0, 1.0, 0.0], "science"}
    ]

    documents =
      for {pk, values, category} <- docs do
        Document.new()
        |> Document.put_pk(pk)
        |> Document.put("id", pk)
        |> Document.put("embedding", Vector.from_list(values, :fp32))
        |> Document.put("category", category)
      end

    assert {:ok, %{success: 3}} = Collection.insert(coll, documents)

    assert :ok = Collection.flush(coll)
    coll
  end
end
