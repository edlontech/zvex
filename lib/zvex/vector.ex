defmodule Zvex.Vector do
  @moduledoc """
  Pure Elixir vector packing/unpacking for dense and sparse vector types.

  Converts between Elixir lists and native-endian binary representations
  used by zvec. Supports fp16, fp32, fp64, int4, int8, int16, binary32,
  and binary64 dense vector types, as well as sparse_fp16 and sparse_fp32
  sparse vector types.

  ## Dense Example

      iex> vector = Zvex.Vector.from_list([1.0, 2.0, 3.0], :fp32)
      iex> Zvex.Vector.to_list(vector)
      [1.0, 2.0, 3.0]
      iex> Zvex.Vector.dimension(vector)
      3

  ## Sparse Example

      iex> vector = Zvex.Vector.from_sparse([0, 5, 10], [1.0, 2.5, -3.0], :sparse_fp32)
      iex> Zvex.Vector.to_sparse(vector)
      {[0, 5, 10], [1.0, 2.5, -3.0]}
      iex> Zvex.Vector.sparse?(vector)
      true
  """

  import Bitwise

  @enforce_keys [:type, :data]
  defstruct [:type, :data]

  @type t :: %__MODULE__{
          type: type(),
          data: binary()
        }

  @typedoc "Full vector type atom as stored in the struct and in document fields."
  @type type ::
          :vector_fp16
          | :vector_fp32
          | :vector_fp64
          | :vector_int4
          | :vector_int8
          | :vector_int16
          | :vector_binary32
          | :vector_binary64
          | :sparse_vector_fp16
          | :sparse_vector_fp32

  @typedoc """
  Shorthand alias used in `from_list/2`, `from_binary/2`, and `from_sparse/3`.

  Each shorthand maps to a full type (e.g. `:fp32` -> `:vector_fp32`,
  `:sparse_fp32` -> `:sparse_vector_fp32`).
  """
  @type shorthand ::
          :fp16
          | :fp32
          | :fp64
          | :int4
          | :int8
          | :int16
          | :binary32
          | :binary64
          | :sparse_fp16
          | :sparse_fp32

  @shorthands %{
    fp16: :vector_fp16,
    fp32: :vector_fp32,
    fp64: :vector_fp64,
    int4: :vector_int4,
    int8: :vector_int8,
    int16: :vector_int16,
    binary32: :vector_binary32,
    binary64: :vector_binary64,
    sparse_fp16: :sparse_vector_fp16,
    sparse_fp32: :sparse_vector_fp32
  }

  @sparse_types [:sparse_vector_fp16, :sparse_vector_fp32]
  @dense_shorthands Map.drop(@shorthands, [:sparse_fp16, :sparse_fp32])

  @doc """
  Packs a list of numbers into a dense vector binary.

  The `type` is a shorthand atom (e.g. `:fp32`, `:int8`). Sparse shorthands
  are not accepted — use `from_sparse/3` instead.

  ## Examples

      iex> vec = Zvex.Vector.from_list([1.0, 2.0, 3.0], :fp32)
      iex> Zvex.Vector.dimension(vec)
      3
  """
  @spec from_list([number()], shorthand()) :: t()
  def from_list(list, type) when is_list(list) and is_map_key(@dense_shorthands, type) do
    full_type = Map.fetch!(@dense_shorthands, type)
    data = pack(list, type)
    %__MODULE__{type: full_type, data: data}
  end

  @doc """
  Wraps a pre-packed binary as a dense vector of the given `type`.

  No validation is performed on the binary contents — it is assumed to
  already be in the correct native-endian format for the given type.
  """
  @spec from_binary(binary(), shorthand()) :: t()
  def from_binary(binary, type) when is_binary(binary) and is_map_key(@dense_shorthands, type) do
    full_type = Map.fetch!(@dense_shorthands, type)
    %__MODULE__{type: full_type, data: binary}
  end

  @doc """
  Creates a sparse vector from index and value lists.

  The `type` must be either `:sparse_fp32` or `:sparse_fp16`.
  Indices must be non-negative, sorted in ascending order, with no duplicates.
  The indices and values lists must have the same length.

  The binary layout is `[nnz::uint64-little][indices::uint32-little * nnz][values::type * nnz]`.
  """
  @sparse_shorthands %{sparse_fp16: :sparse_vector_fp16, sparse_fp32: :sparse_vector_fp32}

  @spec from_sparse([non_neg_integer()], [number()], type() | shorthand()) :: t()
  def from_sparse(indices, values, type) when is_list(indices) and is_list(values) do
    full_type = resolve_sparse_type!(type)

    if length(indices) != length(values) do
      raise ArgumentError, "indices and values must have the same length"
    end

    validate_sparse_indices!(indices)
    data = pack_sparse(indices, values, full_type)
    %__MODULE__{type: full_type, data: data}
  end

  @doc """
  Unpacks a sparse vector back to `{indices, values}`.

  Raises `ArgumentError` if the vector is not a sparse type.
  """
  @spec to_sparse(t()) :: {[non_neg_integer()], [number()]}
  def to_sparse(%__MODULE__{type: type, data: data}) when type in @sparse_types do
    unpack_sparse(data, type)
  end

  def to_sparse(%__MODULE__{type: type}) do
    raise ArgumentError, "expected a sparse vector, got #{inspect(type)}"
  end

  @doc """
  Returns `true` if the vector is a sparse type.
  """
  @spec sparse?(t()) :: boolean()
  def sparse?(%__MODULE__{type: type}), do: type in @sparse_types

  @doc """
  Returns the number of non-zero elements in a sparse vector.

  Raises `ArgumentError` for dense vectors.
  """
  @spec nnz(t()) :: non_neg_integer()
  def nnz(%__MODULE__{type: type, data: <<nnz::unsigned-little-64, _rest::binary>>})
      when type in @sparse_types do
    nnz
  end

  def nnz(%__MODULE__{type: type}) do
    raise ArgumentError, "expected a sparse vector, got #{inspect(type)}"
  end

  @doc """
  Unpacks a dense vector back to a list of numbers.

  For fp16 vectors, special IEEE 754 values may appear as `:infinity`,
  `:neg_infinity`, or `:nan`. Sparse vectors are not supported — use
  `to_sparse/1` instead.
  """
  @spec to_list(t()) :: [number() | :infinity | :neg_infinity | :nan]
  def to_list(%__MODULE__{type: type}) when type in @sparse_types do
    raise ArgumentError, "to_list/1 is not supported for sparse vectors, use to_sparse/1"
  end

  def to_list(%__MODULE__{type: type, data: data}) do
    unpack(data, to_shorthand(type))
  end

  @doc """
  Returns the number of elements (dimension) in a dense vector.

  Returns `nil` for sparse vectors, since sparse vectors don't have a fixed
  dimension. Use `nnz/1` to get the number of non-zero entries instead.
  """
  @spec dimension(t()) :: non_neg_integer() | nil
  def dimension(%__MODULE__{type: type}) when type in @sparse_types, do: nil

  def dimension(%__MODULE__{type: type, data: data}) do
    dim(byte_size(data), to_shorthand(type))
  end

  # -- Packing -----------------------------------------------------------

  defp pack(list, :fp32), do: Enum.reduce(list, <<>>, &(&2 <> <<&1::native-float-32>>))
  defp pack(list, :fp64), do: Enum.reduce(list, <<>>, &(&2 <> <<&1::native-float-64>>))
  defp pack(list, :fp16), do: Enum.reduce(list, <<>>, &(&2 <> encode_fp16(&1)))
  defp pack(list, :int8), do: Enum.reduce(list, <<>>, &(&2 <> <<&1::native-signed-8>>))
  defp pack(list, :int16), do: Enum.reduce(list, <<>>, &(&2 <> <<&1::native-signed-16>>))
  defp pack(list, :int4), do: pack_nibbles(list)
  defp pack(list, :binary32), do: pack_bits(list)
  defp pack(list, :binary64), do: pack_bits(list)

  # -- Unpacking ---------------------------------------------------------

  defp unpack(<<>>, _type), do: []
  defp unpack(data, :fp32), do: unpack_fp32(data, [])
  defp unpack(data, :fp64), do: unpack_fp64(data, [])
  defp unpack(data, :fp16), do: unpack_fp16(data, [])
  defp unpack(data, :int8), do: unpack_int8(data, [])
  defp unpack(data, :int16), do: unpack_int16(data, [])
  defp unpack(data, :int4), do: unpack_nibbles(data, [])
  defp unpack(data, :binary32), do: unpack_bits(data, [])
  defp unpack(data, :binary64), do: unpack_bits(data, [])

  defp unpack_fp32(<<>>, acc), do: Enum.reverse(acc)
  defp unpack_fp32(<<v::native-float-32, rest::binary>>, acc), do: unpack_fp32(rest, [v | acc])

  defp unpack_fp64(<<>>, acc), do: Enum.reverse(acc)
  defp unpack_fp64(<<v::native-float-64, rest::binary>>, acc), do: unpack_fp64(rest, [v | acc])

  defp unpack_fp16(<<>>, acc), do: Enum.reverse(acc)

  defp unpack_fp16(<<bytes::binary-size(2), rest::binary>>, acc),
    do: unpack_fp16(rest, [decode_fp16(bytes) | acc])

  defp unpack_int8(<<>>, acc), do: Enum.reverse(acc)
  defp unpack_int8(<<v::native-signed-8, rest::binary>>, acc), do: unpack_int8(rest, [v | acc])

  defp unpack_int16(<<>>, acc), do: Enum.reverse(acc)
  defp unpack_int16(<<v::native-signed-16, rest::binary>>, acc), do: unpack_int16(rest, [v | acc])

  # -- Nibble packing (int4) ---------------------------------------------

  defp pack_nibbles(list) do
    list
    |> Enum.chunk_every(2, 2, [0])
    |> Enum.reduce(<<>>, fn
      [hi, lo], acc -> acc <> <<hi::4, lo::4>>
    end)
  end

  defp unpack_nibbles(<<>>, acc), do: Enum.reverse(acc)

  defp unpack_nibbles(<<hi::4, lo::4, rest::binary>>, acc),
    do: unpack_nibbles(rest, [lo, hi | acc])

  # -- Bit packing (binary32/binary64) -----------------------------------

  defp pack_bits(list) do
    list
    |> Enum.chunk_every(8, 8, List.duplicate(0, 8))
    |> Enum.reduce(<<>>, fn bits, acc ->
      byte = Enum.reduce(bits, 0, fn bit, b -> b * 2 + bit end)
      acc <> <<byte::8>>
    end)
  end

  defp unpack_bits(<<>>, acc), do: Enum.reverse(acc) |> List.flatten()

  defp unpack_bits(<<byte::8, rest::binary>>, acc) do
    bits = for i <- 7..0//-1, do: byte >>> i &&& 1
    unpack_bits(rest, [bits | acc])
  end

  # -- FP16 IEEE 754 half-precision --------------------------------------

  defp encode_fp16(val) do
    <<sign::1, exp::8, mant::23>> = <<val::float-32>>
    encode_fp16_parts(sign, exp, mant)
  end

  defp encode_fp16_parts(sign, 0, _mant) do
    <<sign::1, 0::5, 0::10>>
  end

  defp encode_fp16_parts(sign, 255, mant) do
    fp16_mant = mant >>> 13
    <<sign::1, 31::5, fp16_mant::10>>
  end

  defp encode_fp16_parts(sign, exp, mant) do
    new_exp = exp - 127 + 15

    cond do
      new_exp >= 31 ->
        <<sign::1, 31::5, 0::10>>

      new_exp > 0 ->
        shifted_mant = mant >>> 13
        <<sign::1, new_exp::5, shifted_mant::10>>

      new_exp > -10 ->
        fp16_mant = (mant ||| 0x800000) >>> (14 - new_exp)
        <<sign::1, 0::5, fp16_mant::10>>

      true ->
        <<sign::1, 0::5, 0::10>>
    end
  end

  defp decode_fp16(<<sign::1, exp::5, mant::10>>) do
    decode_fp16_parts(sign, exp, mant)
  end

  defp decode_fp16_parts(sign, 0, 0) do
    <<f::float-32>> = <<sign::1, 0::8, 0::23>>
    f
  end

  defp decode_fp16_parts(sign, 0, mant) do
    val = mant / 1024.0 * :math.pow(2, -14)
    if sign == 1, do: -val, else: val
  end

  defp decode_fp16_parts(sign, 31, 0) do
    if sign == 1, do: :neg_infinity, else: :infinity
  end

  defp decode_fp16_parts(_sign, 31, _mant), do: :nan

  defp decode_fp16_parts(sign, exp, mant) do
    fp32_exp = exp - 15 + 127
    fp32_mant = mant <<< 13
    <<val::float-32>> = <<sign::1, fp32_exp::8, fp32_mant::23>>
    val
  end

  # -- Dimension ----------------------------------------------------------

  defp dim(size, :fp32), do: div(size, 4)
  defp dim(size, :fp64), do: div(size, 8)
  defp dim(size, :fp16), do: div(size, 2)
  defp dim(size, :int8), do: size
  defp dim(size, :int16), do: div(size, 2)
  defp dim(size, :int4), do: size * 2
  defp dim(size, :binary32), do: size * 8
  defp dim(size, :binary64), do: size * 8

  # -- Helpers ------------------------------------------------------------

  defp to_shorthand(:vector_fp16), do: :fp16
  defp to_shorthand(:vector_fp32), do: :fp32
  defp to_shorthand(:vector_fp64), do: :fp64
  defp to_shorthand(:vector_int4), do: :int4
  defp to_shorthand(:vector_int8), do: :int8
  defp to_shorthand(:vector_int16), do: :int16
  defp to_shorthand(:vector_binary32), do: :binary32
  defp to_shorthand(:vector_binary64), do: :binary64

  # -- Sparse helpers -------------------------------------------------------

  defp resolve_sparse_type!(type) when type in @sparse_types, do: type

  defp resolve_sparse_type!(type) when is_map_key(@sparse_shorthands, type) do
    Map.fetch!(@sparse_shorthands, type)
  end

  defp resolve_sparse_type!(type) do
    raise ArgumentError, "expected a sparse type, got #{inspect(type)}"
  end

  defp validate_sparse_indices!([]), do: :ok

  defp validate_sparse_indices!([first | _]) when not is_integer(first) do
    raise ArgumentError, "sparse indices must be integers"
  end

  defp validate_sparse_indices!([first | _]) when first < 0 do
    raise ArgumentError, "sparse indices must be non-negative and sorted in ascending order"
  end

  defp validate_sparse_indices!([_single]), do: :ok

  defp validate_sparse_indices!([_a, b | _]) when not is_integer(b) do
    raise ArgumentError, "sparse indices must be integers"
  end

  defp validate_sparse_indices!([a, b | _]) when a > b do
    raise ArgumentError, "sparse indices must be sorted in ascending order"
  end

  defp validate_sparse_indices!([a, a | _]) do
    raise ArgumentError, "sparse indices must not contain duplicate values"
  end

  defp validate_sparse_indices!([_ | rest]), do: validate_sparse_indices!(rest)

  defp pack_sparse(indices, values, :sparse_vector_fp32) do
    nnz = length(indices)
    indices_bin = Enum.reduce(indices, <<>>, &(&2 <> <<&1::unsigned-little-32>>))
    values_bin = Enum.reduce(values, <<>>, &(&2 <> <<&1::little-float-32>>))
    <<nnz::unsigned-little-64>> <> indices_bin <> values_bin
  end

  defp pack_sparse(indices, values, :sparse_vector_fp16) do
    nnz = length(indices)
    indices_bin = Enum.reduce(indices, <<>>, &(&2 <> <<&1::unsigned-little-32>>))
    values_bin = Enum.reduce(values, <<>>, &(&2 <> encode_fp16(&1)))
    <<nnz::unsigned-little-64>> <> indices_bin <> values_bin
  end

  defp unpack_sparse(<<nnz::unsigned-little-64, rest::binary>>, :sparse_vector_fp32) do
    indices_size = nnz * 4
    values_size = nnz * 4
    <<indices_bin::binary-size(indices_size), values_bin::binary-size(values_size)>> = rest
    indices = for <<i::unsigned-little-32 <- indices_bin>>, do: i
    values = for <<v::little-float-32 <- values_bin>>, do: v
    {indices, values}
  end

  defp unpack_sparse(<<nnz::unsigned-little-64, rest::binary>>, :sparse_vector_fp16) do
    indices_size = nnz * 4
    values_size = nnz * 2
    <<indices_bin::binary-size(indices_size), values_bin::binary-size(values_size)>> = rest
    indices = for <<i::unsigned-little-32 <- indices_bin>>, do: i
    values = for <<bytes::binary-size(2) <- values_bin>>, do: decode_fp16(bytes)
    {indices, values}
  end
end
