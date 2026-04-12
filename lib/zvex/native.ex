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
  """
end
