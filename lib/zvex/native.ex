defmodule Zvex.Native do
  @moduledoc """
  Low-level NIF bindings to the zvec C API.

  At compile time the host target triple drives a single decision:

    * Supported target and `ZVEX_BUILD` unset — download the
      `zvex-v<version>` GitHub release tarball (NIF + `libzvec_c_api`),
      verify via SHA-256, and unpack into `priv/lib`. No Makefile, no
      Zig toolchain required.
    * Unsupported target, or `ZVEX_BUILD=1` — build everything from
      source via `elixir_make` (Makefile builds `libzvec_c_api`) plus
      Zigler (compiles the NIF). Requires the Zig toolchain, CMake,
      and a C/C++ compiler.

  Download failures on a supported target raise — they do not silently
  fall back to source. Set `ZVEX_BUILD=1` to take the source path.

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
    targets: ~w(x86_64-linux-gnu aarch64-linux-gnu aarch64-macos-none x86_64-windows-gnu),
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
