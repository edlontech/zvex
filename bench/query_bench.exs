alias Zvex.{Collection, Collection.Schema, Document, Query, Vector}

defmodule Bench.QueryHelpers do
  @dim 128

  def dim, do: @dim

  def schema do
    Schema.new("bench_query")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32,
      dimension: @dim,
      index: [type: :hnsw, metric: :cosine, m: 16, ef_construction: 200]
    )
    |> Schema.add_field("category", :string, nullable: true, index: [type: :invert])
    |> Schema.add_field("value", :double, nullable: true)
  end

  def random_vector(dim) do
    Enum.map(1..dim, fn _ -> :rand.uniform() * 2 - 1 end)
  end

  def make_doc(i) do
    pk = "doc-#{i}"
    vec = Vector.from_list(random_vector(@dim), :fp32)

    Document.new()
    |> Document.put_pk(pk)
    |> Document.put("id", pk)
    |> Document.put("embedding", vec)
    |> Document.put("category", Enum.random(["books", "music", "movies", "games"]))
    |> Document.put("value", :rand.uniform() * 100)
  end

  def seed_collection(size) do
    ts = System.system_time(:nanosecond)
    uniq = System.unique_integer([:positive])

    dir =
      Path.join(System.tmp_dir!(), "zvex_qbench_#{size}_#{ts}_#{uniq}")

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    path = Path.join(dir, "collection")
    coll = Collection.create!(path, schema())

    1..size
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      docs = Enum.map(chunk, &make_doc/1)
      Collection.insert!(coll, docs)
    end)

    Collection.optimize!(coll)
    {coll, dir}
  end

  def cleanup(coll, dir) do
    Collection.close(coll)
    File.rm_rf!(dir)
  end
end

Zvex.initialize!()

# --- Query across different collection sizes ---

for size <- [1_000, 10_000, 50_000] do
  IO.puts("\n=== Collection size: #{size} documents ===\n")
  {coll, dir} = Bench.QueryHelpers.seed_collection(size)
  query_vec = Vector.from_list(Bench.QueryHelpers.random_vector(Bench.QueryHelpers.dim()), :fp32)

  Benchee.run(
    %{
      "top_k=10" => fn ->
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(10)
        |> Query.execute!(coll)
      end,
      "top_k=100" => fn ->
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(100)
        |> Query.execute!(coll)
      end,
      "top_k=10 + filter" => fn ->
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(10)
        |> Query.filter("category = 'books'")
        |> Query.execute!(coll)
      end,
      "top_k=10 + output_fields" => fn ->
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(10)
        |> Query.output_fields(["category", "value"])
        |> Query.execute!(coll)
      end,
      # NOTE: flat (brute force) query omitted -- causes segfault in NIF layer
      "hnsw ef=64 top_k=10" => fn ->
        Query.new()
        |> Query.field("embedding")
        |> Query.vector(query_vec)
        |> Query.top_k(10)
        |> Query.hnsw(ef: 64)
        |> Query.execute!(coll)
      end
    },
    time: 10,
    memory_time: 2,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.Markdown, file: "bench/output/query_#{size}.md"}
    ]
  )

  Bench.QueryHelpers.cleanup(coll, dir)
end

# --- HNSW ef parameter sweep ---

IO.puts("\n=== HNSW ef parameter sweep (10k docs) ===\n")
{coll, dir} = Bench.QueryHelpers.seed_collection(10_000)
query_vec = Vector.from_list(Bench.QueryHelpers.random_vector(Bench.QueryHelpers.dim()), :fp32)

ef_scenarios =
  for ef <- [16, 32, 64, 128, 256], into: %{} do
    {"ef=#{ef}",
     fn ->
       Query.new()
       |> Query.field("embedding")
       |> Query.vector(query_vec)
       |> Query.top_k(10)
       |> Query.hnsw(ef: ef)
       |> Query.execute!(coll)
     end}
  end

Benchee.run(
  ef_scenarios,
  time: 10,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/query_hnsw_ef.md"}
  ]
)

Bench.QueryHelpers.cleanup(coll, dir)

Zvex.shutdown()
