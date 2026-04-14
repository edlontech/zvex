const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");
const common = @import("common.zig");
const zvec = common.zvec;
const types = @import("types.zig");

pub const MAX_DOCS = 10000;
pub const MAX_PKS = 10000;
pub const PK_BUF_SIZE = 4096;

pub const PkArray = struct {
    ptrs: [*][*:0]const u8,
    buf: [*]u8,
    count: usize,
    buf_size: usize,

    pub fn deinit(self: *PkArray) void {
        std.heap.c_allocator.free(self.ptrs[0..self.count]);
        std.heap.c_allocator.free(self.buf[0..self.buf_size]);
    }
};

pub fn build_pk_array(pks_list: beam.term) ?PkArray {
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
            total_size += bin.size + 1;
            count += 1;
        }
    }
    if (count == 0) {
        const ptrs = std.heap.c_allocator.alloc([*:0]const u8, 1) catch return null;
        const buf = std.heap.c_allocator.alloc(u8, 1) catch {
            std.heap.c_allocator.free(ptrs);
            return null;
        };
        return PkArray{ .ptrs = ptrs.ptr, .buf = buf.ptr, .count = 0, .buf_size = 1 };
    }

    const ptrs = std.heap.c_allocator.alloc([*:0]const u8, count) catch return null;
    const buf = std.heap.c_allocator.alloc(u8, total_size) catch {
        std.heap.c_allocator.free(ptrs);
        return null;
    };

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
    if (common.atom_eql(type_term, "null")) {
        _ = zvec.zvec_doc_set_field_null(doc, name_cstr);
        return true;
    }

    const dt = types.atom_to_data_type(type_term) orelse return false;

    if (dt == zvec.ZVEC_DATA_TYPE_STRING) {
        var str_buf: [65536]u8 = undefined;
        const cstr = common.get_binary_as_cstr(value_term, &str_buf) orelse return false;
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
    if (e.enif_inspect_binary(beam.context.env, value_term.v, &bin) != 1) {
        return false;
    }

    if (dt == zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32 or
        dt == zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16)
    {
        if (bin.size < 8) return false;
        const data: [*]const u8 = @ptrCast(bin.data);
        if (data[4] != 0 or data[5] != 0 or data[6] != 0 or data[7] != 0) return false;
        var c_buf: [65536]u8 = undefined;
        const payload_size = bin.size - 4;
        if (payload_size > c_buf.len) return false;
        @memcpy(c_buf[0..4], data[0..4]);
        @memcpy(c_buf[4..payload_size], data[8..bin.size]);
        _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(&c_buf), payload_size);
        return true;
    }

    _ = zvec.zvec_doc_add_field_by_value(doc, name_cstr, dt, @ptrCast(bin.data), bin.size);
    return true;
}

