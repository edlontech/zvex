defmodule Zvex.Native do
  @moduledoc """
  Low-level NIF bindings to the zvec C API via Zigler.

  This module provides direct access to zvec's version information,
  initialization, and shutdown functions. Prefer using the higher-level
  `Zvex` module API instead of calling these directly.
  """

  use Zig,
    otp_app: :zvex,
    resources: [:CollectionResource],
    nifs: [
      ...,
      collection_create_and_open: [:dirty_cpu],
      collection_open: [:dirty_cpu],
      collection_flush: [:dirty_cpu],
      collection_optimize: [:dirty_cpu],
      collection_insert: [:dirty_cpu],
      collection_insert_with_results: [:dirty_cpu],
      collection_update: [:dirty_cpu],
      collection_update_with_results: [:dirty_cpu],
      collection_upsert: [:dirty_cpu],
      collection_upsert_with_results: [:dirty_cpu],
      collection_delete: [:dirty_cpu],
      collection_delete_with_results: [:dirty_cpu],
      collection_delete_by_filter: [:dirty_cpu],
      collection_fetch: [:dirty_cpu],
      collection_create_index: [:dirty_cpu],
      collection_drop_index: [:dirty_cpu],
      collection_add_column: [:dirty_cpu],
      collection_drop_column: [:dirty_cpu],
      collection_alter_column: [:dirty_cpu],
      collection_get_options: [:dirty_cpu],
      collection_has_field: [:dirty_cpu],
      collection_has_index: [:dirty_cpu],
      collection_field_names: [:dirty_cpu],
      collection_query: [:dirty_cpu],
      doc_serialize: [:dirty_cpu],
      doc_deserialize: [:dirty_cpu]
    ],
    c: [
      include_dirs: [{:priv, "include"}],
      library_dirs: [{:priv, "lib"}],
      link_lib: [{:system, "zvec_c_api"}],
      link_libcpp: true
    ]

  ~Z"""
  const std = @import("std");
  const beam = @import("beam");

  const common = @import("zig/common.zig");
  const zvec = common.zvec;
  const config = @import("zig/config.zig");
  const schema = @import("zig/schema.zig");
  const coll = @import("zig/collection.zig");
  const query_mod = @import("zig/query.zig");
  const document = @import("zig/document.zig");
  const resource = @import("zig/resource.zig");

  const make_error_result = common.make_error_result;

  pub const CollectionResource = resource.CollectionResource;

  pub fn version() beam.term {
      const ver = zvec.zvec_get_version();
      if (ver) |v| {
          const len = std.mem.len(@as([*:0]const u8, @ptrCast(v)));
          return beam.make(@as([*]const u8, @ptrCast(v))[0..len], .{});
      }
      return beam.make("", .{});
  }

  pub fn version_major() c_int {
      return zvec.zvec_get_version_major();
  }

  pub fn version_minor() c_int {
      return zvec.zvec_get_version_minor();
  }

  pub fn version_patch() c_int {
      return zvec.zvec_get_version_patch();
  }

  pub fn check_version(major: c_int, minor: c_int, patch: c_int) bool {
      return zvec.zvec_check_version(major, minor, patch);
  }

  pub fn initialize() beam.term {
      zvec.zvec_clear_error();
      const rc = zvec.zvec_initialize(null);
      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }
      return beam.make(.ok, .{});
  }

  pub fn shutdown() beam.term {
      zvec.zvec_clear_error();
      const rc = zvec.zvec_shutdown();
      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }
      return beam.make(.ok, .{});
  }

  pub fn is_initialized() bool {
      return zvec.zvec_is_initialized();
  }

  pub const initialize_with_config = config.initialize_with_config;
  pub const collection_create_and_open = schema.collection_create_and_open;
  pub const collection_open = schema.collection_open;
  pub const collection_get_schema = schema.collection_get_schema;
  pub const collection_close = coll.collection_close;
  pub const collection_flush = coll.collection_flush;
  pub const collection_optimize = coll.collection_optimize;
  pub const collection_get_stats = coll.collection_get_stats;
  pub const collection_insert = coll.collection_insert;
  pub const collection_insert_with_results = coll.collection_insert_with_results;
  pub const collection_update = coll.collection_update;
  pub const collection_update_with_results = coll.collection_update_with_results;
  pub const collection_upsert = coll.collection_upsert;
  pub const collection_upsert_with_results = coll.collection_upsert_with_results;
  pub const collection_delete = coll.collection_delete;
  pub const collection_delete_with_results = coll.collection_delete_with_results;
  pub const collection_delete_by_filter = coll.collection_delete_by_filter;
  pub const collection_fetch = coll.collection_fetch;
  pub const collection_create_index = coll.collection_create_index;
  pub const collection_drop_index = coll.collection_drop_index;
  pub const collection_add_column = coll.collection_add_column;
  pub const collection_drop_column = coll.collection_drop_column;
  pub const collection_alter_column = coll.collection_alter_column;
  pub const collection_get_options = coll.collection_get_options;
  pub const collection_has_field = coll.collection_has_field;
  pub const collection_has_index = coll.collection_has_index;
  pub const collection_field_names = coll.collection_field_names;
  pub const collection_query = query_mod.collection_query;
  pub const doc_serialize = document.doc_serialize;
  pub const doc_deserialize = document.doc_deserialize;
  pub const doc_memory_usage = document.doc_memory_usage;
  pub const doc_detail_string = document.doc_detail_string;
  """
end
