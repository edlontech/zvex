const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");
pub const zvec = @cImport({
    @cInclude("zvec/c_api.h");
});

pub fn error_code_to_atom(code: zvec.zvec_error_code_t) beam.term {
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

pub fn make_error_result(code: zvec.zvec_error_code_t) beam.term {
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

pub fn get_map_value(map: beam.term, key: []const u8) ?beam.term {
    const key_atom = beam.make_into_atom(key, .{});
    var value: e.ErlNifTerm = undefined;
    if (e.enif_get_map_value(beam.context.env, map.v, key_atom.v, &value) == 1) {
        return beam.term{ .v = value };
    }
    return null;
}

pub fn get_int_from_term(comptime T: type, term_val: beam.term) ?T {
    return beam.get(T, term_val, .{}) catch null;
}

pub fn get_float_from_term(term_val: beam.term) ?f32 {
    const f = beam.get(f64, term_val, .{}) catch return null;
    return @floatCast(f);
}

pub fn atom_eql(term_val: beam.term, expected: []const u8) bool {
    var buf: [256]u8 = undefined;
    const len = @as(usize, @intCast(e.enif_get_atom(beam.context.env, term_val.v, &buf, 256, e.ERL_NIF_LATIN1)));
    if (len == 0) return false;
    return std.mem.eql(u8, buf[0 .. len - 1], expected);
}

pub fn get_binary_as_cstr(term_val: beam.term, out_buf: []u8) ?[*:0]const u8 {
    var bin: e.ErlNifBinary = undefined;
    if (e.enif_inspect_binary(beam.context.env, term_val.v, &bin) == 0) return null;
    if (bin.size >= out_buf.len) return null;
    const data_ptr: [*]const u8 = @ptrCast(bin.data);
    @memcpy(out_buf[0..bin.size], data_ptr[0..bin.size]);
    out_buf[bin.size] = 0;
    return @ptrCast(out_buf[0..bin.size :0]);
}

