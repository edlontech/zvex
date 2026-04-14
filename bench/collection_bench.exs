alias Zvex.{Collection, Collection.Schema, Document, Vector}

defmodule Bench.Helpers do
  @dim 128

  def dim, do: @dim

  def schema do
    Schema.new("bench")
    |> Schema.add_field("id", :string, primary_key: true)
    |> Schema.add_field("embedding", :vector_fp32,
      dimension: @dim,
      index: [type: :hnsw, metric: :cosine]
    )
    |> Schema.add_field("category", :string, nullable: true, index: [type: :invert])
    |> Schema.add_field("score", :double, nullable: true)
  end

  def make_doc(i) do
    pk = "doc-#{i}"
    vec = Vector.from_list(random_vector(@dim), :fp32)

    Document.new()
    |> Document.put_pk(pk)
    |> Document.put("id", pk)
    |> Document.put("embedding", vec)
    |> Document.put("category", Enum.random(["a", "b", "c", "d"]))
    |> Document.put("score", :rand.uniform())
  end

  def make_docs(count) do
    Enum.map(1..count, &make_doc/1)
  end

  def random_vector(dim) do
    Enum.map(1..dim, fn _ -> :rand.uniform() * 2 - 1 end)
  end

  def fresh_collection(prefix) do
    ts = System.system_time(:nanosecond)
    uniq = System.unique_integer([:positive])

    dir =
      Path.join(System.tmp_dir!(), "zvex_bench_#{prefix}_#{ts}_#{uniq}")

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    path = Path.join(dir, "collection")
    coll = Collection.create!(path, schema())
    {coll, dir}
  end

  def cleanup(coll, dir) do
    Collection.close(coll)
    File.rm_rf!(dir)
  end
end

Zvex.initialize!()

# --- Batch insert at varying sizes ---

for batch_size <- [1, 10, 100, 1_000] do
  IO.puts("\n=== Insert batch_size=#{batch_size} ===\n")
  {coll, dir} = Bench.Helpers.fresh_collection("insert_#{batch_size}")
  counter = :counters.new(1, [:atomics])

  Benchee.run(
    %{
      "insert #{batch_size} docs" => fn docs -> Collection.insert!(coll, docs) end
    },
    before_each: fn _ ->
      offset = :counters.get(counter, 1) * batch_size
      :counters.add(counter, 1, 1)
      Enum.map(1..batch_size, &Bench.Helpers.make_doc(&1 + offset))
    end,
    time: 10,
    memory_time: 2,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.Markdown, file: "bench/output/collection_insert_#{batch_size}.md"}
    ]
  )

  Bench.Helpers.cleanup(coll, dir)
end

# --- Upsert benchmark (mix of new and existing) ---

IO.puts("\n=== Upsert 100 docs (50 existing + 50 new) ===\n")
{coll, dir} = Bench.Helpers.fresh_collection("upsert")
seed_docs = Bench.Helpers.make_docs(50)
Collection.insert!(coll, seed_docs)
upsert_counter = :counters.new(1, [:atomics])

Benchee.run(
  %{
    "upsert 100 docs" => fn docs -> Collection.upsert!(coll, docs) end
  },
  before_each: fn _ ->
    offset = :counters.get(upsert_counter, 1) * 50
    :counters.add(upsert_counter, 1, 1)
    existing = Enum.map(1..50, &Bench.Helpers.make_doc/1)
    new_docs = Enum.map(1..50, &Bench.Helpers.make_doc(&1 + 10_000 + offset))
    existing ++ new_docs
  end,
  time: 10,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/collection_upsert.md"}
  ]
)

Bench.Helpers.cleanup(coll, dir)

# --- Fetch benchmark ---

for size <- [1_000, 10_000] do
  IO.puts("\n=== Fetch from #{size} docs ===\n")
  {coll, dir} = Bench.Helpers.fresh_collection("fetch_#{size}")

  Bench.Helpers.make_docs(size)
  |> Enum.chunk_every(500)
  |> Enum.each(&Collection.insert!(coll, &1))

  fetch_inputs = %{
    "1 key" => ["doc-#{:rand.uniform(size)}"],
    "10 keys" => Enum.map(1..10, fn _ -> "doc-#{:rand.uniform(size)}" end),
    "100 keys" => Enum.map(1..100, fn _ -> "doc-#{:rand.uniform(size)}" end)
  }

  Benchee.run(
    %{
      "fetch" => fn keys -> Collection.fetch!(coll, keys) end
    },
    inputs: fetch_inputs,
    time: 5,
    memory_time: 2,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.Markdown, file: "bench/output/collection_fetch_#{size}.md"}
    ]
  )

  Bench.Helpers.cleanup(coll, dir)
end

# --- Delete benchmark ---

IO.puts("\n=== Delete from 5000 docs ===\n")
{coll, dir} = Bench.Helpers.fresh_collection("delete")

Bench.Helpers.make_docs(5_000)
|> Enum.chunk_every(500)
|> Enum.each(&Collection.insert!(coll, &1))

Benchee.run(
  %{
    "delete 100 docs by pk" => fn keys -> Collection.delete!(coll, keys) end,
    "delete_by_filter" => fn _keys ->
      Collection.delete_by_filter!(coll, "category = 'a'")
    end
  },
  before_each: fn _ ->
    Enum.map(1..100, fn _ -> "doc-#{:rand.uniform(5_000)}" end)
  end,
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/collection_delete.md"}
  ]
)

Bench.Helpers.cleanup(coll, dir)

Zvex.shutdown()
