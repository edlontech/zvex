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

      task =
        Task.async(fn ->
          {:ok, _coll} = Collection.create(path, minimal_schema())
          :created
        end)

      :created = Task.await(task)
      :erlang.garbage_collect()
      Process.sleep(100)

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

      task =
        Task.async(fn ->
          Collection.create!(path, minimal_schema())
          :created
        end)

      :created = Task.await(task)
      :erlang.garbage_collect()
      Process.sleep(100)

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

    test "close is idempotent on the same resource", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.close(coll)
      closed_coll = %{coll | closed: true}
      assert {:error, _} = Collection.close(closed_coll)
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
      coll = %{coll | closed: true}

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
      coll = %{coll | closed: true}

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
      coll = %{coll | closed: true}

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
      coll = %{coll | closed: true}

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
      coll = %{coll | closed: true}

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
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.drop_index(coll, "embedding")
    end
  end

  defp schema_with_numeric_column do
    Schema.new("numeric_collection")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32, dimension: 4)
    |> Schema.add_field("score", :double, nullable: true)
  end

  describe "add_column/4" do
    test "adds a nullable numeric column", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.add_column(coll, "score", :double, nullable: true)

      {:ok, schema} = Collection.schema(coll)
      score = Enum.find(schema.fields, &(&1.name == "score"))
      assert score.data_type == :double
      assert score.nullable == true
    end

    test "adds a column with default expression", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.add_column(coll, "count", :int32, nullable: true, default: "0")

      {:ok, schema} = Collection.schema(coll)
      count = Enum.find(schema.fields, &(&1.name == "count"))
      assert count.data_type == :int32
    end

    test "add_column! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert :ok = Collection.add_column!(coll, "weight", :float, nullable: true)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.add_column(coll, "score", :double, nullable: true)
    end
  end

  describe "drop_column/2" do
    test "drops an existing numeric column", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, schema_with_numeric_column())

      assert :ok = Collection.drop_column(coll, "score")

      {:ok, schema} = Collection.schema(coll)
      field_names = Enum.map(schema.fields, & &1.name)
      refute "score" in field_names
    end

    test "drop_column! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, schema_with_numeric_column())

      assert :ok = Collection.drop_column!(coll, "score")
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.drop_column(coll, "score")
    end
  end

  describe "alter_column/3" do
    test "renames a numeric column", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, schema_with_numeric_column())

      assert :ok = Collection.alter_column(coll, "score", new_name: "rating")

      {:ok, schema} = Collection.schema(coll)
      field_names = Enum.map(schema.fields, & &1.name)
      assert "rating" in field_names
      refute "score" in field_names
    end

    test "alter_column! returns :ok", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, schema_with_numeric_column())

      assert :ok = Collection.alter_column!(coll, "score", new_name: "renamed_score")
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.alter_column(coll, "score", new_name: "rating")
    end
  end

  describe "options/1" do
    test "returns options for a collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert {:ok, opts} = Collection.options(coll)
      assert is_boolean(Map.get(opts, :enable_mmap))
      assert is_integer(Map.get(opts, :max_buffer_size))
      assert is_boolean(Map.get(opts, :read_only))
    end

    test "returns options reflecting open-time settings", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema(), read_only: false)

      {:ok, opts} = Collection.options(coll)
      assert opts.read_only == false
    end

    test "options! returns the map directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert %{enable_mmap: _, max_buffer_size: _, read_only: _} = Collection.options!(coll)
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.options(coll)
    end
  end

  describe "has_field?/2" do
    test "returns true for existing field", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert Collection.has_field?(coll, "id")
      assert Collection.has_field?(coll, "embedding")
    end

    test "returns false for non-existent field", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      refute Collection.has_field?(coll, "nonexistent")
    end

    test "reflects dynamically added columns", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      refute Collection.has_field?(coll, "score")
      :ok = Collection.add_column(coll, "score", :double, nullable: true)
      assert Collection.has_field?(coll, "score")
    end
  end

  describe "has_index?/2" do
    test "returns true for indexed field", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      assert Collection.has_index?(coll, "embedding")
    end

    test "returns false for non-indexed field", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      refute Collection.has_index?(coll, "embedding")
    end

    test "reflects dynamically created indexes", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      refute Collection.has_index?(coll, "embedding")
      :ok = Collection.create_index(coll, "embedding", type: :hnsw, metric: :cosine)
      assert Collection.has_index?(coll, "embedding")
    end
  end

  describe "field_names/1 and field_names/2" do
    test "returns all field names", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, names} = Collection.field_names(coll)
      assert "id" in names
      assert "embedding" in names
      assert "title" in names
    end

    test "returns forward (scalar) field names", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, names} = Collection.field_names(coll, :forward)
      assert "id" in names
      assert "title" in names
      refute "embedding" in names
    end

    test "returns vector field names", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, names} = Collection.field_names(coll, :vector)
      assert "embedding" in names
      refute "id" in names
    end

    test "returns indexed field names", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, indexed_schema())

      {:ok, names} = Collection.field_names(coll, :indexed)
      assert is_list(names)
    end

    test "field_names! returns list directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert is_list(Collection.field_names!(coll))
    end

    test "field_names!/2 returns list directly", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())

      assert is_list(Collection.field_names!(coll, :forward))
    end

    test "returns error on closed collection", %{test_dir: test_dir} do
      path = collection_path(test_dir)
      {:ok, coll} = Collection.create(path, minimal_schema())
      coll = %{coll | closed: true}

      assert {:error, _} = Collection.field_names(coll)
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
      coll = %{coll | closed: true}

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
    test "create -> GC -> open -> stats round-trip", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      task =
        Task.async(fn ->
          {:ok, coll} = Collection.create(path, minimal_schema())
          :ok = Collection.flush(coll)
          :flushed
        end)

      :flushed = Task.await(task)
      :erlang.garbage_collect()
      Process.sleep(100)

      {:ok, reopened} = Collection.open(path)
      assert {:ok, %Stats{doc_count: 0}} = Collection.stats(reopened)
    end

    test "create -> GC -> open -> schema preserves fields", %{test_dir: test_dir} do
      path = collection_path(test_dir)

      task =
        Task.async(fn ->
          {:ok, coll} = Collection.create(path, indexed_schema())
          :ok = Collection.flush(coll)
          :flushed
        end)

      :flushed = Task.await(task)
      :erlang.garbage_collect()
      Process.sleep(100)

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
