defmodule Zvex.VectorTest do
  use ExUnit.Case, async: true

  alias Zvex.Vector

  describe "from_list/2 -> to_list/1 round-trip" do
    test "fp32" do
      input = [1.0, 2.0, 3.0, -4.5]
      vector = Vector.from_list(input, :fp32)

      assert %Vector{type: :vector_fp32} = vector
      assert Vector.to_list(vector) == input
    end

    test "fp64" do
      input = [1.0, 2.0, 3.0, -4.5]
      vector = Vector.from_list(input, :fp64)

      assert %Vector{type: :vector_fp64} = vector
      assert Vector.to_list(vector) == input
    end

    test "fp16 with tolerance" do
      input = [1.0, 2.0, 0.5, -3.0]
      vector = Vector.from_list(input, :fp16)

      assert %Vector{type: :vector_fp16} = vector
      result = Vector.to_list(vector)

      Enum.zip(input, result)
      |> Enum.each(fn {expected, actual} ->
        assert_in_delta expected, actual, 0.01
      end)
    end

    test "fp16 handles zero" do
      vector = Vector.from_list([0.0], :fp16)
      assert [+0.0] = Vector.to_list(vector)
    end

    test "fp16 handles subnormals" do
      vector = Vector.from_list([0.0001], :fp16)
      result = Vector.to_list(vector)
      [val] = result
      assert_in_delta 0.0001, val, 0.001
    end

    test "int8" do
      input = [1, -1, 127, -128, 0]
      vector = Vector.from_list(input, :int8)

      assert %Vector{type: :vector_int8} = vector
      assert Vector.to_list(vector) == input
    end

    test "int16" do
      input = [1, -1, 32_767, -32_768, 0]
      vector = Vector.from_list(input, :int16)

      assert %Vector{type: :vector_int16} = vector
      assert Vector.to_list(vector) == input
    end

    test "int4 nibble packing" do
      input = [1, 2, 3, 4]
      vector = Vector.from_list(input, :int4)

      assert %Vector{type: :vector_int4} = vector
      assert Vector.to_list(vector) == input
    end

    test "int4 odd count pads with zero" do
      input = [1, 2, 3]
      vector = Vector.from_list(input, :int4)

      assert %Vector{type: :vector_int4} = vector
      # Odd count: last byte has low nibble = 0, but dimension tracks pairs
      # The stored dimension is byte_size * 2, so we get padded result
      assert Vector.to_list(vector) == [1, 2, 3, 0]
    end

    test "binary32 passthrough" do
      input = [1, 0, 1, 1, 0, 0, 1, 0]
      vector = Vector.from_list(input, :binary32)

      assert %Vector{type: :vector_binary32} = vector
      assert Vector.to_list(vector) == input
    end

    test "binary64 passthrough" do
      input = [1, 0, 1, 1, 0, 0, 1, 0]
      vector = Vector.from_list(input, :binary64)

      assert %Vector{type: :vector_binary64} = vector
      assert Vector.to_list(vector) == input
    end
  end

  describe "from_binary/2" do
    test "wraps pre-packed binary for fp32" do
      packed = <<1.0::native-float-32, 2.0::native-float-32>>
      vector = Vector.from_binary(packed, :fp32)

      assert %Vector{type: :vector_fp32, data: ^packed} = vector
      assert Vector.to_list(vector) == [1.0, 2.0]
    end

    test "wraps pre-packed binary for int8" do
      packed = <<42::native-signed-8, -1::native-signed-8>>
      vector = Vector.from_binary(packed, :int8)

      assert %Vector{type: :vector_int8, data: ^packed} = vector
      assert Vector.to_list(vector) == [42, -1]
    end
  end

  describe "dimension/1" do
    test "fp32 dimension is byte_size / 4" do
      vector = Vector.from_list([1.0, 2.0, 3.0], :fp32)
      assert Vector.dimension(vector) == 3
    end

    test "fp64 dimension is byte_size / 8" do
      vector = Vector.from_list([1.0, 2.0], :fp64)
      assert Vector.dimension(vector) == 2
    end

    test "fp16 dimension is byte_size / 2" do
      vector = Vector.from_list([1.0, 2.0, 3.0], :fp16)
      assert Vector.dimension(vector) == 3
    end

    test "int8 dimension is byte_size" do
      vector = Vector.from_list([1, 2, 3, 4, 5], :int8)
      assert Vector.dimension(vector) == 5
    end

    test "int16 dimension is byte_size / 2" do
      vector = Vector.from_list([1, 2, 3], :int16)
      assert Vector.dimension(vector) == 3
    end

    test "int4 dimension is byte_size * 2" do
      vector = Vector.from_list([1, 2, 3, 4], :int4)
      assert Vector.dimension(vector) == 4
    end

    test "binary32 dimension is byte_size * 8" do
      # 8 bits packed into 1 byte
      vector = Vector.from_list([1, 0, 1, 1, 0, 0, 1, 0], :binary32)
      assert Vector.dimension(vector) == 8
    end

    test "binary64 dimension is byte_size * 8" do
      vector = Vector.from_list([1, 0, 1, 1, 0, 0, 1, 0], :binary64)
      assert Vector.dimension(vector) == 8
    end
  end

  describe "sparse vectors" do
    test "from_sparse/3 round-trip for sparse_fp32" do
      indices = [0, 5, 10]
      values = [1.0, 2.5, -3.0]
      vector = Vector.from_sparse(indices, values, :sparse_fp32)

      assert %Vector{type: :sparse_vector_fp32} = vector
      assert {^indices, ^values} = Vector.to_sparse(vector)
    end

    test "from_sparse/3 round-trip for sparse_fp16" do
      indices = [0, 5, 10]
      values = [1.0, 2.5, -3.0]
      vector = Vector.from_sparse(indices, values, :sparse_fp16)

      assert %Vector{type: :sparse_vector_fp16} = vector
      {result_indices, result_values} = Vector.to_sparse(vector)

      assert result_indices == indices

      Enum.zip(values, result_values)
      |> Enum.each(fn {expected, actual} ->
        assert_in_delta expected, actual, 0.01
      end)
    end

    test "sparse?/1 returns true for sparse vectors" do
      vector = Vector.from_sparse([0, 1], [1.0, 2.0], :sparse_fp32)
      assert Vector.sparse?(vector)
    end

    test "sparse?/1 returns false for dense vectors" do
      vector = Vector.from_list([1.0, 2.0], :fp32)
      refute Vector.sparse?(vector)
    end

    test "nnz/1 returns correct count" do
      vector = Vector.from_sparse([0, 5, 10], [1.0, 2.5, -3.0], :sparse_fp32)
      assert Vector.nnz(vector) == 3
    end

    test "nnz/1 raises for dense vectors" do
      vector = Vector.from_list([1.0, 2.0], :fp32)

      assert_raise ArgumentError, ~r/sparse/, fn ->
        Vector.nnz(vector)
      end
    end

    test "dimension/1 returns nil for sparse vectors" do
      vector = Vector.from_sparse([0, 1], [1.0, 2.0], :sparse_fp32)
      assert Vector.dimension(vector) == nil
    end

    test "to_list/1 raises for sparse vectors" do
      vector = Vector.from_sparse([0, 1], [1.0, 2.0], :sparse_fp32)

      assert_raise ArgumentError, ~r/sparse/, fn ->
        Vector.to_list(vector)
      end
    end

    test "from_sparse/3 raises on unsorted indices" do
      assert_raise ArgumentError, ~r/sorted/, fn ->
        Vector.from_sparse([5, 0, 10], [1.0, 2.0, 3.0], :sparse_fp32)
      end
    end

    test "from_sparse/3 raises on duplicate indices" do
      assert_raise ArgumentError, ~r/duplicate/, fn ->
        Vector.from_sparse([0, 5, 5], [1.0, 2.0, 3.0], :sparse_fp32)
      end
    end

    test "from_sparse/3 raises on mismatched lengths" do
      assert_raise ArgumentError, ~r/length/, fn ->
        Vector.from_sparse([0, 5], [1.0, 2.0, 3.0], :sparse_fp32)
      end
    end

    test "from_sparse/3 raises on non-sparse type" do
      assert_raise ArgumentError, ~r/sparse/, fn ->
        Vector.from_sparse([0, 1], [1.0, 2.0], :vector_fp32)
      end
    end

    test "from_sparse/3 raises on negative index" do
      assert_raise ArgumentError, ~r/non-negative/, fn ->
        Vector.from_sparse([-1], [1.0], :sparse_fp32)
      end
    end

    test "from_sparse/3 raises on float index" do
      assert_raise ArgumentError, ~r/integers/, fn ->
        Vector.from_sparse([0, 1.5], [1.0, 2.0], :sparse_fp32)
      end
    end

    test "empty sparse vector round-trip" do
      vector = Vector.from_sparse([], [], :sparse_fp32)

      assert %Vector{type: :sparse_vector_fp32} = vector
      assert {[], []} = Vector.to_sparse(vector)
      assert Vector.nnz(vector) == 0
    end

    test "from_list/2 raises with sparse shorthand" do
      assert_raise FunctionClauseError, fn ->
        Vector.from_list([1.0, 2.0], :sparse_fp32)
      end
    end

    test "from_binary/2 raises with sparse shorthand" do
      assert_raise FunctionClauseError, fn ->
        Vector.from_binary(<<1, 2, 3>>, :sparse_fp32)
      end
    end

    test "binary layout verification" do
      indices = [2, 7]
      values = [1.5, -2.0]
      vector = Vector.from_sparse(indices, values, :sparse_fp32)

      <<nnz::unsigned-little-64, rest::binary>> = vector.data
      assert nnz == 2

      indices_size = 2 * 4
      <<indices_bin::binary-size(indices_size), values_bin::binary>> = rest

      parsed_indices = for <<i::unsigned-little-32 <- indices_bin>>, do: i
      assert parsed_indices == [2, 7]

      parsed_values = for <<v::little-float-32 <- values_bin>>, do: v
      assert parsed_values == [1.5, -2.0]
    end
  end

  describe "edge cases" do
    test "empty list for fp32" do
      vector = Vector.from_list([], :fp32)

      assert %Vector{type: :vector_fp32} = vector
      assert Vector.to_list(vector) == []
      assert Vector.dimension(vector) == 0
    end

    test "single element fp32" do
      vector = Vector.from_list([42.0], :fp32)

      assert Vector.to_list(vector) == [42.0]
      assert Vector.dimension(vector) == 1
    end

    test "single element int8" do
      vector = Vector.from_list([99], :int8)

      assert Vector.to_list(vector) == [99]
      assert Vector.dimension(vector) == 1
    end

    test "fp16 negative zero round-trip" do
      vector = Vector.from_list([-0.0], :fp16)
      [val] = Vector.to_list(vector)
      assert val == -0.0
      assert <<1::1, _::31>> = <<val::float-32>>
    end

    test "fp16 infinity round-trip" do
      large = 1.0e30
      vector = Vector.from_list([large, -large], :fp16)
      assert [:infinity, :neg_infinity] = Vector.to_list(vector)
    end

    test "empty list for int4" do
      vector = Vector.from_list([], :int4)

      assert Vector.to_list(vector) == []
      assert Vector.dimension(vector) == 0
    end

    test "empty list for binary32" do
      vector = Vector.from_list([], :binary32)

      assert Vector.to_list(vector) == []
      assert Vector.dimension(vector) == 0
    end
  end
end
