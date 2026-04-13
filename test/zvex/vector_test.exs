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
      input = [1, -1, 32767, -32768, 0]
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
