defmodule Zvex.Vector do
  @moduledoc """
  Pure Elixir vector packing/unpacking for dense vector types.

  Converts between Elixir lists and native-endian binary representations
  used by zvec. Supports fp16, fp32, fp64, int4, int8, int16, binary32,
  and binary64 vector types.

  ## Example

      iex> vector = Zvex.Vector.from_list([1.0, 2.0, 3.0], :fp32)
      iex> Zvex.Vector.to_list(vector)
      [1.0, 2.0, 3.0]
      iex> Zvex.Vector.dimension(vector)
      3
  """

  import Bitwise

  @enforce_keys [:type, :data]
  defstruct [:type, :data]

  @type t :: %__MODULE__{
          type: type(),
          data: binary()
        }

  @type type ::
          :vector_fp16
          | :vector_fp32
          | :vector_fp64
          | :vector_int4
          | :vector_int8
          | :vector_int16
          | :vector_binary32
          | :vector_binary64

  @type shorthand ::
          :fp16 | :fp32 | :fp64 | :int4 | :int8 | :int16 | :binary32 | :binary64

  @shorthands %{
    fp16: :vector_fp16,
    fp32: :vector_fp32,
    fp64: :vector_fp64,
    int4: :vector_int4,
    int8: :vector_int8,
    int16: :vector_int16,
    binary32: :vector_binary32,
    binary64: :vector_binary64
  }

  @spec from_list([number()], shorthand()) :: t()
  def from_list(list, type) when is_list(list) and is_map_key(@shorthands, type) do
    full_type = Map.fetch!(@shorthands, type)
    data = pack(list, type)
    %__MODULE__{type: full_type, data: data}
  end

  @spec from_binary(binary(), shorthand()) :: t()
  def from_binary(binary, type) when is_binary(binary) and is_map_key(@shorthands, type) do
    full_type = Map.fetch!(@shorthands, type)
    %__MODULE__{type: full_type, data: binary}
  end

  @spec to_list(t()) :: [number() | :infinity | :neg_infinity | :nan]
  def to_list(%__MODULE__{type: type, data: data}) do
    unpack(data, to_shorthand(type))
  end

  @spec dimension(t()) :: non_neg_integer()
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
end
