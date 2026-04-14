const std = @import("std");
const beam = @import("beam");
const common = @import("common.zig");
const zvec = common.zvec;
const document = @import("document.zig");
const resource = @import("resource.zig");
const schema = @import("schema.zig");

pub fn collection_close(resource_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    var data = res.unpack();
    _ = &data;

    if (data.closed) {
        return beam.make(.ok, .{});
    }

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_close(data.ptr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    res.__payload.*.closed = true;
    return beam.make(.ok, .{});
}

pub fn collection_flush(resource_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_flush(data.ptr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_optimize(resource_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_optimize(data.ptr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_get_stats(resource_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    zvec.zvec_clear_error();
    var stats: ?*zvec.zvec_collection_stats_t = null;
    const rc = zvec.zvec_collection_get_stats(data.ptr, &stats);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
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

pub fn collection_insert(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var success_count: usize = 0;
    var error_count: usize = 0;
    const rc = zvec.zvec_collection_insert(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
}

pub fn collection_insert_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var results: [*c]zvec.zvec_write_result_t = undefined;
    var result_count: usize = 0;
    const rc = zvec.zvec_collection_insert_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    const results_list = document.make_write_results_list(results, result_count);
    zvec.zvec_write_results_free(@ptrCast(results), result_count);

    return beam.make(.{ .ok, results_list }, .{});
}

pub fn collection_update(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var success_count: usize = 0;
    var error_count: usize = 0;
    const rc = zvec.zvec_collection_update(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
}

pub fn collection_update_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var results: [*c]zvec.zvec_write_result_t = undefined;
    var result_count: usize = 0;
    const rc = zvec.zvec_collection_update_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    const results_list = document.make_write_results_list(results, result_count);
    zvec.zvec_write_results_free(@ptrCast(results), result_count);

    return beam.make(.{ .ok, results_list }, .{});
}

pub fn collection_upsert(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var success_count: usize = 0;
    var error_count: usize = 0;
    const rc = zvec.zvec_collection_upsert(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, &success_count, &error_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
}

pub fn collection_upsert_with_results(resource_term: beam.term, docs_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var doc_ptrs_buf: [document.MAX_DOCS]?*zvec.zvec_doc_t = undefined;
    const doc_count = document.build_doc_array(docs_list, &doc_ptrs_buf, document.MAX_DOCS) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build document array" } }, .{});

    zvec.zvec_clear_error();
    var results: [*c]zvec.zvec_write_result_t = undefined;
    var result_count: usize = 0;
    const rc = zvec.zvec_collection_upsert_with_results(data.ptr, @ptrCast(&doc_ptrs_buf), doc_count, @ptrCast(&results), &result_count);

    document.free_built_docs(&doc_ptrs_buf, doc_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    const results_list = document.make_write_results_list(results, result_count);
    zvec.zvec_write_results_free(@ptrCast(results), result_count);

    return beam.make(.{ .ok, results_list }, .{});
}

pub fn collection_delete(resource_term: beam.term, pks_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var pks = document.build_pk_array(pks_list) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
    defer pks.deinit();

    zvec.zvec_clear_error();
    var success_count: usize = 0;
    var error_count: usize = 0;
    const rc = zvec.zvec_collection_delete(data.ptr, @ptrCast(pks.ptrs), pks.count, &success_count, &error_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.{ .ok, .{ success_count, error_count } }, .{});
}

pub fn collection_delete_with_results(resource_term: beam.term, pks_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var pks = document.build_pk_array(pks_list) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
    defer pks.deinit();

    zvec.zvec_clear_error();
    var results: [*c]zvec.zvec_write_result_t = undefined;
    var result_count: usize = 0;
    const rc = zvec.zvec_collection_delete_with_results(data.ptr, @ptrCast(pks.ptrs), pks.count, @ptrCast(&results), &result_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    const results_list = document.make_write_results_list(results, result_count);
    zvec.zvec_write_results_free(@ptrCast(results), result_count);

    return beam.make(.{ .ok, results_list }, .{});
}

pub fn collection_delete_by_filter(resource_term: beam.term, filter_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var filter_buf: [65536]u8 = undefined;
    const filter_cstr = common.get_binary_as_cstr(filter_term, &filter_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid filter expression" } }, .{});

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_delete_by_filter(data.ptr, filter_cstr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_create_index(resource_term: beam.term, field_name_term: beam.term, index_map: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var field_buf: [4096]u8 = undefined;
    const field_cstr = common.get_binary_as_cstr(field_name_term, &field_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid field name" } }, .{});

    var params: ?*zvec.zvec_index_params_t = null;
    const build_result = schema.build_index_params(index_map, &params);
    if (!common.atom_eql(build_result, "ok")) return build_result;
    defer zvec.zvec_index_params_destroy(params);

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_create_index(data.ptr, field_cstr, params);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_drop_index(resource_term: beam.term, field_name_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var field_buf: [4096]u8 = undefined;
    const field_cstr = common.get_binary_as_cstr(field_name_term, &field_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid field name" } }, .{});

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_drop_index(data.ptr, field_cstr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_add_column(resource_term: beam.term, field_map: beam.term, expression_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    const built = schema.build_field_schema(field_map);
    if (built.field_schema == null) return built.result;
    defer zvec.zvec_field_schema_destroy(built.field_schema);

    var expr_buf: [65536]u8 = undefined;
    const expr_cstr: ?[*:0]const u8 = if (common.atom_eql(expression_term, "nil"))
        null
    else
        common.get_binary_as_cstr(expression_term, &expr_buf);

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_add_column(data.ptr, built.field_schema, expr_cstr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_drop_column(resource_term: beam.term, column_name_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var name_buf: [4096]u8 = undefined;
    const name_cstr = common.get_binary_as_cstr(column_name_term, &name_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid column name" } }, .{});

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_drop_column(data.ptr, name_cstr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_alter_column(resource_term: beam.term, column_name_term: beam.term, new_name_term: beam.term, new_schema_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var col_buf: [4096]u8 = undefined;
    const col_cstr = common.get_binary_as_cstr(column_name_term, &col_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid column name" } }, .{});

    var rename_buf: [4096]u8 = undefined;
    const new_name_cstr: ?[*:0]const u8 = if (common.atom_eql(new_name_term, "nil"))
        null
    else
        common.get_binary_as_cstr(new_name_term, &rename_buf) orelse
            return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid new column name" } }, .{});

    var new_field_schema: ?*zvec.zvec_field_schema_t = null;

    if (!common.atom_eql(new_schema_term, "nil")) {
        const built = schema.build_field_schema(new_schema_term);
        if (built.field_schema == null) return built.result;
        new_field_schema = built.field_schema;
    }
    defer if (new_field_schema) |fs| zvec.zvec_field_schema_destroy(fs);

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_alter_column(data.ptr, col_cstr, new_name_cstr, new_field_schema);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_fetch(resource_term: beam.term, pks_list: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    if (data.closed) {
        return beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{});
    }

    var pks = document.build_pk_array(pks_list) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "failed to build primary key array" } }, .{});
    defer pks.deinit();

    zvec.zvec_clear_error();
    var result_docs: [*c]?*zvec.zvec_doc_t = undefined;
    var found_count: usize = 0;
    const rc = zvec.zvec_collection_fetch(data.ptr, @ptrCast(pks.ptrs), pks.count, @ptrCast(&result_docs), &found_count);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    var docs_result_list = beam.make_empty_list(.{});
    var di: usize = found_count;
    while (di > 0) {
        di -= 1;
        if (result_docs[di]) |doc_ptr| {
            const doc_term = document.extract_doc_to_term(doc_ptr);
            docs_result_list = beam.make_list_cell(doc_term, docs_result_list, .{});
        }
    }

    zvec.zvec_docs_free(@ptrCast(result_docs), found_count);

    return beam.make(.{ .ok, docs_result_list }, .{});
}
