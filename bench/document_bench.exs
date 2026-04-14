alias Zvex.{Document, Vector, Collection.Schema}

dim = 128

schema =
  Schema.new("bench")
  |> Schema.add_field("id", :string, primary_key: true)
  |> Schema.add_field("embedding", :vector_fp32, dimension: dim)
  |> Schema.add_field("title", :string, nullable: true)
  |> Schema.add_field("score", :double, nullable: true)

vector = Vector.from_list(Enum.map(1..dim, fn i -> i / dim end), :fp32)

map_input = %{
  "id" => "doc-1",
  "embedding" => vector,
  "title" => "Hello world",
  "score" => 0.95
}

doc =
  Document.new()
  |> Document.put_pk("doc-1")
  |> Document.put("id", "doc-1")
  |> Document.put("embedding", vector)
  |> Document.put("title", "Hello world")
  |> Document.put("score", 0.95)

{:ok, serialized} = Document.serialize(doc)

Benchee.run(
  %{
    "new + put fields" => fn ->
      Document.new()
      |> Document.put_pk("doc-1")
      |> Document.put("id", "doc-1")
      |> Document.put("embedding", vector)
      |> Document.put("title", "Hello world")
      |> Document.put("score", 0.95)
    end,
    "from_map" => fn -> Document.from_map(map_input, schema) end,
    "to_map" => fn -> Document.to_map(doc) end,
    "serialize" => fn -> Document.serialize!(doc) end,
    "deserialize" => fn -> Document.deserialize!(serialized) end,
    "merge two docs" => fn ->
      other =
        Document.new()
        |> Document.put_pk("doc-1")
        |> Document.put("extra", "value")

      Document.merge(doc, other)
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.Markdown, file: "bench/output/document.md"}
  ]
)
