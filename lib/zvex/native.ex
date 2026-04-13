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
      collection_fetch: [:dirty_cpu]
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
  const zvec = @cImport({
      @cInclude("zvec/c_api.h");
  });

  fn error_code_to_atom(code: zvec.zvec_error_code_t) beam.term {
      return switch (code) {
          zvec.ZVEC_ERROR_INVALID_ARGUMENT => beam.make(.invalid_argument, .{}),
          zvec.ZVEC_ERROR_NOT_FOUND => beam.make(.not_found, .{}),
          zvec.ZVEC_ERROR_ALREADY_EXISTS => beam.make(.already_exists, .{}),
          zvec.ZVEC_ERROR_PERMISSION_DENIED => beam.make(.permission_denied, .{}),
          zvec.ZVEC_ERROR_FAILED_PRECONDITION => beam.make(.failed_precondition, .{}),
          zvec.ZVEC_ERROR_RESOURCE_EXHAUSTED => beam.make(.resource_exhausted, .{}),
          zvec.ZVEC_ERROR_UNAVAILABLE => beam.make(.unavailable, .{}),
          zvec.ZVEC_ERROR_NOT_SUPPORTED => beam.make(.not_supported, .{}),
          zvec.ZVEC_ERROR_INTERNAL_ERROR => beam.make(.internal_error, .{}),
          zvec.ZVEC_ERROR_UNKNOWN => beam.make(.unknown, .{}),
          else => beam.make(.unknown, .{}),
      };
  }

  fn make_error_result(code: zvec.zvec_error_code_t) beam.term {
      var msg_ptr: [*c]u8 = null;
      _ = zvec.zvec_get_last_error(&msg_ptr);

      const code_atom = error_code_to_atom(code);

      if (msg_ptr) |ptr| {
          const len = std.mem.len(@as([*:0]const u8, @ptrCast(ptr)));
          const msg_slice = @as([*]const u8, @ptrCast(ptr))[0..len];
          const result = beam.make(.{ .@"error", .{ code_atom, msg_slice } }, .{});
          zvec.zvec_free(@ptrCast(ptr));
          return result;
      }

      return beam.make(.{ .@"error", .{ code_atom, "" } }, .{});
  }

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

  const e = @import("erl_nif");
  const root = @import("root");

  fn get_map_value(map: beam.term, key: []const u8) ?beam.term {
      const key_atom = beam.make_into_atom(key, .{});
      var value: e.ErlNifTerm = undefined;
      if (e.enif_get_map_value(beam.context.env, map.v, key_atom.v, &value) == 1) {
          return beam.term{ .v = value };
      }
      return null;
  }

  fn get_int_from_term(comptime T: type, term_val: beam.term) ?T {
      return beam.get(T, term_val, .{}) catch null;
  }

  fn get_float_from_term(term_val: beam.term) ?f32 {
      const f = beam.get(f64, term_val, .{}) catch return null;
      return @floatCast(f);
  }

  fn atom_to_log_level(term_val: beam.term) ?c_uint {
      var buf: [256]u8 = undefined;
      const len = @as(usize, @intCast(e.enif_get_atom(beam.context.env, term_val.v, &buf, 256, e.ERL_NIF_LATIN1)));
      if (len == 0) return null;
      const name = buf[0 .. len - 1];

      if (std.mem.eql(u8, name, "debug")) return zvec.ZVEC_LOG_LEVEL_DEBUG;
      if (std.mem.eql(u8, name, "info")) return zvec.ZVEC_LOG_LEVEL_INFO;
      if (std.mem.eql(u8, name, "warn")) return zvec.ZVEC_LOG_LEVEL_WARN;
      if (std.mem.eql(u8, name, "error")) return zvec.ZVEC_LOG_LEVEL_ERROR;
      if (std.mem.eql(u8, name, "fatal")) return zvec.ZVEC_LOG_LEVEL_FATAL;
      return null;
  }

  fn atom_eql(term_val: beam.term, expected: []const u8) bool {
      var buf: [256]u8 = undefined;
      const len = @as(usize, @intCast(e.enif_get_atom(beam.context.env, term_val.v, &buf, 256, e.ERL_NIF_LATIN1)));
      if (len == 0) return false;
      return std.mem.eql(u8, buf[0 .. len - 1], expected);
  }

  fn get_binary_as_cstr(term_val: beam.term, out_buf: []u8) ?[*:0]const u8 {
      var bin: e.ErlNifBinary = undefined;
      if (e.enif_inspect_binary(beam.context.env, term_val.v, &bin) == 0) return null;
      if (bin.size >= out_buf.len) return null;
      const data_ptr: [*]const u8 = @ptrCast(bin.data);
      @memcpy(out_buf[0..bin.size], data_ptr[0..bin.size]);
      out_buf[bin.size] = 0;
      return @ptrCast(out_buf[0..bin.size :0]);
  }

  fn create_log_config(log_map: beam.term) ?*zvec.zvec_log_config_t {
      const type_term = get_map_value(log_map, "type") orelse return null;
      const level_term = get_map_value(log_map, "level");
      const level: c_uint = if (level_term) |lt| (atom_to_log_level(lt) orelse zvec.ZVEC_LOG_LEVEL_INFO) else zvec.ZVEC_LOG_LEVEL_INFO;

      if (atom_eql(type_term, "console")) {
          return zvec.zvec_config_log_create_console(level);
      }

      if (atom_eql(type_term, "file")) {
          var dir_buf: [4096]u8 = undefined;
          var base_buf: [256]u8 = undefined;

          const dir_term = get_map_value(log_map, "dir") orelse return null;
          const base_term = get_map_value(log_map, "basename") orelse return null;

          const dir_cstr = get_binary_as_cstr(dir_term, &dir_buf) orelse return null;
          const base_cstr = get_binary_as_cstr(base_term, &base_buf) orelse return null;

          const file_size: u32 = if (get_map_value(log_map, "file_size")) |fs| (get_int_from_term(u32, fs) orelse 100) else 100;
          const overdue_days: u32 = if (get_map_value(log_map, "overdue_days")) |od| (get_int_from_term(u32, od) orelse 7) else 7;

          return zvec.zvec_config_log_create_file(level, dir_cstr, base_cstr, file_size, overdue_days);
      }

      return null;
  }

  pub fn initialize_with_config(config_map: beam.term) beam.term {
      zvec.zvec_clear_error();

      const config_data = zvec.zvec_config_data_create();
      if (config_data == null) {
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate config" } }, .{});
      }

      if (get_map_value(config_map, "memory_limit")) |ml| {
          if (get_int_from_term(u64, ml)) |val| {
              const rc = zvec.zvec_config_data_set_memory_limit(config_data, val);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      if (get_map_value(config_map, "query_threads")) |qt| {
          if (get_int_from_term(u32, qt)) |val| {
              const rc = zvec.zvec_config_data_set_query_thread_count(config_data, val);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      if (get_map_value(config_map, "optimize_threads")) |ot| {
          if (get_int_from_term(u32, ot)) |val| {
              const rc = zvec.zvec_config_data_set_optimize_thread_count(config_data, val);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      if (get_map_value(config_map, "invert_to_forward_scan_ratio")) |ratio| {
          if (get_float_from_term(ratio)) |val| {
              const rc = zvec.zvec_config_data_set_invert_to_forward_scan_ratio(config_data, val);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      if (get_map_value(config_map, "brute_force_by_keys_ratio")) |ratio| {
          if (get_float_from_term(ratio)) |val| {
              const rc = zvec.zvec_config_data_set_brute_force_by_keys_ratio(config_data, val);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      if (get_map_value(config_map, "log")) |log_map| {
          const log_config = create_log_config(log_map);
          if (log_config == null) {
              zvec.zvec_config_data_destroy(config_data);
              return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "failed to create log configuration" } }, .{});
          }
          const rc = zvec.zvec_config_data_set_log_config(config_data, log_config);
          if (rc != zvec.ZVEC_OK) {
              zvec.zvec_config_log_destroy(log_config);
              zvec.zvec_config_data_destroy(config_data);
              return make_error_result(rc);
          }
      }

      const rc = zvec.zvec_initialize(config_data);
      zvec.zvec_config_data_destroy(config_data);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }
      return beam.make(.ok, .{});
  }

  // =========================================================================
  // Collection Resource
  // =========================================================================

  const CollectionData = struct {
      ptr: *zvec.zvec_collection_t,
      closed: bool,
  };

  const CollectionCallbacks = struct {
      pub fn dtor(data: *CollectionData) void {
          if (!data.closed) {
              _ = zvec.zvec_collection_close(data.ptr);
          }
      }
  };

  pub const CollectionResource = beam.Resource(CollectionData, root, .{ .Callbacks = CollectionCallbacks });

  // =========================================================================
  // Data type mappings
  // =========================================================================

  fn atom_to_data_type(term_val: beam.term) ?zvec.zvec_data_type_t {
      if (atom_eql(term_val, "string")) return zvec.ZVEC_DATA_TYPE_STRING;
      if (atom_eql(term_val, "int32")) return zvec.ZVEC_DATA_TYPE_INT32;
      if (atom_eql(term_val, "int64")) return zvec.ZVEC_DATA_TYPE_INT64;
      if (atom_eql(term_val, "uint32")) return zvec.ZVEC_DATA_TYPE_UINT32;
      if (atom_eql(term_val, "uint64")) return zvec.ZVEC_DATA_TYPE_UINT64;
      if (atom_eql(term_val, "float")) return zvec.ZVEC_DATA_TYPE_FLOAT;
      if (atom_eql(term_val, "double")) return zvec.ZVEC_DATA_TYPE_DOUBLE;
      if (atom_eql(term_val, "bool")) return zvec.ZVEC_DATA_TYPE_BOOL;
      if (atom_eql(term_val, "binary")) return zvec.ZVEC_DATA_TYPE_BINARY;
      if (atom_eql(term_val, "vector_fp32")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP32;
      if (atom_eql(term_val, "vector_fp16")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP16;
      if (atom_eql(term_val, "vector_fp64")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP64;
      if (atom_eql(term_val, "vector_int4")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT4;
      if (atom_eql(term_val, "vector_int8")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT8;
      if (atom_eql(term_val, "vector_int16")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT16;
      if (atom_eql(term_val, "vector_binary32")) return zvec.ZVEC_DATA_TYPE_VECTOR_BINARY32;
      if (atom_eql(term_val, "vector_binary64")) return zvec.ZVEC_DATA_TYPE_VECTOR_BINARY64;
      if (atom_eql(term_val, "sparse_vector_fp16")) return zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16;
      if (atom_eql(term_val, "sparse_vector_fp32")) return zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32;
      if (atom_eql(term_val, "array_string")) return zvec.ZVEC_DATA_TYPE_ARRAY_STRING;
      if (atom_eql(term_val, "array_int32")) return zvec.ZVEC_DATA_TYPE_ARRAY_INT32;
      if (atom_eql(term_val, "array_int64")) return zvec.ZVEC_DATA_TYPE_ARRAY_INT64;
      if (atom_eql(term_val, "array_uint32")) return zvec.ZVEC_DATA_TYPE_ARRAY_UINT32;
      if (atom_eql(term_val, "array_uint64")) return zvec.ZVEC_DATA_TYPE_ARRAY_UINT64;
      if (atom_eql(term_val, "array_float")) return zvec.ZVEC_DATA_TYPE_ARRAY_FLOAT;
      if (atom_eql(term_val, "array_double")) return zvec.ZVEC_DATA_TYPE_ARRAY_DOUBLE;
      if (atom_eql(term_val, "array_bool")) return zvec.ZVEC_DATA_TYPE_ARRAY_BOOL;
      if (atom_eql(term_val, "array_binary")) return zvec.ZVEC_DATA_TYPE_ARRAY_BINARY;
      return null;
  }

  fn data_type_to_atom(dt: zvec.zvec_data_type_t) beam.term {
      return switch (dt) {
          zvec.ZVEC_DATA_TYPE_STRING => beam.make(.string, .{}),
          zvec.ZVEC_DATA_TYPE_INT32 => beam.make(.int32, .{}),
          zvec.ZVEC_DATA_TYPE_INT64 => beam.make(.int64, .{}),
          zvec.ZVEC_DATA_TYPE_UINT32 => beam.make(.uint32, .{}),
          zvec.ZVEC_DATA_TYPE_UINT64 => beam.make(.uint64, .{}),
          zvec.ZVEC_DATA_TYPE_FLOAT => beam.make(.float, .{}),
          zvec.ZVEC_DATA_TYPE_DOUBLE => beam.make(.double, .{}),
          zvec.ZVEC_DATA_TYPE_BOOL => beam.make(.bool, .{}),
          zvec.ZVEC_DATA_TYPE_BINARY => beam.make(.binary, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_FP32 => beam.make(.vector_fp32, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_FP16 => beam.make(.vector_fp16, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_FP64 => beam.make(.vector_fp64, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_INT4 => beam.make(.vector_int4, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_INT8 => beam.make(.vector_int8, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_INT16 => beam.make(.vector_int16, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_BINARY32 => beam.make(.vector_binary32, .{}),
          zvec.ZVEC_DATA_TYPE_VECTOR_BINARY64 => beam.make(.vector_binary64, .{}),
          zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16 => beam.make(.sparse_vector_fp16, .{}),
          zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32 => beam.make(.sparse_vector_fp32, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_STRING => beam.make(.array_string, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_INT32 => beam.make(.array_int32, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_INT64 => beam.make(.array_int64, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_UINT32 => beam.make(.array_uint32, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_UINT64 => beam.make(.array_uint64, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_FLOAT => beam.make(.array_float, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_DOUBLE => beam.make(.array_double, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_BOOL => beam.make(.array_bool, .{}),
          zvec.ZVEC_DATA_TYPE_ARRAY_BINARY => beam.make(.array_binary, .{}),
          else => beam.make(.undefined, .{}),
      };
  }

  // =========================================================================
  // Index type / metric / quantize mappings
  // =========================================================================

  fn atom_to_index_type(term_val: beam.term) ?zvec.zvec_index_type_t {
      if (atom_eql(term_val, "hnsw")) return zvec.ZVEC_INDEX_TYPE_HNSW;
      if (atom_eql(term_val, "ivf")) return zvec.ZVEC_INDEX_TYPE_IVF;
      if (atom_eql(term_val, "flat")) return zvec.ZVEC_INDEX_TYPE_FLAT;
      if (atom_eql(term_val, "invert")) return zvec.ZVEC_INDEX_TYPE_INVERT;
      return null;
  }

  fn index_type_to_atom(it: zvec.zvec_index_type_t) beam.term {
      return switch (it) {
          zvec.ZVEC_INDEX_TYPE_HNSW => beam.make(.hnsw, .{}),
          zvec.ZVEC_INDEX_TYPE_IVF => beam.make(.ivf, .{}),
          zvec.ZVEC_INDEX_TYPE_FLAT => beam.make(.flat, .{}),
          zvec.ZVEC_INDEX_TYPE_INVERT => beam.make(.invert, .{}),
          else => beam.make(.undefined, .{}),
      };
  }

  fn atom_to_metric_type(term_val: beam.term) ?zvec.zvec_metric_type_t {
      if (atom_eql(term_val, "l2")) return zvec.ZVEC_METRIC_TYPE_L2;
      if (atom_eql(term_val, "ip")) return zvec.ZVEC_METRIC_TYPE_IP;
      if (atom_eql(term_val, "cosine")) return zvec.ZVEC_METRIC_TYPE_COSINE;
      if (atom_eql(term_val, "mipsl2")) return zvec.ZVEC_METRIC_TYPE_MIPSL2;
      return null;
  }

  fn metric_type_to_atom(mt: zvec.zvec_metric_type_t) beam.term {
      return switch (mt) {
          zvec.ZVEC_METRIC_TYPE_L2 => beam.make(.l2, .{}),
          zvec.ZVEC_METRIC_TYPE_IP => beam.make(.ip, .{}),
          zvec.ZVEC_METRIC_TYPE_COSINE => beam.make(.cosine, .{}),
          zvec.ZVEC_METRIC_TYPE_MIPSL2 => beam.make(.mipsl2, .{}),
          else => beam.make(.@"nil", .{}),
      };
  }

  fn atom_to_quantize_type(term_val: beam.term) ?zvec.zvec_quantize_type_t {
      if (atom_eql(term_val, "fp16")) return zvec.ZVEC_QUANTIZE_TYPE_FP16;
      if (atom_eql(term_val, "int8")) return zvec.ZVEC_QUANTIZE_TYPE_INT8;
      if (atom_eql(term_val, "int4")) return zvec.ZVEC_QUANTIZE_TYPE_INT4;
      return null;
  }

  fn quantize_type_to_atom(qt: zvec.zvec_quantize_type_t) beam.term {
      return switch (qt) {
          zvec.ZVEC_QUANTIZE_TYPE_FP16 => beam.make(.fp16, .{}),
          zvec.ZVEC_QUANTIZE_TYPE_INT8 => beam.make(.int8, .{}),
          zvec.ZVEC_QUANTIZE_TYPE_INT4 => beam.make(.int4, .{}),
          else => beam.make(.@"nil", .{}),
      };
  }

  // =========================================================================
  // Helper: create collection options from Elixir map
  // =========================================================================

  fn create_collection_options(opts_map: beam.term) ?*zvec.zvec_collection_options_t {
      const options = zvec.zvec_collection_options_create();
      if (options == null) return null;

      if (get_map_value(opts_map, "mmap")) |mmap_term| {
          const val = beam.get(bool, mmap_term, .{}) catch false;
          _ = zvec.zvec_collection_options_set_enable_mmap(options, val);
      }

      if (get_map_value(opts_map, "max_buffer_size")) |mbs_term| {
          if (get_int_from_term(u64, mbs_term)) |val| {
              _ = zvec.zvec_collection_options_set_max_buffer_size(options, val);
          }
      }

      if (get_map_value(opts_map, "read_only")) |ro_term| {
          const val = beam.get(bool, ro_term, .{}) catch false;
          _ = zvec.zvec_collection_options_set_read_only(options, val);
      }

      return options;
  }

  // =========================================================================
  // Helper: set index params on a field schema from Elixir index map
  // =========================================================================

  fn setup_index_params(field_schema: *zvec.zvec_field_schema_t, index_map: beam.term) beam.term {
      const type_term = get_map_value(index_map, "type") orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "index missing :type" } }, .{});

      const idx_type = atom_to_index_type(type_term) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "unknown index type" } }, .{});

      const params = zvec.zvec_index_params_create(idx_type);
      if (params == null)
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate index params" } }, .{});

      if (get_map_value(index_map, "metric")) |mt| {
          if (atom_to_metric_type(mt)) |metric| {
              _ = zvec.zvec_index_params_set_metric_type(params, metric);
          }
      }

      if (get_map_value(index_map, "quantize")) |qt| {
          if (atom_to_quantize_type(qt)) |quantize| {
              _ = zvec.zvec_index_params_set_quantize_type(params, quantize);
          }
      }

      if (idx_type == zvec.ZVEC_INDEX_TYPE_HNSW) {
          const m_term = get_map_value(index_map, "m");
          const ef_term = get_map_value(index_map, "ef_construction");
          const m: c_int = if (m_term) |t| (get_int_from_term(c_int, t) orelse 16) else 16;
          const ef: c_int = if (ef_term) |t| (get_int_from_term(c_int, t) orelse 200) else 200;
          _ = zvec.zvec_index_params_set_hnsw_params(params, m, ef);
      }

      if (idx_type == zvec.ZVEC_INDEX_TYPE_IVF) {
          const nl_term = get_map_value(index_map, "n_list");
          const ni_term = get_map_value(index_map, "n_iters");
          const soar_term = get_map_value(index_map, "use_soar");
          const n_list: c_int = if (nl_term) |t| (get_int_from_term(c_int, t) orelse 128) else 128;
          const n_iters: c_int = if (ni_term) |t| (get_int_from_term(c_int, t) orelse 10) else 10;
          const use_soar: bool = if (soar_term) |t| (beam.get(bool, t, .{}) catch false) else false;
          _ = zvec.zvec_index_params_set_ivf_params(params, n_list, n_iters, use_soar);
      }

      if (idx_type == zvec.ZVEC_INDEX_TYPE_INVERT) {
          const ro_term = get_map_value(index_map, "enable_range_opt");
          const wc_term = get_map_value(index_map, "enable_wildcard");
          const range_opt: bool = if (ro_term) |t| (beam.get(bool, t, .{}) catch false) else false;
          const wildcard: bool = if (wc_term) |t| (beam.get(bool, t, .{}) catch false) else false;
          _ = zvec.zvec_index_params_set_invert_params(params, range_opt, wildcard);
      }

      zvec.zvec_clear_error();
      const rc = zvec.zvec_field_schema_set_index_params(field_schema, params);
      zvec.zvec_index_params_destroy(params);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.ok, .{});
  }

  // =========================================================================
  // Helper: extract C string from beam term into stack buffer
  // =========================================================================

  fn c_str_from_term(term_val: beam.term, out_buf: []u8) ?[*:0]const u8 {
      var bin: e.ErlNifBinary = undefined;
      if (e.enif_inspect_binary(beam.context.env, term_val.v, &bin) == 0) {
          var atom_len: c_uint = undefined;
          const alen = e.enif_get_atom(beam.context.env, term_val.v, @ptrCast(out_buf.ptr), @intCast(out_buf.len), e.ERL_NIF_LATIN1);
          if (alen == 0) return null;
          atom_len = @intCast(alen);
          return @ptrCast(out_buf[0 .. atom_len - 1 :0]);
      }
      if (bin.size >= out_buf.len) return null;
      const data_ptr: [*]const u8 = @ptrCast(bin.data);
      @memcpy(out_buf[0..bin.size], data_ptr[0..bin.size]);
      out_buf[bin.size] = 0;
      return @ptrCast(out_buf[0..bin.size :0]);
  }

  // =========================================================================
  // collection_create_and_open/3 — yielding NIF
  // =========================================================================

  pub fn collection_create_and_open(path_term: beam.term, schema_map: beam.term, opts_map: beam.term) beam.term {
      var path_buf: [4096]u8 = undefined;
      const path_cstr = get_binary_as_cstr(path_term, &path_buf) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid path" } }, .{});

      const name_term = get_map_value(schema_map, "name") orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "schema missing :name" } }, .{});

      var name_buf: [1024]u8 = undefined;
      const name_cstr = get_binary_as_cstr(name_term, &name_buf) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid schema name" } }, .{});

      const c_schema = zvec.zvec_collection_schema_create(name_cstr);
      if (c_schema == null)
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection schema" } }, .{});

      if (get_map_value(schema_map, "max_doc_count_per_segment")) |mdc_term| {
          if (get_int_from_term(u64, mdc_term)) |val| {
              _ = zvec.zvec_collection_schema_set_max_doc_count_per_segment(c_schema, val);
          }
      }

      const fields_term = get_map_value(schema_map, "fields") orelse {
          zvec.zvec_collection_schema_destroy(c_schema);
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "schema missing :fields" } }, .{});
      };

      var list = fields_term.v;
      var head: e.ErlNifTerm = undefined;
      var tail: e.ErlNifTerm = undefined;

      while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
          const field_map = beam.term{ .v = head };

          const fname_term = get_map_value(field_map, "name") orelse {
              zvec.zvec_collection_schema_destroy(c_schema);
              return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "field missing :name" } }, .{});
          };
          var fname_buf: [1024]u8 = undefined;
          const fname_cstr = get_binary_as_cstr(fname_term, &fname_buf) orelse {
              zvec.zvec_collection_schema_destroy(c_schema);
              return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid field name" } }, .{});
          };

          const dtype_term = get_map_value(field_map, "data_type") orelse {
              zvec.zvec_collection_schema_destroy(c_schema);
              return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "field missing :data_type" } }, .{});
          };
          const data_type = atom_to_data_type(dtype_term) orelse {
              zvec.zvec_collection_schema_destroy(c_schema);
              return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "unknown data type" } }, .{});
          };

          const nullable_term = get_map_value(field_map, "nullable");
          const nullable: bool = if (nullable_term) |t| (beam.get(bool, t, .{}) catch false) else false;

          const dim_term = get_map_value(field_map, "dimension");
          const dimension: u32 = if (dim_term) |t| (get_int_from_term(u32, t) orelse 0) else 0;

          const field_schema = zvec.zvec_field_schema_create(fname_cstr, data_type, nullable, dimension);
          if (field_schema == null) {
              zvec.zvec_collection_schema_destroy(c_schema);
              return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate field schema" } }, .{});
          }

          if (get_map_value(field_map, "index")) |index_map| {
              if (!atom_eql(index_map, "nil")) {
                  const idx_result = setup_index_params(field_schema.?, index_map);
                  if (!atom_eql(idx_result, "ok")) {
                      zvec.zvec_field_schema_destroy(field_schema);
                      zvec.zvec_collection_schema_destroy(c_schema);
                      return idx_result;
                  }
              }
          }

          zvec.zvec_clear_error();
          const add_rc = zvec.zvec_collection_schema_add_field(c_schema, field_schema);
          zvec.zvec_field_schema_destroy(field_schema);

          if (add_rc != zvec.ZVEC_OK) {
              zvec.zvec_collection_schema_destroy(c_schema);
              return make_error_result(add_rc);
          }
      }

      const c_options = create_collection_options(opts_map);
      if (c_options == null) {
          zvec.zvec_collection_schema_destroy(c_schema);
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection options" } }, .{});
      }

      zvec.zvec_clear_error();
      var collection: ?*zvec.zvec_collection_t = null;
      const rc = zvec.zvec_collection_create_and_open(path_cstr, c_schema, c_options, &collection);

      zvec.zvec_collection_schema_destroy(c_schema);
      zvec.zvec_collection_options_destroy(c_options);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const resource = CollectionResource.create(.{
          .ptr = collection.?,
          .closed = false,
      }, .{}) catch
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection resource" } }, .{});

      const resource_term = resource.make(.{});
      return beam.make(.{ .ok, resource_term }, .{});
  }

  // =========================================================================
  // collection_open/2 — dirty CPU NIF
  // =========================================================================

  pub fn collection_open(path_term: beam.term, opts_map: beam.term) beam.term {
      var path_buf: [4096]u8 = undefined;
      const path_cstr = get_binary_as_cstr(path_term, &path_buf) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid path" } }, .{});

      const c_options = create_collection_options(opts_map);
      if (c_options == null) {
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection options" } }, .{});
      }

      zvec.zvec_clear_error();
      var collection: ?*zvec.zvec_collection_t = null;
      const rc = zvec.zvec_collection_open(path_cstr, c_options, &collection);

      zvec.zvec_collection_options_destroy(c_options);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const resource = CollectionResource.create(.{
          .ptr = collection.?,
          .closed = false,
      }, .{}) catch
          return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection resource" } }, .{});

      const resource_term = resource.make(.{});
      return beam.make(.{ .ok, resource_term }, .{});
  }

  // =========================================================================
  // collection_close/1 — normal NIF
  // =========================================================================

  pub fn collection_close(resource_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      var data = resource.unpack();
      _ = &data;

      if (data.closed) {
          return beam.make(.ok, .{});
      }

      zvec.zvec_clear_error();
      const rc = zvec.zvec_collection_close(data.ptr);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      resource.__payload.*.closed = true;
      return beam.make(.ok, .{});
  }

  // =========================================================================
  // collection_flush/1 — dirty CPU NIF
  // =========================================================================

  pub fn collection_flush(resource_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      zvec.zvec_clear_error();
      const rc = zvec.zvec_collection_flush(data.ptr);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.ok, .{});
  }

  // =========================================================================
  // collection_optimize/1 — yielding NIF
  // =========================================================================

  pub fn collection_optimize(resource_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      zvec.zvec_clear_error();
      const rc = zvec.zvec_collection_optimize(data.ptr);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.ok, .{});
  }

  // =========================================================================
  // collection_get_stats/1 — normal NIF
  // =========================================================================

  pub fn collection_get_stats(resource_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      zvec.zvec_clear_error();
      var stats: ?*zvec.zvec_collection_stats_t = null;
      const rc = zvec.zvec_collection_get_stats(data.ptr, &stats);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const stats_ptr = stats.?;
      const doc_count = zvec.zvec_collection_stats_get_doc_count(stats_ptr);
      const index_count = zvec.zvec_collection_stats_get_index_count(stats_ptr);

      var indexes_list = beam.make_empty_list(.{});

      var idx: usize = index_count;
      while (idx > 0) {
          idx -= 1;
          const idx_name_ptr = zvec.zvec_collection_stats_get_index_name(stats_ptr, idx);
          const completeness = zvec.zvec_collection_stats_get_index_completeness(stats_ptr, idx);

          var name_term: beam.term = undefined;
          if (idx_name_ptr) |np| {
              const name_len = std.mem.len(@as([*:0]const u8, @ptrCast(np)));
              name_term = beam.make(@as([*]const u8, @ptrCast(np))[0..name_len], .{});
          } else {
              name_term = beam.make("", .{});
          }

          const comp_f64: f64 = @floatCast(completeness);
          const index_entry = beam.make(.{
              .name = name_term,
              .completeness = comp_f64,
          }, .{});

          indexes_list = beam.make_list_cell(index_entry, indexes_list, .{});
      }

      zvec.zvec_collection_stats_destroy(stats_ptr);

      const result_map = beam.make(.{
          .doc_count = doc_count,
          .indexes = indexes_list,
      }, .{});

      return beam.make(.{ .ok, result_map }, .{});
  }

  // =========================================================================
  // collection_get_schema/1 — normal NIF
  // =========================================================================

  pub fn collection_get_schema(resource_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      zvec.zvec_clear_error();
      var c_schema: ?*zvec.zvec_collection_schema_t = null;
      const rc = zvec.zvec_collection_get_schema(data.ptr, &c_schema);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const schema_ptr = c_schema.?;

      const schema_name_ptr = zvec.zvec_collection_schema_get_name(schema_ptr);
      var schema_name_term: beam.term = undefined;
      if (schema_name_ptr) |snp| {
          const sn_len = std.mem.len(@as([*:0]const u8, @ptrCast(snp)));
          schema_name_term = beam.make(@as([*]const u8, @ptrCast(snp))[0..sn_len], .{});
      } else {
          schema_name_term = beam.make("", .{});
      }

      const max_doc_count = zvec.zvec_collection_schema_get_max_doc_count_per_segment(schema_ptr);

      var names: [*c][*c]const u8 = undefined;
      var field_count: usize = 0;
      const names_rc = zvec.zvec_collection_schema_get_all_field_names(schema_ptr, &names, &field_count);

      if (names_rc != zvec.ZVEC_OK) {
          zvec.zvec_collection_schema_destroy(schema_ptr);
          return make_error_result(names_rc);
      }

      var fields_list = beam.make_empty_list(.{});

      var fi: usize = field_count;
      while (fi > 0) {
          fi -= 1;

          const field_name_cstr = names[fi];
          const field_ptr = zvec.zvec_collection_schema_get_field(schema_ptr, field_name_cstr);

          if (field_ptr == null) continue;

          const fname_len = std.mem.len(@as([*:0]const u8, @ptrCast(field_name_cstr)));
          const fname_term = beam.make(@as([*]const u8, @ptrCast(field_name_cstr))[0..fname_len], .{});

          const dt = zvec.zvec_field_schema_get_data_type(field_ptr);
          const dt_atom = data_type_to_atom(dt);

          const is_nullable = zvec.zvec_field_schema_is_nullable(field_ptr);
          const dim = zvec.zvec_field_schema_get_dimension(field_ptr);
          const has_idx = zvec.zvec_field_schema_has_index(field_ptr);

          var field_entry: beam.term = undefined;

          if (has_idx) {
              const idx_type = zvec.zvec_field_schema_get_index_type(field_ptr);
              const idx_type_atom = index_type_to_atom(idx_type);

              const idx_params = zvec.zvec_field_schema_get_index_params(field_ptr);

              if (idx_params != null) {
                  const metric = zvec.zvec_index_params_get_metric_type(idx_params);
                  const metric_atom = metric_type_to_atom(metric);
                  const quantize = zvec.zvec_index_params_get_quantize_type(idx_params);
                  const quantize_atom = quantize_type_to_atom(quantize);

                  if (idx_type == zvec.ZVEC_INDEX_TYPE_HNSW) {
                      const m_val = zvec.zvec_index_params_get_hnsw_m(idx_params);
                      const ef_val = zvec.zvec_index_params_get_hnsw_ef_construction(idx_params);

                      const index_map = beam.make(.{
                          .type = idx_type_atom,
                          .metric = metric_atom,
                          .quantize = quantize_atom,
                          .m = @as(c_int, m_val),
                          .ef_construction = @as(c_int, ef_val),
                      }, .{});

                      field_entry = beam.make(.{
                          .name = fname_term,
                          .data_type = dt_atom,
                          .nullable = is_nullable,
                          .dimension = @as(u32, dim),
                          .index = index_map,
                      }, .{});
                  } else if (idx_type == zvec.ZVEC_INDEX_TYPE_IVF) {
                      var n_list: c_int = 0;
                      var n_iters: c_int = 0;
                      var use_soar: bool = false;
                      _ = zvec.zvec_index_params_get_ivf_params(idx_params, &n_list, &n_iters, &use_soar);

                      const index_map = beam.make(.{
                          .type = idx_type_atom,
                          .metric = metric_atom,
                          .quantize = quantize_atom,
                          .n_list = @as(c_int, n_list),
                          .n_iters = @as(c_int, n_iters),
                          .use_soar = use_soar,
                      }, .{});

                      field_entry = beam.make(.{
                          .name = fname_term,
                          .data_type = dt_atom,
                          .nullable = is_nullable,
                          .dimension = @as(u32, dim),
                          .index = index_map,
                      }, .{});
                  } else if (idx_type == zvec.ZVEC_INDEX_TYPE_INVERT) {
                      var range_opt: bool = false;
                      var wildcard: bool = false;
                      _ = zvec.zvec_index_params_get_invert_params(idx_params, &range_opt, &wildcard);

                      const index_map = beam.make(.{
                          .type = idx_type_atom,
                          .enable_range_opt = range_opt,
                          .enable_wildcard = wildcard,
                      }, .{});

                      field_entry = beam.make(.{
                          .name = fname_term,
                          .data_type = dt_atom,
                          .nullable = is_nullable,
                          .dimension = @as(u32, dim),
                          .index = index_map,
                      }, .{});
                  } else {
                      const index_map = beam.make(.{
                          .type = idx_type_atom,
                          .metric = metric_atom,
                          .quantize = quantize_atom,
                      }, .{});

                      field_entry = beam.make(.{
                          .name = fname_term,
                          .data_type = dt_atom,
                          .nullable = is_nullable,
                          .dimension = @as(u32, dim),
                          .index = index_map,
                      }, .{});
                  }
              } else {
                  const index_map = beam.make(.{
                      .type = idx_type_atom,
                  }, .{});

                  field_entry = beam.make(.{
                      .name = fname_term,
                      .data_type = dt_atom,
                      .nullable = is_nullable,
                      .dimension = @as(u32, dim),
                      .index = index_map,
                  }, .{});
              }
          } else {
              field_entry = beam.make(.{
                  .name = fname_term,
                  .data_type = dt_atom,
                  .nullable = is_nullable,
                  .dimension = @as(u32, dim),
              }, .{});
          }

          fields_list = beam.make_list_cell(field_entry, fields_list, .{});
      }

      zvec.zvec_free(@ptrCast(names));
      zvec.zvec_collection_schema_destroy(schema_ptr);

      var max_doc_term: beam.term = undefined;
      if (max_doc_count > 0) {
          max_doc_term = beam.make(max_doc_count, .{});
      } else {
          max_doc_term = beam.make(.@"nil", .{});
      }

      const result_map = beam.make(.{
          .name = schema_name_term,
          .fields = fields_list,
          .max_doc_count_per_segment = max_doc_term,
      }, .{});

      return beam.make(.{ .ok, result_map }, .{});
  }

  // =========================================================================
  // Document CRUD helpers
  // =========================================================================

  const MAX_DOCS = 10000;
  const MAX_PKS = 10000;
  const PK_BUF_SIZE = 4096;

  const PkArray = struct {
      ptrs: [*][*:0]const u8,
      buf: [*]u8,
      count: usize,
      buf_size: usize,

      fn deinit(self: *PkArray) void {
          std.heap.c_allocator.free(self.ptrs[0..self.count]);
          std.heap.c_allocator.free(self.buf[0..self.buf_size]);
      }
  };

  fn build_pk_array(pks_list: beam.term) ?PkArray {
      // First pass: count items and total size
      var count: usize = 0;
      var total_size: usize = 0;
      {
          var list = pks_list.v;
          var head: e.ErlNifTerm = undefined;
          var tail: e.ErlNifTerm = undefined;
          while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
              var bin: e.ErlNifBinary = undefined;
              if (e.enif_inspect_binary(beam.context.env, head, &bin) == 0) return null;
              if (count >= MAX_PKS) return null;
              total_size += bin.size + 1; // +1 for null terminator
              count += 1;
          }
      }
      if (count == 0) {
          // Allocate minimal arrays for zero-length case
          const ptrs = std.heap.c_allocator.alloc([*:0]const u8, 1) catch return null;
          const buf = std.heap.c_allocator.alloc(u8, 1) catch {
              std.heap.c_allocator.free(ptrs);
              return null;
          };
          return PkArray{ .ptrs = ptrs.ptr, .buf = buf.ptr, .count = 0, .buf_size = 1 };
      }

      // Allocate
      const ptrs = std.heap.c_allocator.alloc([*:0]const u8, count) catch return null;
      const buf = std.heap.c_allocator.alloc(u8, total_size) catch {
          std.heap.c_allocator.free(ptrs);
          return null;
      };

      // Second pass: copy strings
      var offset: usize = 0;
      var idx: usize = 0;
      {
          var list = pks_list.v;
          var head: e.ErlNifTerm = undefined;
          var tail: e.ErlNifTerm = undefined;
          while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
              var bin: e.ErlNifBinary = undefined;
              _ = e.enif_inspect_binary(beam.context.env, head, &bin);
              const data_ptr: [*]const u8 = @ptrCast(bin.data);
              @memcpy(buf[offset .. offset + bin.size], data_ptr[0..bin.size]);
              buf[offset + bin.size] = 0;
              ptrs[idx] = @ptrCast(buf[offset .. offset + bin.size :0]);
              offset += bin.size + 1;
              idx += 1;
          }
      }

      return PkArray{ .ptrs = ptrs.ptr, .buf = buf.ptr, .count = count, .buf_size = total_size };
  }

  fn set_doc_field(doc: *zvec.zvec_doc_t, name_cstr: [*:0]const u8, type_term: beam.term, value_term: beam.term) bool {
      if (atom_eql(type_term, "null")) {
          _ = zvec.zvec_doc_set_field_null(doc, name_cstr);
          return true;
      }

      const dt = atom_to_data_type(type_term) orelse return false;

      if (dt == zvec.ZVEC_DATA_TYPE_STRING) {
          var str_buf: [65536]u8 = undefined;
          const cstr = get_binary_as_cstr(value_term, &str_buf) orelse return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(cstr), std.mem.len(cstr));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_INT32) {
          const val = beam.get(i32, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(i32));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_INT64) {
          const val = beam.get(i64, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(i64));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_UINT32) {
          const val = beam.get(u32, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(u32));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_UINT64) {
          const val = beam.get(u64, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(u64));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_FLOAT) {
          const f = beam.get(f64, value_term, .{}) catch return false;
          const val: f32 = @floatCast(f);
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(f32));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_DOUBLE) {
          const val = beam.get(f64, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(f64));
          return true;
      }

      if (dt == zvec.ZVEC_DATA_TYPE_BOOL) {
          const val = beam.get(bool, value_term, .{}) catch return false;
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&val), @sizeOf(bool));
          return true;
      }

      var bin: e.ErlNifBinary = undefined;
      if (e.enif_inspect_binary(beam.context.env, value_term.v, &bin) == 1) {
          _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(bin.data), bin.size);
          return true;
      }

      return false;
  }

  fn build_doc_from_native_map(map_term: beam.term) ?*zvec.zvec_doc_t {
      const doc = zvec.zvec_doc_create() orelse return null;

      const pk_term = get_map_value(map_term, "pk") orelse {
          zvec.zvec_doc_destroy(doc);
          return null;
      };

      if (!atom_eql(pk_term, "nil")) {
          var pk_buf: [4096]u8 = undefined;
          const pk_cstr = get_binary_as_cstr(pk_term, &pk_buf) orelse {
              zvec.zvec_doc_destroy(doc);
              return null;
          };
          zvec.zvec_doc_set_pk(doc, pk_cstr);
      }

      const fields_term = get_map_value(map_term, "fields") orelse {
          zvec.zvec_doc_destroy(doc);
          return null;
      };

      var list = fields_term.v;
      var head: e.ErlNifTerm = undefined;
      var tail: e.ErlNifTerm = undefined;

      while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
          var arity: c_int = undefined;
          var tuple_ptr: [*c]const e.ErlNifTerm = undefined;
          if (e.enif_get_tuple(beam.context.env, head, &arity, &tuple_ptr) != 1 or arity != 3) {
              zvec.zvec_doc_destroy(doc);
              return null;
          }

          const name_term = beam.term{ .v = tuple_ptr[0] };
          const type_term = beam.term{ .v = tuple_ptr[1] };
          const value_term = beam.term{ .v = tuple_ptr[2] };

          if (atom_eql(type_term, "null")) {
              var fname_buf: [1024]u8 = undefined;
              const fname_cstr = get_binary_as_cstr(name_term, &fname_buf) orelse {
                  zvec.zvec_doc_destroy(doc);
                  return null;
              };
              _ = zvec.zvec_doc_set_field_null(doc, fname_cstr);
              continue;
          }

          var fname_buf: [1024]u8 = undefined;
          const fname_cstr = get_binary_as_cstr(name_term, &fname_buf) orelse {
              zvec.zvec_doc_destroy(doc);
              return null;
          };

          if (!set_doc_field(doc, fname_cstr, type_term, value_term)) {
              zvec.zvec_doc_destroy(doc);
              return null;
          }
      }

      return doc;
  }

  fn build_doc_array(docs_list: beam.term, doc_ptrs: [*]?*zvec.zvec_doc_t, max_count: usize) ?usize {
      var count: usize = 0;
      var list = docs_list.v;
      var head: e.ErlNifTerm = undefined;
      var tail: e.ErlNifTerm = undefined;

      while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
          if (count >= max_count) {
              free_built_docs(doc_ptrs, count);
              return null;
          }
          const doc = build_doc_from_native_map(beam.term{ .v = head }) orelse {
              free_built_docs(doc_ptrs, count);
              return null;
          };
          doc_ptrs[count] = doc;
          count += 1;
      }

      return count;
  }

  fn free_built_docs(doc_ptrs: [*]?*zvec.zvec_doc_t, count: usize) void {
      var i: usize = 0;
      while (i < count) : (i += 1) {
          if (doc_ptrs[i]) |d| {
              zvec.zvec_doc_destroy(d);
          }
      }
  }

  fn extract_typed_value(dt: zvec.zvec_data_type_t, ptr: *const anyopaque, size: usize) beam.term {
      return switch (dt) {
          zvec.ZVEC_DATA_TYPE_STRING => blk: {
              const cstr: [*:0]const u8 = @ptrCast(@alignCast(ptr));
              const len = std.mem.len(cstr);
              break :blk beam.make(@as([*]const u8, @ptrCast(cstr))[0..len], .{});
          },
          zvec.ZVEC_DATA_TYPE_INT32 => blk: {
              const val: *const i32 = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          zvec.ZVEC_DATA_TYPE_INT64 => blk: {
              const val: *const i64 = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          zvec.ZVEC_DATA_TYPE_UINT32 => blk: {
              const val: *const u32 = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          zvec.ZVEC_DATA_TYPE_UINT64 => blk: {
              const val: *const u64 = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          zvec.ZVEC_DATA_TYPE_FLOAT => blk: {
              const val: *const f32 = @ptrCast(@alignCast(ptr));
              const f64_val: f64 = @floatCast(val.*);
              break :blk beam.make(f64_val, .{});
          },
          zvec.ZVEC_DATA_TYPE_DOUBLE => blk: {
              const val: *const f64 = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          zvec.ZVEC_DATA_TYPE_BOOL => blk: {
              const val: *const bool = @ptrCast(@alignCast(ptr));
              break :blk beam.make(val.*, .{});
          },
          else => blk: {
              const byte_ptr: [*]const u8 = @ptrCast(ptr);
              break :blk beam.make(byte_ptr[0..size], .{});
          },
      };
  }

  const probe_types = [_]zvec.zvec_data_type_t{
      zvec.ZVEC_DATA_TYPE_STRING,
      zvec.ZVEC_DATA_TYPE_INT64,
      zvec.ZVEC_DATA_TYPE_DOUBLE,
      zvec.ZVEC_DATA_TYPE_BOOL,
      zvec.ZVEC_DATA_TYPE_FLOAT,
      zvec.ZVEC_DATA_TYPE_INT32,
      zvec.ZVEC_DATA_TYPE_UINT32,
      zvec.ZVEC_DATA_TYPE_UINT64,
      zvec.ZVEC_DATA_TYPE_BINARY,
      zvec.ZVEC_DATA_TYPE_VECTOR_FP32,
      zvec.ZVEC_DATA_TYPE_VECTOR_FP16,
      zvec.ZVEC_DATA_TYPE_VECTOR_FP64,
      zvec.ZVEC_DATA_TYPE_VECTOR_INT4,
      zvec.ZVEC_DATA_TYPE_VECTOR_INT8,
      zvec.ZVEC_DATA_TYPE_VECTOR_INT16,
      zvec.ZVEC_DATA_TYPE_VECTOR_BINARY32,
      zvec.ZVEC_DATA_TYPE_VECTOR_BINARY64,
      zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16,
      zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32,
  };

  fn extract_field_value(doc: *const zvec.zvec_doc_t, name_ptr: [*:0]const u8) beam.term {
      const name_len = std.mem.len(name_ptr);
      const name_term = beam.make(@as([*]const u8, @ptrCast(name_ptr))[0..name_len], .{});

      if (zvec.zvec_doc_is_field_null(doc, name_ptr)) {
          return beam.make(.{ name_term, beam.make(.null, .{}), beam.make(.@"nil", .{}) }, .{});
      }

      inline for (probe_types) |dt| {
          var val_ptr: ?*const anyopaque = null;
          var val_size: usize = 0;
          const rc = zvec.zvec_doc_get_field_value_pointer(doc, name_ptr, dt, &val_ptr, &val_size);
          if (rc == zvec.ZVEC_OK) {
              if (val_ptr) |vp| {
                  const type_atom = data_type_to_atom(dt);
                  const value = extract_typed_value(dt, vp, val_size);
                  return beam.make(.{ name_term, type_atom, value }, .{});
              }
          }
      }

      return beam.make(.{ name_term, beam.make(.unknown, .{}), beam.make(.@"nil", .{}) }, .{});
  }

  fn extract_doc_to_term(doc: *const zvec.zvec_doc_t) beam.term {
      var pk_term: beam.term = beam.make(.@"nil", .{});
      const pk_ptr = zvec.zvec_doc_get_pk_copy(doc);
      if (pk_ptr) |pkp| {
          const pk_len = std.mem.len(@as([*:0]const u8, @ptrCast(pkp)));
          pk_term = beam.make(@as([*]const u8, @ptrCast(pkp))[0..pk_len], .{});
          zvec.zvec_free(@constCast(@ptrCast(pkp)));
      }

      var field_names: [*c][*c]u8 = undefined;
      var field_count: usize = 0;
      const names_rc = zvec.zvec_doc_get_field_names(doc, @ptrCast(&field_names), &field_count);

      if (names_rc != zvec.ZVEC_OK) {
          return beam.make(.{
              .pk = pk_term,
              .fields = beam.make_empty_list(.{}),
          }, .{});
      }

      var fields_list = beam.make_empty_list(.{});
      var fi: usize = field_count;
      while (fi > 0) {
          fi -= 1;
          const fname: [*:0]const u8 = @ptrCast(field_names[fi]);
          const entry = extract_field_value(doc, fname);
          fields_list = beam.make_list_cell(entry, fields_list, .{});
      }

      zvec.zvec_free_str_array(@ptrCast(field_names), field_count);

      return beam.make(.{
          .pk = pk_term,
          .fields = fields_list,
      }, .{});
  }

  fn make_write_results_list(results: [*c]zvec.zvec_write_result_t, count: usize) beam.term {
      var list = beam.make_empty_list(.{});
      var idx: usize = count;
      while (idx > 0) {
          idx -= 1;
          const code_atom = if (results[idx].code == zvec.ZVEC_OK)
              beam.make(.ok, .{})
          else
              error_code_to_atom(results[idx].code);
          var msg_term: beam.term = undefined;
          if (results[idx].message) |msg| {
              const msg_len = std.mem.len(@as([*:0]const u8, @ptrCast(msg)));
              msg_term = beam.make(@as([*]const u8, @ptrCast(msg))[0..msg_len], .{});
          } else {
              msg_term = beam.make("", .{});
          }
          const entry = beam.make(.{
              .code = code_atom,
              .message = msg_term,
          }, .{});
          list = beam.make_list_cell(entry, list, .{});
      }
      return list;
  }

  // =========================================================================
  // collection_insert/2
  // =========================================================================

  pub fn collection_insert(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var success_count: usize = 0;
      var error_count: usize = 0;
      const rc = zvec.zvec_collection_insert(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
  }

  // =========================================================================
  // collection_insert_with_results/2
  // =========================================================================

  pub fn collection_insert_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var results: [*c]zvec.zvec_write_result_t = undefined;
      var result_count: usize = 0;
      const rc = zvec.zvec_collection_insert_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const results_list = make_write_results_list(results, result_count);
      zvec.zvec_write_results_free(@ptrCast(results), result_count);

      return beam.make(.{ .ok, results_list }, .{});
  }

  // =========================================================================
  // collection_update/2
  // =========================================================================

  pub fn collection_update(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var success_count: usize = 0;
      var error_count: usize = 0;
      const rc = zvec.zvec_collection_update(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
  }

  // =========================================================================
  // collection_update_with_results/2
  // =========================================================================

  pub fn collection_update_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var results: [*c]zvec.zvec_write_result_t = undefined;
      var result_count: usize = 0;
      const rc = zvec.zvec_collection_update_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const results_list = make_write_results_list(results, result_count);
      zvec.zvec_write_results_free(@ptrCast(results), result_count);

      return beam.make(.{ .ok, results_list }, .{});
  }

  // =========================================================================
  // collection_upsert/2
  // =========================================================================

  pub fn collection_upsert(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var success_count: usize = 0;
      var error_count: usize = 0;
      const rc = zvec.zvec_collection_upsert(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
  }

  // =========================================================================
  // collection_upsert_with_results/2
  // =========================================================================

  pub fn collection_upsert_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var doc_ptrs_buf: [MAX_DOCS]?*zvec.zvec_doc_t = undefined;
      const doc_count = build_doc_array(docs_list, &doc_ptrs_buf, MAX_DOCS) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

      zvec.zvec_clear_error();
      var results: [*c]zvec.zvec_write_result_t = undefined;
      var result_count: usize = 0;
      const rc = zvec.zvec_collection_upsert_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

      free_built_docs(&doc_ptrs_buf, doc_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const results_list = make_write_results_list(results, result_count);
      zvec.zvec_write_results_free(@ptrCast(results), result_count);

      return beam.make(.{ .ok, results_list }, .{});
  }

  // =========================================================================
  // collection_delete/2
  // =========================================================================

  pub fn collection_delete(resource_term: beam.term, pks_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var pks = build_pk_array(pks_list) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
      defer pks.deinit();

      zvec.zvec_clear_error();
      var success_count: usize = 0;
      var error_count: usize = 0;
      const rc = zvec.zvec_collection_delete(data.ptr, @ptrCast(pks.ptrs), pks.count, &success_count, &error_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
  }

  // =========================================================================
  // collection_delete_with_results/2
  // =========================================================================

  pub fn collection_delete_with_results(resource_term: beam.term, pks_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var pks = build_pk_array(pks_list) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
      defer pks.deinit();

      zvec.zvec_clear_error();
      var results: [*c]zvec.zvec_write_result_t = undefined;
      var result_count: usize = 0;
      const rc = zvec.zvec_collection_delete_with_results(data.ptr, @ptrCast(pks.ptrs), pks.count, @ptrCast(&results), &result_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      const results_list = make_write_results_list(results, result_count);
      zvec.zvec_write_results_free(@ptrCast(results), result_count);

      return beam.make(.{ .ok, results_list }, .{});
  }

  // =========================================================================
  // collection_delete_by_filter/2
  // =========================================================================

  pub fn collection_delete_by_filter(resource_term: beam.term, filter_term: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var filter_buf: [65536]u8 = undefined;
      const filter_cstr = get_binary_as_cstr(filter_term, &filter_buf) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid filter expression" } }, .{});

      zvec.zvec_clear_error();
      const rc = zvec.zvec_collection_delete_by_filter(data.ptr, filter_cstr);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      return beam.make(.ok, .{});
  }

  // =========================================================================
  // collection_fetch/2
  // =========================================================================

  pub fn collection_fetch(resource_term: beam.term, pks_list: beam.term) beam.term {
      var resource: CollectionResource = undefined;
      resource.get(resource_term, .{ .released = false }) catch
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

      const data = resource.unpack();

      if (data.closed) {
          return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
      }

      var pks = build_pk_array(pks_list) orelse
          return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
      defer pks.deinit();

      zvec.zvec_clear_error();
      var result_docs: [*c]?*zvec.zvec_doc_t = undefined;
      var found_count: usize = 0;
      const rc = zvec.zvec_collection_fetch(data.ptr, @ptrCast(pks.ptrs), pks.count, @ptrCast(&result_docs), &found_count);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }

      var docs_result_list = beam.make_empty_list(.{});
      var di: usize = found_count;
      while (di > 0) {
          di -= 1;
          if (result_docs[di]) |doc_ptr| {
              const doc_term = extract_doc_to_term(doc_ptr);
              docs_result_list = beam.make_list_cell(doc_term, docs_result_list, .{});
          }
      }

      zvec.zvec_docs_free(@ptrCast(result_docs), found_count);

      return beam.make(.{ .ok, docs_result_list }, .{});
  }
  """
end
