alias Zvex.Vector

dimensions = [128, 768, 1536]

inputs =
  for dim <- dimensions, into: %{} do
    {"dim_#{dim}", Enum.map(1..dim, fn i -> i / dim end)}
  end

Benchee.run(
  %{
    "from_list fp32" => fn list -> Vector.from_list(list, :fp32) end,
    "from_list fp16" => fn list -> Vector.from_list(list, :fp16) end,
    "from_list fp64" => fn list -> Vector.from_list(list, :fp64) end,
    "from_list int8" => fn list ->
      list |> Enum.map(&trunc(&1 * 127)) |> Vector.from_list(:int8)
    end
  },
  inputs: inputs,
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/vector_packing.md"}
  ]
)

packed_inputs =
  for dim <- dimensions, into: %{} do
    list = Enum.map(1..dim, fn i -> i / dim end)
    {"dim_#{dim}", Vector.from_list(list, :fp32)}
  end

Benchee.run(
  %{
    "to_list fp32" => fn vec -> Vector.to_list(vec) end
  },
  inputs: packed_inputs,
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/vector_unpacking.md"}
  ]
)

sparse_inputs =
  for nnz <- [100, 500, 1000], into: %{} do
    indices = Enum.to_list(0..(nnz - 1))
    values = Enum.map(1..nnz, fn i -> i / nnz end)
    {"nnz_#{nnz}", {indices, values}}
  end

Benchee.run(
  %{
    "from_sparse fp32" => fn {idx, vals} -> Vector.from_sparse(idx, vals, :sparse_fp32) end,
    "from_sparse fp16" => fn {idx, vals} -> Vector.from_sparse(idx, vals, :sparse_fp16) end
  },
  inputs: sparse_inputs,
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/vector_sparse.md"}
  ]
)
