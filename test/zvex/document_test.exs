defmodule Zvex.DocumentTest do
  use ExUnit.Case, async: true

  alias Zvex.Document
  alias Zvex.Vector
  alias Zvex.Collection.Schema

  defp build_schema do
    Schema.new("test_collection")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32, dimension: 3)
    |> Schema.add_field("title", :string)
    |> Schema.add_field("score", :double)
    |> Schema.add_field("tags", :array_string, nullable: true)
  end

  describe "new/0" do
    test "creates empty document" do
      doc = Document.new()
      assert %Document{fields: %{}, pk: nil} = doc
    end
  end

  describe "put/3 type inference" do
    test "infers boolean before binary guard" do
      doc = Document.new() |> Document.put("flag", true)
      assert %Document{fields: %{"flag" => {:bool, true}}} = doc
    end

    test "infers false as bool" do
      doc = Document.new() |> Document.put("flag", false)
      assert %Document{fields: %{"flag" => {:bool, false}}} = doc
    end

    test "infers binary as string" do
      doc = Document.new() |> Document.put("name", "hello")
      assert %Document{fields: %{"name" => {:string, "hello"}}} = doc
    end

    test "infers integer as int64" do
      doc = Document.new() |> Document.put("count", 42)
      assert %Document{fields: %{"count" => {:int64, 42}}} = doc
    end

    test "infers float as double" do
      doc = Document.new() |> Document.put("score", 3.14)
      assert %Document{fields: %{"score" => {:double, 3.14}}} = doc
    end

    test "infers Vector struct type" do
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)
      doc = Document.new() |> Document.put("embedding", vec)
      assert %Document{fields: %{"embedding" => {:vector_fp32, data}}} = doc
      assert is_binary(data)
    end

    test "raises ArgumentError for lists" do
      assert_raise ArgumentError, fn ->
        Document.new() |> Document.put("items", [1, 2, 3])
      end
    end
  end

  describe "put/4 explicit type" do
    test "stores with explicit type" do
      doc = Document.new() |> Document.put("score", 3.14, :float)
      assert %Document{fields: %{"score" => {:float, 3.14}}} = doc
    end

    test "stores array type" do
      doc = Document.new() |> Document.put("tags", ["a", "b"], :array_string)
      assert %Document{fields: %{"tags" => {:array_string, ["a", "b"]}}} = doc
    end
  end

  describe "put_null/2" do
    test "stores null" do
      doc = Document.new() |> Document.put_null("optional_field")
      assert %Document{fields: %{"optional_field" => {:null, nil}}} = doc
    end
  end

  describe "put_pk/2" do
    test "sets pk" do
      doc = Document.new() |> Document.put_pk("doc-123")
      assert %Document{pk: "doc-123"} = doc
    end
  end

  describe "from_map/2" do
    test "resolves types from schema" do
      schema = build_schema()

      doc = Document.from_map(%{"id" => "doc-1", "title" => "Hello", "score" => 9.5}, schema)

      assert %Document{
               pk: "doc-1",
               fields: %{
                 "id" => {:string, "doc-1"},
                 "title" => {:string, "Hello"},
                 "score" => {:double, 9.5}
               }
             } = doc
    end

    test "auto-packs vector lists using schema type" do
      schema = build_schema()

      doc = Document.from_map(%{"id" => "doc-1", "embedding" => [1.0, 2.0, 3.0]}, schema)

      assert %Document{fields: %{"embedding" => {:vector_fp32, data}}} = doc
      assert is_binary(data)

      vec = Vector.from_binary(data, :fp32)
      assert Vector.to_list(vec) == [1.0, 2.0, 3.0]
    end

    test "accepts Vector structs" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc = Document.from_map(%{"id" => "doc-1", "embedding" => vec}, schema)

      assert %Document{fields: %{"embedding" => {:vector_fp32, data}}} = doc
      assert data == vec.data
    end

    test "ignores unknown fields" do
      schema = build_schema()

      doc = Document.from_map(%{"id" => "doc-1", "unknown_field" => "value"}, schema)

      refute Map.has_key?(doc.fields, "unknown_field")
      assert Map.has_key?(doc.fields, "id")
    end

    test "sets pk from primary key field" do
      schema = build_schema()

      doc = Document.from_map(%{"id" => "primary-key-value"}, schema)

      assert doc.pk == "primary-key-value"
    end
  end

  describe "to_map/1" do
    test "strips type tags" do
      doc =
        Document.new()
        |> Document.put("name", "Alice")
        |> Document.put("age", 30)
        |> Document.put("score", 9.5)

      result = Document.to_map(doc)

      assert result == %{"name" => "Alice", "age" => 30, "score" => 9.5}
    end

    test "strips null tags" do
      doc = Document.new() |> Document.put_null("empty")

      result = Document.to_map(doc)
      assert result == %{"empty" => nil}
    end
  end

  describe "validate/2" do
    test "valid document passes" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc =
        Document.from_map(
          %{"id" => "doc-1", "embedding" => vec, "title" => "Hello", "score" => 9.5},
          schema
        )

      assert :ok = Document.validate(doc, schema)
    end

    test "missing pk fails" do
      schema = build_schema()

      doc = Document.new() |> Document.put("title", "Hello")

      assert {:error, err} = Document.validate(doc, schema)
      assert Exception.message(err) =~ "primary key"
    end

    test "wrong vector dimension fails" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0], :fp32)

      doc =
        Document.from_map(
          %{"id" => "doc-1", "embedding" => vec, "title" => "Hello", "score" => 9.5},
          schema
        )

      assert {:error, err} = Document.validate(doc, schema)
      assert Exception.message(err) =~ "dimension"
    end

    test "missing required (non-nullable) field fails" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc = Document.from_map(%{"id" => "doc-1", "embedding" => vec}, schema)

      assert {:error, err} = Document.validate(doc, schema)
      assert Exception.message(err) =~ "required"
    end

    test "field type mismatch fails" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc =
        Document.new()
        |> Document.put_pk("doc-1")
        |> Document.put("id", "doc-1", :string)
        |> Document.put("embedding", vec)
        |> Document.put("title", "Hello")
        |> Document.put("score", "not a double", :string)

      assert {:error, err} = Document.validate(doc, schema)
      assert Exception.message(err) =~ "field 'score' has type string, expected double"
    end

    test "nullable field can be omitted" do
      schema = build_schema()
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc =
        Document.from_map(
          %{"id" => "doc-1", "embedding" => vec, "title" => "Hello", "score" => 9.5},
          schema
        )

      assert :ok = Document.validate(doc, schema)
    end
  end

  describe "to_native_map/1 and from_native_map/1 round-trip" do
    test "round-trips a document" do
      doc =
        Document.new()
        |> Document.put_pk("doc-1")
        |> Document.put("name", "Alice")
        |> Document.put("age", 42)

      native = Document.to_native_map(doc)

      assert native.pk == "doc-1"
      assert is_list(native.fields)

      reconstructed = Document.from_native_map(native)

      assert reconstructed.pk == doc.pk
      assert reconstructed.fields == doc.fields
    end

    test "round-trips with vector data" do
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc =
        Document.new()
        |> Document.put_pk("vec-doc")
        |> Document.put("embedding", vec)

      native = Document.to_native_map(doc)
      reconstructed = Document.from_native_map(native)

      assert reconstructed.fields == doc.fields
    end
  end

  describe "to_native_maps/1" do
    test "normalizes single doc to list" do
      doc = Document.new() |> Document.put_pk("doc-1")

      result = Document.to_native_maps(doc)

      assert is_list(result)
      assert length(result) == 1
      assert [%{pk: "doc-1"}] = result
    end

    test "normalizes list of docs" do
      doc1 = Document.new() |> Document.put_pk("doc-1")
      doc2 = Document.new() |> Document.put_pk("doc-2")

      result = Document.to_native_maps([doc1, doc2])

      assert length(result) == 2
      assert [%{pk: "doc-1"}, %{pk: "doc-2"}] = result
    end
  end
end
