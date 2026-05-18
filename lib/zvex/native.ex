defmodule Zvex.Native do
  @moduledoc """
  Low-level NIF bindings to the zvec C API.

  When a precompiled artifact is available for the host target — i.e. the
  Hex package ships `checksum-Elixir.Zvex.Native.exs` and the host triple
  is in the supported set — the NIF is downloaded from the matching
  `zvex-v<version>` GitHub release and verified via SHA-256. Otherwise
  zvex builds from source through Zigler + CMake automatically (requires
  the Zig toolchain, CMake, and a C/C++ compiler). Set `ZVEX_BUILD=1` to
  force a source build even when a precompiled artifact is available.

  Prefer using the higher-level `Zvex` module API over calling these
  functions directly.
  """

  @version Mix.Project.config()[:version]
  @use_precompiled Mix.Project.config()[:zvex_use_precompiled] == true

  use ZiglerPrecompiled,
    otp_app: :zvex,
    base_url: "https://github.com/edlontech/zvex/releases/download/zvex-v#{@version}",
    version: @version,
    force_build: not @use_precompiled,
    targets: ~w(x86_64-linux-gnu aarch64-linux-gnu aarch64-macos-none),
    zig_code_path: "native.zig",
    resources: [:CollectionResource],
    c: [
      include_dirs: [{:priv, "include"}],
      library_dirs: [{:priv, "lib"}],
      link_lib: [{:system, "zvec_c_api"}],
      link_libcpp: true
    ],
    nifs: [
      check_version: 3,
      collection_add_column: [:dirty_cpu, arity: 3],
      collection_alter_column: [:dirty_cpu, arity: 4],
      collection_close: [:dirty_cpu, arity: 1],
      collection_create_and_open: [:dirty_cpu, arity: 3],
      collection_create_index: [:dirty_cpu, arity: 3],
      collection_delete: [:dirty_cpu, arity: 2],
      collection_delete_by_filter: [:dirty_cpu, arity: 2],
      collection_delete_with_results: [:dirty_cpu, arity: 2],
      collection_drop_column: [:dirty_cpu, arity: 2],
      collection_drop_index: [:dirty_cpu, arity: 2],
      collection_fetch: [:dirty_cpu, arity: 2],
      collection_field_names: [:dirty_cpu, arity: 2],
      collection_flush: [:dirty_cpu, arity: 1],
      collection_get_options: [:dirty_cpu, arity: 1],
      collection_get_schema: 1,
      collection_get_stats: 1,
      collection_has_field: [:dirty_cpu, arity: 2],
      collection_has_index: [:dirty_cpu, arity: 2],
      collection_insert: [:dirty_cpu, arity: 2],
      collection_insert_with_results: [:dirty_cpu, arity: 2],
      collection_open: [:dirty_cpu, arity: 2],
      collection_optimize: [:dirty_cpu, arity: 1],
      collection_query: [:dirty_cpu, arity: 2],
      collection_update: [:dirty_cpu, arity: 2],
      collection_update_with_results: [:dirty_cpu, arity: 2],
      collection_upsert: [:dirty_cpu, arity: 2],
      collection_upsert_with_results: [:dirty_cpu, arity: 2],
      doc_deserialize: [:dirty_cpu, arity: 1],
      doc_detail_string: 1,
      doc_memory_usage: 1,
      doc_serialize: [:dirty_cpu, arity: 1],
      initialize: 0,
      initialize_with_config: 1,
      is_initialized: 0,
      shutdown: 0,
      version: 0,
      version_major: 0,
      version_minor: 0,
      version_patch: 0
    ]
end
