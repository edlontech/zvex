defmodule Zvex.Collection.SchemaTest do
  use ExUnit.Case, async: true

  alias Zvex.Collection.Schema
  alias Zvex.Collection.Schema.IndexParams

  defp minimal_schema do
    Schema.new("test")
    |> Schema.add_field("id", :string, primary_key: true)
  end

  describe "new/1" do
    test "creates schema with name" do
      schema = Schema.new("my_collection")
      assert schema.name == "my_collection"
      assert schema.fields == []
      assert schema.max_doc_count_per_segment == nil
    end
  end

  describe "add_field/4" do
    test "appends a simple field" do
      schema = Schema.new("test") |> Schema.add_field("id", :string)

      assert [%{name: "id", data_type: :string, nullable: false, dimension: 0, index: nil}] =
               schema.fields
    end

    test "primary_key forces non-nullable" do
      schema =
        Schema.new("test") |> Schema.add_field("id", :string, primary_key: true, nullable: true)

      [field] = schema.fields
      assert field.primary_key == true
      assert field.nullable == false
    end

    test "sets nullable" do
      schema = Schema.new("test") |> Schema.add_field("cat", :string, nullable: true)
      [field] = schema.fields
      assert field.nullable == true
    end

    test "sets dimension for vector fields" do
      schema = Schema.new("test") |> Schema.add_field("emb", :vector_fp32, dimension: 768)
      [field] = schema.fields
      assert field.dimension == 768
    end

    test "builds IndexParams from index keyword" do
      schema =
        Schema.new("test")
        |> Schema.add_field("emb", :vector_fp32,
          dimension: 768,
          index: [type: :hnsw, metric: :cosine, m: 16, ef_construction: 200]
        )

      [field] = schema.fields
      assert %IndexParams{type: :hnsw, metric: :cosine, m: 16, ef_construction: 200} = field.index
    end

    test "builds invert index params" do
      schema =
        Schema.new("test")
        |> Schema.add_field("cat", :string, index: [type: :invert, enable_wildcard: true])

      [field] = schema.fields
      assert %IndexParams{type: :invert, enable_wildcard: true} = field.index
    end

    test "builds ivf index params" do
      schema =
        Schema.new("test")
        |> Schema.add_field("emb", :vector_fp32,
          dimension: 128,
          index: [type: :ivf, metric: :l2, n_list: 100, n_iters: 10, use_soar: true]
        )

      [field] = schema.fields
      assert %IndexParams{type: :ivf, n_list: 100, n_iters: 10, use_soar: true} = field.index
    end

    test "preserves field ordering" do
      schema =
        Schema.new("test")
        |> Schema.add_field("a", :string)
        |> Schema.add_field("b", :int32)
        |> Schema.add_field("c", :float)

      names = Enum.map(schema.fields, & &1.name)
      assert names == ["a", "b", "c"]
    end
  end

  describe "max_doc_count_per_segment/2" do
    test "sets the value" do
      schema = Schema.new("test") |> Schema.max_doc_count_per_segment(10_000)
      assert schema.max_doc_count_per_segment == 10_000
    end
  end

  describe "validate/1" do
    test "accepts minimal valid schema" do
      assert :ok = minimal_schema() |> Schema.validate()
    end

    test "accepts schema with vector field and hnsw index" do
      schema =
        minimal_schema()
        |> Schema.add_field("emb", :vector_fp32,
          dimension: 128,
          index: [type: :hnsw, metric: :cosine]
        )

      assert :ok = Schema.validate(schema)
    end

    test "rejects empty name" do
      schema = %Schema{
        name: "",
        fields: [
          %{
            name: "id",
            data_type: :string,
            primary_key: true,
            nullable: false,
            dimension: 0,
            index: nil
          }
        ]
      }

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects nil name" do
      schema = %Schema{
        name: nil,
        fields: [
          %{
            name: "id",
            data_type: :string,
            primary_key: true,
            nullable: false,
            dimension: 0,
            index: nil
          }
        ]
      }

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects empty fields" do
      schema = Schema.new("test")
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects missing primary key" do
      schema = Schema.new("test") |> Schema.add_field("name", :string)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects multiple primary keys" do
      schema =
        Schema.new("test")
        |> Schema.add_field("id1", :string, primary_key: true)
        |> Schema.add_field("id2", :string, primary_key: true)

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects non-string primary key" do
      schema = Schema.new("test") |> Schema.add_field("id", :int64, primary_key: true)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects duplicate field names" do
      schema =
        Schema.new("test")
        |> Schema.add_field("id", :string, primary_key: true)
        |> Schema.add_field("id", :int32)

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects unknown data type" do
      schema =
        Schema.new("test")
        |> Schema.add_field("id", :string, primary_key: true)
        |> Schema.add_field("x", :bogus_type)

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects vector field with zero dimension" do
      schema =
        minimal_schema()
        |> Schema.add_field("emb", :vector_fp32)

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects hnsw index on scalar field" do
      schema =
        minimal_schema()
        |> Schema.add_field("cat", :string, index: [type: :hnsw, metric: :cosine])

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects invert index on vector field" do
      schema =
        minimal_schema()
        |> Schema.add_field("emb", :vector_fp32, dimension: 128, index: [type: :invert])

      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "rejects negative max_doc_count_per_segment" do
      schema = minimal_schema() |> Schema.max_doc_count_per_segment(-1)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Schema.validate(schema)
    end

    test "accepts all scalar data types" do
      for type <- Schema.scalar_types() do
        schema =
          Schema.new("test")
          |> Schema.add_field("id", :string, primary_key: true)
          |> Schema.add_field("f", type)

        assert :ok = Schema.validate(schema), "expected :ok for scalar type #{type}"
      end
    end

    test "accepts all vector data types with dimension" do
      for type <- Schema.vector_types() do
        schema =
          Schema.new("test")
          |> Schema.add_field("id", :string, primary_key: true)
          |> Schema.add_field("v", type, dimension: 128)

        assert :ok = Schema.validate(schema), "expected :ok for vector type #{type}"
      end
    end
  end

  describe "IndexParams.from_opts/1" do
    test "requires :type" do
      assert_raise KeyError, fn -> IndexParams.from_opts([]) end
    end

    test "sets only type when no other opts given" do
      params = IndexParams.from_opts(type: :flat)
      assert params.type == :flat
      assert params.metric == nil
    end

    test "sets quantize" do
      params = IndexParams.from_opts(type: :hnsw, quantize: :int8)
      assert params.quantize == :int8
    end
  end
end