fn build_doc_from_native_map(map_term: beam.term) ?*zvec.zvec_doc_t {
    const doc = zvec.zvec_doc_create() orelse return null;

    const pk_term = common.get_map_value(map_term, "pk") orelse {
        zvec.zvec_doc_destroy(doc);
        return null;
    };

    if (!common.atom_eql(pk_term, "nil")) {
        var pk_buf: [4096]u8 = undefined;
        const pk_cstr = common.get_binary_as_cstr(pk_term, &pk_buf) orelse {
            zvec.zvec_doc_destroy(doc);
            return null;
        };
        zvec.zvec_doc_set_pk(doc, pk_cstr);
    }

    const fields_term = common.get_map_value(map_term, "fields") orelse {
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

        if (common.atom_eql(type_term, "null")) {
            var fname_buf: [1024]u8 = undefined;
            const fname_cstr = common.get_binary_as_cstr(name_term, &fname_buf) orelse {
                zvec.zvec_doc_destroy(doc);
                return null;
            };
            _ = zvec.zvec_doc_set_field_null(doc, fname_cstr);
            continue;
        }

        var fname_buf: [1024]u8 = undefined;
        const fname_cstr = common.get_binary_as_cstr(name_term, &fname_buf) orelse {
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

pub fn build_doc_array(docs_list: beam.term, doc_ptrs: [*]?*zvec.zvec_doc_t, max_count: usize) ?usize {
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

pub fn free_built_docs(doc_ptrs: [*]?*zvec.zvec_doc_t, count: usize) void {
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
                const type_atom = types.data_type_to_atom(dt);
                const value = extract_typed_value(dt, vp, val_size);
                return beam.make(.{ name_term, type_atom, value }, .{});
            }
        }
    }

    inline for (.{
        zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32,
        zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16,
    }) |dt| {
        var val_ptr: ?*anyopaque = null;
        var val_size: usize = 0;
        const rc = zvec.zvec_doc_get_field_value_copy(doc, name_ptr, dt, &val_ptr, &val_size);
        if (rc == zvec.ZVEC_OK) {
            if (val_ptr) |vp| {
                const type_atom = types.data_type_to_atom(dt);
                const value = beam.make(@as([*]const u8, @ptrCast(vp))[0..val_size], .{});
                zvec.zvec_free(vp);
                return beam.make(.{ name_term, type_atom, value }, .{});
            }
        }
    }

    return beam.make(.{ name_term, beam.make(.unknown, .{}), beam.make(.@"nil", .{}) }, .{});
}

pub fn extract_doc_to_term(doc: *const zvec.zvec_doc_t) beam.term {
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

pub fn extract_query_result_to_term(doc: *const zvec.zvec_doc_t) beam.term {
    var pk_term: beam.term = beam.make(.@"nil", .{});
    const pk_ptr = zvec.zvec_doc_get_pk_copy(doc);
    if (pk_ptr) |pkp| {
        const pk_len = std.mem.len(@as([*:0]const u8, @ptrCast(pkp)));
        pk_term = beam.make(@as([*]const u8, @ptrCast(pkp))[0..pk_len], .{});
        zvec.zvec_free(@constCast(@ptrCast(pkp)));
    }

    const score: f64 = @floatCast(zvec.zvec_doc_get_score(doc));
    const doc_id: u64 = zvec.zvec_doc_get_doc_id(doc);

    var field_names: [*c][*c]u8 = undefined;
    var field_count: usize = 0;
    const names_rc = zvec.zvec_doc_get_field_names(doc, @ptrCast(&field_names), &field_count);

    if (names_rc != zvec.ZVEC_OK) {
        return beam.make(.{
            .pk = pk_term,
            .score = score,
            .doc_id = doc_id,
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
        .score = score,
        .doc_id = doc_id,
        .fields = fields_list,
    }, .{});
}

pub fn make_write_results_list(results: [*c]zvec.zvec_write_result_t, count: usize) beam.term {
    var list = beam.make_empty_list(.{});
    var idx: usize = count;
    while (idx > 0) {
        idx -= 1;
        const code_atom = if (results[idx].code == zvec.ZVEC_OK)
            beam.make(.ok, .{})
        else
            common.error_code_to_atom(results[idx].code);
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

pub fn doc_serialize(native_map: beam.term) beam.term {
    const doc = build_doc_from_native_map(native_map) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document" } }, .{});
    defer zvec.zvec_doc_destroy(doc);

    zvec.zvec_clear_error();
    var data: [*c]u8 = null;
    var size: usize = 0;
    const rc = zvec.zvec_doc_serialize(doc, @ptrCast(&data), &size);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    if (data == null or size == 0) {
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "serialize returned empty data" } }, .{});
    }

    const result = beam.make(@as([*]const u8, @ptrCast(data))[0..size], .{});
    zvec.zvec_free_uint8_array(data);

    return beam.make(.{ .ok, result }, .{});
}

pub fn doc_deserialize(binary: beam.term) beam.term {
    var bin: e.ErlNifBinary = undefined;
    if (e.enif_inspect_binary(beam.context.env, binary.v, &bin) == 0) {
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "expected binary" } }, .{});
    }

    const min_doc_size: usize = 24;
    if (bin.size < min_doc_size) {
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "binary too small to be a valid document" } }, .{});
    }

    const pk_len = std.mem.readInt(u32, bin.data[0..4], .little);
    if (pk_len > bin.size - min_doc_size) {
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid document binary" } }, .{});
    }

    zvec.zvec_clear_error();
    var doc: ?*zvec.zvec_doc_t = null;
    const rc = zvec.zvec_doc_deserialize(@ptrCast(bin.data), bin.size, @ptrCast(&doc));

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    if (doc == null) {
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "deserialize returned null doc" } }, .{});
    }

    defer zvec.zvec_doc_destroy(doc.?);
    const result = extract_doc_to_term(doc.?);

    return beam.make(.{ .ok, result }, .{});
}

pub fn doc_memory_usage(native_map: beam.term) beam.term {
    const doc = build_doc_from_native_map(native_map) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document" } }, .{});
    defer zvec.zvec_doc_destroy(doc);

    const usage = zvec.zvec_doc_memory_usage(doc);
    return beam.make(.{ .ok, usage }, .{});
}

pub fn doc_detail_string(native_map: beam.term) beam.term {
    const doc = build_doc_from_native_map(native_map) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document" } }, .{});
    defer zvec.zvec_doc_destroy(doc);

    zvec.zvec_clear_error();
    var str_ptr: [*c]u8 = null;
    const rc = zvec.zvec_doc_to_detail_string(doc, @ptrCast(&str_ptr));

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    if (str_ptr == null) {
        return beam.make(.{ .ok, "" }, .{});
    }

    const len = std.mem.len(@as([*:0]const u8, @ptrCast(str_ptr)));
    const result = beam.make(@as([*]const u8, @ptrCast(str_ptr))[0..len], .{});
    zvec.zvec_free(@constCast(@ptrCast(str_ptr)));

    return beam.make(.{ .ok, result }, .{});
}
