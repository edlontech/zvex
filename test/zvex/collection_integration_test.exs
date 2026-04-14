defmodule Zvex.CollectionIntegrationTest do
  use ExUnit.Case, async: false

  import Zvex.TestDir

  alias Zvex.Collection
  alias Zvex.Collection.Schema
  alias Zvex.Collection.Schema.IndexParams
  alias Zvex.Collection.Stats

  setup_all do
    Zvex.initialize()
    on_exit(fn -> if Zvex.initialized?(), do: Zvex.shutdown() end)
    :ok
  end

  setup :create_test_dir

  defp minimal_schema do
    Schema.new("test_collection")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32, dimension: 4)
  end

  defp indexed_schema do
    Schema.new("indexed_collection")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32,
      dimension: 128,
      index: [type: :hnsw, metric: :cosine, m: 16, ef_construction: 200]
    )
    |> Schema.add_field("title", :string, nullable: true)
  end

  defp collection_path(test_dir, name \\ "coll") do
    Path.join(test_dir, name)
  end

  describe "create/3" do
    test "returns a collection struct", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      assert {:ok, %Collection{path: ^path, closed: false}} =
               Collection.create(path, minimal_schema())
    end

    test "creates with indexed vector fields", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      assert {:ok, %Collection{}} = Collection.create(path, indexed_schema())
    end

    test "rejects invalid schema before hitting NIF", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      bad_schema = Schema.new("empty")

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Collection.create(path, bad_schema)
    end

    test "returns error for duplicate path", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, _} = Collection.create(path, minimal_schema())

      assert {:error, _} = Collection.create(path, minimal_schema())
    end
  end

  describe "create!/3" do
    test "returns the collection directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      assert %Collection{path: ^path} = Collection.create!(path, minimal_schema())
    end

    test "raises on invalid schema", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      assert_raise Zvex.Error.Invalid.Argument, fn ->
        Collection.create!(path, Schema.new("empty"))
      end
    end
  end

  describe "open/2" do
    test "opens an existing collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      :ok = Collection.close(coll)

      assert {:ok, %Collection{path: ^path}} = Collection.open(path)
    end

    test "returns error for non-existent path", %{test_dir: test_dir} do
      path = collection_path(test_dir, "nonexistent")
      assert {:error, _} = Collection.open(path)
    end
  end

  describe "open!/2" do
    test "returns the collection directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      Collection.create!(path, minimal_schema()) |> Collection.close()

      assert %Collection{} = Collection.open!(path)
    end

    test "raises for non-existent path", %{test_dir: test_dir} do
      path = collection_path(test_dir, "nonexistent")

      assert_raise Zvex.Error.Invalid.Argument, fn ->
        Collection.open!(path)
      end
    end
  end

  describe "close/1" do
    test "closes an open collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.close(coll)
    end

    test "NIF close is idempotent on the same resource", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Zvex.Native.collection_close(coll.ref)
      assert :ok = Zvex.Native.collection_close(coll.ref)
    end
  end

  describe "close!/1" do
    test "returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.close!(coll)
    end
  end

  describe "flush/1" do
    test "flushes an open collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.flush(coll)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} = Collection.flush(coll)
    end
  end

  describe "optimize/1" do
    test "optimizes an open collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.optimize(coll)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} = Collection.optimize(coll)
    end
  end

  describe "stats/1" do
    test "returns stats for a fresh collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert {:ok, %Stats{doc_count: 0, indexes: indexes}} = Collection.stats(coll)
      assert is_list(indexes)
    end

    test "stats! returns the struct directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert %Stats{doc_count: 0} = Collection.stats!(coll)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} = Collection.stats(coll)
    end
  end

  describe "schema/1" do
    test "returns the schema of a collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert {:ok, %Schema{name: "test_collection"} = schema} = Collection.schema(coll)

      field_names = Enum.map(schema.fields, & &1.name)
      assert "id" in field_names
      assert "embedding" in field_names
    end

    test "round-trips indexed fields", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, schema} = Collection.schema(coll)
      embedding = Enum.find(schema.fields, &(&1.name == "embedding"))

      assert embedding.data_type == :vector_fp32
      assert embedding.dimension == 128
      assert %IndexParams{type: :hnsw, metric: :cosine} = embedding.index
    end

    test "round-trips nullable fields", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, schema} = Collection.schema(coll)
      title = Enum.find(schema.fields, &(&1.name == "title"))

      assert title.data_type == :string
      assert title.nullable == true
    end

    test "schema! returns directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert %Schema{} = Collection.schema!(coll)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} = Collection.schema(coll)
    end
  end

  describe "create_index/3" do
    test "creates an hnsw index on an unindexed field", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok =
               Collection.create_index(coll, "embedding",
                 type: :hnsw,
                 metric: :cosine,
                 m: 16,
                 ef_construction: 200
               )

      {:ok, schema} = Collection.schema(coll)
      embedding = Enum.find(schema.fields, &(&1.name == "embedding"))
      assert %IndexParams{type: :hnsw, metric: :cosine} = embedding.index
    end

    test "create_index! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.create_index!(coll, "embedding", type: :hnsw, metric: :cosine)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} =
               Collection.create_index(coll, "embedding", type: :hnsw, metric: :cosine)
    end
  end

  describe "drop_index/2" do
    test "drops an existing index", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      assert :ok = Collection.drop_index(coll, "embedding")
    end

    test "drop_index! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      assert :ok = Collection.drop_index!(coll, "embedding")
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert {:error, _} = Collection.drop_index(coll, "embedding")
    end
  end

  describe "drop/1" do
    test "removes the collection directory", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.drop(coll)
      refute File.exists?(path)
    end

    test "drop works on already-closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      Zvex.Native.collection_close(coll.ref)

      assert :ok = Collection.drop(coll)
      refute File.exists?(path)
    end

    test "drop! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.drop!(coll)
    end
  end

  describe "GC destructor" do
    test "no segfault when collection is GC'd without explicit close", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      task =
        Task.async(fn ->
          {:ok, _} = Collection.create(path, minimal_schema())
          :created
        end)

      :created = Task.await(task)
    end

    test "no segfault when multiple collections are GC'd", %{test_dir: test_dir} do
      task =
        Task.async(fn ->
          for i <- 1..5 do
            path = collection_path(test_dir, "gc_coll_#{i}")
            {:ok, _} = Collection.create(path, minimal_schema())
          end

          :created
        end)

      :created = Task.await(task)
    end

    test "no segfault when close is called then resource is GC'd", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      task =
        Task.async(fn ->
          {:ok, coll} = Collection.create(path, minimal_schema())
          :ok = Collection.close(coll)
          :done
        end)

      :done = Task.await(task)
    end
  end

  describe "reopen lifecycle" do
    test "create -> close -> open -> stats round-trip", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      {:ok, coll} = Collection.create(path, minimal_schema())
      :ok = Collection.flush(coll)
      :ok = Collection.close(coll)

      {:ok, reopened} = Collection.open(path)
      assert {:ok, %Stats{doc_count: 0}} = Collection.stats(reopened)
    end

    test "create -> close -> open -> schema preserves fields", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      {:ok, coll} = Collection.create(path, indexed_schema())
      :ok = Collection.flush(coll)
      :ok = Collection.close(coll)

      {:ok, reopened} = Collection.open(path)
      {:ok, schema} = Collection.schema(reopened)

      assert schema.name == "indexed_collection"

      field_names = Enum.map(schema.fields, & &1.name)
      assert "id" in field_names
      assert "embedding" in field_names
      assert "title" in field_names
    end
  end
end
