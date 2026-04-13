defmodule Zvex.QueryTest do
  use ExUnit.Case, async: true

  alias Zvex.Query
  alias Zvex.Vector

  describe "new/0" do
    test "returns struct with defaults" do
      q = Query.new()
      assert q.field == nil
      assert q.vector == nil
      assert q.top_k == 10
      assert q.filter == nil
      assert q.output_fields == []
      assert q.include_vector == false
      assert q.include_doc_id == false
      assert q.params == nil
    end
  end

  describe "field/2" do
    test "sets field name" do
      assert %Query{field: "embedding"} = Query.new() |> Query.field("embedding")
    end
  end

  describe "vector/2" do
    test "stores binary data from a dense Vector struct" do
      vec = Vector.from_list([1.0, 2.0, 3.0], :fp32)
      q = Query.new() |> Query.vector(vec)
      assert q.vector == vec.data
    end

    test "coerces float list to fp32 binary" do
      q = Query.new() |> Query.vector([1.0, 2.0, 3.0])
      expected = Vector.from_list([1.0, 2.0, 3.0], :fp32)
      assert q.vector == expected.data
    end

    test "raises ArgumentError for sparse_vector_fp32" do
      sparse = %Vector{type: :sparse_vector_fp32, data: <<0::64>>}
      assert_raise ArgumentError, fn -> Query.new() |> Query.vector(sparse) end
    end

    test "raises ArgumentError for sparse_vector_fp16" do
      sparse = %Vector{type: :sparse_vector_fp16, data: <<0::64>>}
      assert_raise ArgumentError, fn -> Query.new() |> Query.vector(sparse) end
    end
  end

  describe "top_k/2" do
    test "sets top_k" do
      assert %Query{top_k: 5} = Query.new() |> Query.top_k(5)
    end
  end

  describe "filter/2" do
    test "sets filter expression" do
      assert %Query{filter: "cat = 'x'"} = Query.new() |> Query.filter("cat = 'x'")
    end
  end

  describe "output_fields/2" do
    test "sets output fields" do
      assert %Query{output_fields: ["id", "cat"]} =
               Query.new() |> Query.output_fields(["id", "cat"])
    end
  end

  describe "include_vector/2 and include_doc_id/2" do
    test "sets include_vector" do
      assert %Query{include_vector: true} = Query.new() |> Query.include_vector(true)
    end

    test "sets include_doc_id" do
      assert %Query{include_doc_id: true} = Query.new() |> Query.include_doc_id(true)
    end
  end

  describe "hnsw/2, ivf/2, flat/2" do
    test "hnsw stores params tuple" do
      assert %Query{params: {:hnsw, [ef: 100]}} = Query.new() |> Query.hnsw(ef: 100)
    end

    test "ivf stores params tuple" do
      assert %Query{params: {:ivf, [nprobe: 32]}} = Query.new() |> Query.ivf(nprobe: 32)
    end

    test "flat stores params tuple" do
      assert %Query{params: {:flat, [use_refiner: true]}} =
               Query.new() |> Query.flat(use_refiner: true)
    end

    test "last index type wins" do
      q = Query.new() |> Query.ivf(nprobe: 32) |> Query.hnsw(ef: 64)
      assert q.params == {:hnsw, [ef: 64]}
    end
  end

  describe "execute/2 validation" do
    test "returns error when field is not set" do
      vec = Vector.from_list([1.0, 2.0], :fp32)
      coll = %Zvex.Collection{ref: nil, path: "/tmp", closed: false}
      q = Query.new() |> Query.vector(vec)
      assert {:error, err} = Query.execute(q, coll)
      assert err.message =~ "field"
    end

    test "returns error when vector is not set" do
      coll = %Zvex.Collection{ref: nil, path: "/tmp", closed: false}
      q = Query.new() |> Query.field("embedding")
      assert {:error, err} = Query.execute(q, coll)
      assert err.message =~ "vector"
    end

    test "returns error when collection is closed" do
      vec = Vector.from_list([1.0, 2.0], :fp32)
      coll = %Zvex.Collection{ref: nil, path: "/tmp", closed: true}
      q = Query.new() |> Query.field("embedding") |> Query.vector(vec)
      assert {:error, err} = Query.execute(q, coll)
      assert err.message =~ "closed"
    end
  end
end
