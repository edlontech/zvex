defmodule Zvex.Native do
  @moduledoc """
  Low-level NIF bindings to the zvec C API via Zigler.

  This module provides direct access to zvec's version information,
  initialization, and shutdown functions. Prefer using the higher-level
  `Zvex` module API instead of calling these directly.
  """

  use Zig,
    otp_app: :zvex,
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

          const file_size: u32 = if (get_map_value(log_map, "file_size")) |fs| (get_int_from_term(u32, fs) orelse 10) else 10;
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
          if (create_log_config(log_map)) |log_config| {
              const rc = zvec.zvec_config_data_set_log_config(config_data, log_config);
              if (rc != zvec.ZVEC_OK) {
                  zvec.zvec_config_data_destroy(config_data);
                  return make_error_result(rc);
              }
          }
      }

      const rc = zvec.zvec_initialize(config_data);
      zvec.zvec_config_data_destroy(config_data);

      if (rc != zvec.ZVEC_OK) {
          return make_error_result(rc);
      }
      return beam.make(.ok, .{});
  }
  """
end
