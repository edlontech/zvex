# Zvex

Elixir bindings for [zvec](https://github.com/alibaba/zvec), an in-process vector database. Zvex provides type-safe, idiomatic Elixir access to zvec's vector indexing and similarity search through Zig-based NIF bindings.

## Features

- **Vector similarity search** with HNSW, IVF, and flat index types
- **Multiple vector types** -- fp16, fp32, fp64, int4, int8, int16, binary32, binary64, and sparse vectors
- **Distance metrics** -- L2, inner product, cosine, and MIPS-L2
- **Quantization** -- fp16, int8, and int4 for reduced memory usage
- **Schema-based collections** with typed fields and index configuration
- **Document CRUD** -- insert, update, upsert, delete, and fetch operations
- **Filtered search** with scalar field predicates
- **Telemetry integration** for observability
- **Structured errors** via Splode

## Installation

Add `zvex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zvex, "~> 0.1.0"}
  ]
end
```

`zvex` ships prebuilt `libzvec_c_api` binaries for the targets listed below. On `mix deps.compile`, the matching binary is downloaded from the GitHub Releases for this repo and verified via SHA256. Zig is still required (the NIF compiles locally via Zigler).

### Supported prebuilt targets

- `linux-x86_64-gnu` (glibc >= 2.35 / Ubuntu 22.04+)
- `linux-aarch64-gnu`
- `linux-x86_64-musl` (Alpine)
- `darwin-aarch64` (Apple Silicon)

Other targets (e.g. Windows, FreeBSD, darwin-x86_64) fall through to a source build requiring `cmake` + a C++ toolchain + the `c_src/zvec` git submodule.

### Environment variables

| Variable          | Effect                                                                  |
|-------------------|-------------------------------------------------------------------------|
| `ZVEX_BUILD=true` | Skip download, build `libzvec_c_api` from the vendored submodule.       |
| `ZVEX_BUILD_URL`  | Override the download prefix (private mirrors, airgapped environments). |

## Quick Start

```elixir
# Initialize the library
Zvex.initialize!()

# Define a collection schema
schema =
  Zvex.Collection.Schema.new("my_collection")
  |> Zvex.Collection.Schema.add_field("embedding", :vector_fp32, dimension: 128, index: :hnsw)
  |> Zvex.Collection.Schema.add_field("title", :string, index: :invert)

# Create and open a collection
{:ok, collection} = Zvex.Collection.create("/tmp/my_collection", schema)

# Build and insert a document
doc =
  Zvex.Document.new()
  |> Zvex.Document.put_pk(1)
  |> Zvex.Document.put("embedding", Zvex.Vector.from_list(:fp32, List.duplicate(0.5, 128)))
  |> Zvex.Document.put("title", "Hello world")

:ok = Zvex.Collection.insert(collection, [doc])

# Query nearest neighbors
results =
  Zvex.Query.new()
  |> Zvex.Query.field("embedding")
  |> Zvex.Query.vector(Zvex.Vector.from_list(:fp32, List.duplicate(0.5, 128)))
  |> Zvex.Query.top_k(10)
  |> Zvex.Query.hnsw(ef: 100)
  |> Zvex.Query.output_fields(["title"])
  |> Zvex.Query.execute!(collection)

# Clean up
Zvex.Collection.close!(collection)
Zvex.Collection.drop!("/tmp/my_collection")
Zvex.shutdown!()
```

## API Overview

### Initialization

```elixir
# Default configuration
Zvex.initialize!()

# Custom configuration
config =
  Zvex.Config.new()
  |> Zvex.Config.memory_limit(1_073_741_824)
  |> Zvex.Config.query_threads(4)
  |> Zvex.Config.optimize_threads(2)
  |> Zvex.Config.log(:console, level: :info)

Zvex.initialize!(config)
```

### Schema Definition

Schemas define the structure and indexing of a collection.

```elixir
schema =
  Zvex.Collection.Schema.new("products")
  |> Zvex.Collection.Schema.add_field("embedding", :vector_fp32,
    dimension: 768,
    index: :hnsw,
    metric: :cosine,
    m: 16,
    ef_construction: 200
  )
  |> Zvex.Collection.Schema.add_field("name", :string, index: :invert)
  |> Zvex.Collection.Schema.add_field("price", :double)
  |> Zvex.Collection.Schema.add_field("tags", :array_string)
```

#### Data Types

| Category | Types |
|----------|-------|
| Dense vectors | `vector_fp32`, `vector_fp16`, `vector_fp64`, `vector_int4`, `vector_int8`, `vector_int16`, `vector_binary32`, `vector_binary64` |
| Sparse vectors | `sparse_vector_fp16`, `sparse_vector_fp32` |
| Scalars | `string`, `int32`, `int64`, `uint32`, `uint64`, `float`, `double`, `bool`, `binary` |
| Arrays | `array_string`, `array_int32`, `array_int64`, `array_uint32`, `array_uint64`, `array_float`, `array_double`, `array_bool`, `array_binary` |

#### Index Types

| Index | Use Case | Key Options |
|-------|----------|-------------|
| `:hnsw` | Approximate nearest neighbor search | `:metric`, `:m`, `:ef_construction`, `:quantize` |
| `:ivf` | Large-scale partitioned search | `:metric`, `:n_list`, `:n_iters`, `:use_soar`, `:quantize` |
| `:flat` | Exact brute-force search | `:metric`, `:quantize` |
| `:invert` | Scalar field filtering | `:enable_range_opt`, `:enable_wildcard` |

### Collections

```elixir
# Create
{:ok, collection} = Zvex.Collection.create("/path/to/data", schema)

# Open existing
{:ok, collection} = Zvex.Collection.open("/path/to/data", schema)

# Open options
{:ok, collection} = Zvex.Collection.open("/path/to/data", schema,
  mmap: true,
  read_only: true,
  max_buffer_size: 67_108_864
)

# Maintenance
Zvex.Collection.flush(collection)
Zvex.Collection.optimize(collection)

# Introspection
{:ok, stats} = Zvex.Collection.stats(collection)
# => %Zvex.Collection.Stats{doc_count: 1000, indexes: [%{name: "embedding", completeness: 1.0}]}

# DDL operations
Zvex.Collection.create_index(collection, "new_field", index_params)
Zvex.Collection.drop_index(collection, "old_field")
Zvex.Collection.add_column(collection, "metadata", :string, "default_value")
Zvex.Collection.drop_column(collection, "metadata")
```

### Documents

```elixir
# Build documents
doc =
  Zvex.Document.new()
  |> Zvex.Document.put_pk(42)
  |> Zvex.Document.put("embedding", Zvex.Vector.from_list(:fp32, embedding_data))
  |> Zvex.Document.put("name", "Product A")
  |> Zvex.Document.put("price", 29.99)

# Build from a map (requires schema for type resolution)
doc = Zvex.Document.from_map(%{"pk" => 42, "name" => "Product A", "price" => 29.99}, schema)

# CRUD
Zvex.Collection.insert(collection, [doc1, doc2])
Zvex.Collection.update(collection, [updated_doc])
Zvex.Collection.upsert(collection, [doc])
Zvex.Collection.delete(collection, [42, 43])
Zvex.Collection.delete_by_filter(collection, "name = 'Product A'")

{:ok, docs} = Zvex.Collection.fetch(collection, [42])
```

### Vectors

```elixir
# Dense vectors
vec = Zvex.Vector.from_list(:fp32, [1.0, 2.0, 3.0])
vec = Zvex.Vector.from_binary(:fp16, binary_data)
list = Zvex.Vector.to_list(vec)
dim = Zvex.Vector.dimension(vec)

# Sparse vectors
vec = Zvex.Vector.from_sparse(:sparse_fp32, [0, 5, 10], [1.0, 0.5, 0.3])
{indices, values} = Zvex.Vector.to_sparse(vec)
nnz = Zvex.Vector.nnz(vec)
```

### Queries

```elixir
results =
  Zvex.Query.new()
  |> Zvex.Query.field("embedding")
  |> Zvex.Query.vector(query_vector)
  |> Zvex.Query.top_k(10)
  |> Zvex.Query.filter("price < 50.0")
  |> Zvex.Query.output_fields(["name", "price"])
  |> Zvex.Query.include_vector(true)
  |> Zvex.Query.hnsw(ef: 200)
  |> Zvex.Query.execute!(collection)

for result <- results do
  IO.puts("pk=#{result.pk} score=#{result.score} name=#{result.fields["name"]}")
end
```

Search algorithm options:

```elixir
# HNSW - approximate, fast
|> Zvex.Query.hnsw(ef: 200)

# IVF - partitioned search
|> Zvex.Query.ivf(n_probe: 16)

# Flat - exact brute-force
|> Zvex.Query.flat()
```

## Error Handling

All fallible functions come in two forms: `fun/n` returns `{:ok, result}` or `{:error, error}`, and `fun!/n` raises on failure.

Errors are structured via Splode into classes:

| Class | Errors |
|-------|--------|
| `Invalid` | `Argument`, `FailedPrecondition` |
| `NotFound` | `NotFound` |
| `Conflict` | `AlreadyExists` |
| `Unavailable` | `PermissionDenied`, `ResourceExhausted`, `Unavailable`, `NotSupported` |
| `Internal` | `InternalError` |
| `Unknown` | `Unknown` |

## Benchmarks

Run benchmarks with mix aliases:

```shell
mix bench.vector       # Vector packing/unpacking
mix bench.document     # Document creation and serialization
mix bench.collection   # Insert, upsert, delete, fetch
mix bench.query        # Vector search performance
mix bench.all          # Everything
```

## Development

```shell
# Run tests
mix test

# Run quality checks
mix check

# Generate docs
mix docs
```

## License

See [LICENSE](LICENSE) for details.
