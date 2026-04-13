defmodule Zvex.DocumentSerializationTest do
  use ExUnit.Case, async: false

  alias Zvex.{Document, Vector}

  setup_all do
    Zvex.initialize()
    on_exit(fn -> if Zvex.initialized?(), do: Zvex.shutdown() end)
    :ok
  end

  describe "serialize/1 and deserialize/1" do
    test "round-trip with string and integer fields" do
      doc =
        Document.new()
        |> Document.put_pk("pk1")
        |> Document.put("name", "Alice")
        |> Document.put("age", 30)

      {:ok, binary} = Document.serialize(doc)
      assert is_binary(binary) and byte_size(binary) > 0

      {:ok, restored} = Document.deserialize(binary)
      assert restored.pk == "pk1"
      assert Document.to_map(restored)["name"] == "Alice"
      assert Document.to_map(restored)["age"] == 30
    end

    test "round-trip with float and boolean fields" do
      doc =
        Document.new()
        |> Document.put_pk("pk2")
        |> Document.put("score", 0.95, :float)
        |> Document.put("active", true)

      {:ok, binary} = Document.serialize(doc)
      {:ok, restored} = Document.deserialize(binary)
      assert_in_delta Document.to_map(restored)["score"], 0.95, 0.001
      assert Document.to_map(restored)["active"] == true
    end

    test "round-trip with vector_fp32 field" do
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)

      doc =
        Document.new()
        |> Document.put_pk("pk3")
        |> Document.put("embedding", vec)

      {:ok, binary} = Document.serialize(doc)
      {:ok, restored} = Document.deserialize(binary)
      assert restored.pk == "pk3"
    end

    test "round-trip with sparse_vector_fp32 field" do
      sparse = Vector.from_sparse([0, 5, 12], [1.5, -2.5, 3.5], :sparse_fp32)

      doc =
        Document.new()
        |> Document.put_pk("pk4")
        |> Document.put("sparse", sparse)

      {:ok, binary} = Document.serialize(doc)
      {:ok, restored} = Document.deserialize(binary)
      assert restored.pk == "pk4"
    end

    test "deserialize with garbage binary returns error" do
      assert {:error, _} = Document.deserialize(<<0, 1, 2, 3, 255, 254>>)
    end

    test "bang variants work" do
      doc = Document.new() |> Document.put_pk("pk5") |> Document.put("x", 1)
      binary = Document.serialize!(doc)
      restored = Document.deserialize!(binary)
      assert restored.pk == "pk5"
    end
  end

  describe "memory_usage/1" do
    test "returns positive integer for non-empty doc" do
      doc =
        Document.new()
        |> Document.put_pk("pk1")
        |> Document.put("name", "test")
        |> Document.put("embedding", Vector.from_list([1.0, 2.0, 3.0], :fp32))

      {:ok, usage} = Document.memory_usage(doc)
      assert is_integer(usage) and usage > 0
    end

    test "bang variant works" do
      doc = Document.new() |> Document.put("x", 1)
      usage = Document.memory_usage!(doc)
      assert is_integer(usage) and usage > 0
    end
  end

  describe "detail_string/1" do
    test "returns non-empty string with field info" do
      doc =
        Document.new()
        |> Document.put_pk("pk1")
        |> Document.put("name", "test")

      {:ok, detail} = Document.detail_string(doc)
      assert is_binary(detail) and byte_size(detail) > 0
    end

    test "bang variant works" do
      doc = Document.new() |> Document.put("x", 1)
      detail = Document.detail_string!(doc)
      assert is_binary(detail)
    end
  end
end
