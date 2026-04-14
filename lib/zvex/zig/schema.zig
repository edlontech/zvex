const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");
const common = @import("common.zig");
const zvec = common.zvec;
const types = @import("types.zig");
const resource = @import("resource.zig");

fn create_collection_options(opts_map: beam.term) ?*zvec.zvec_collection_options_t {
    const options = zvec.zvec_collection_options_create();
    if (options == null) return null;

    if (common.get_map_value(opts_map, "mmap")) |mmap_term| {
        const val = beam.get(bool, mmap_term, .{}) catch false;
        _ = zvec.zvec_collection_options_set_enable_mmap(options, val);
    }

    if (common.get_map_value(opts_map, "max_buffer_size")) |mbs_term| {
        if (common.get_int_from_term(u64, mbs_term)) |val| {
            _ = zvec.zvec_collection_options_set_max_buffer_size(options, val);
        }
    }

    if (common.get_map_value(opts_map, "read_only")) |ro_term| {
        const val = beam.get(bool, ro_term, .{}) catch false;
        _ = zvec.zvec_collection_options_set_read_only(options, val);
    }

    return options;
}

pub fn build_index_params(index_map: beam.term, out: *?*zvec.zvec_index_params_t) beam.term {
    const type_term = common.get_map_value(index_map, "type") orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "index missing :type" } }, .{});

    const idx_type = types.atom_to_index_type(type_term) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "unknown index type" } }, .{});

    const params = zvec.zvec_index_params_create(idx_type) orelse
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate index params" } }, .{});

    if (common.get_map_value(index_map, "metric")) |mt| {
        if (types.atom_to_metric_type(mt)) |metric| {
            _ = zvec.zvec_index_params_set_metric_type(params, metric);
        }
    }

    if (common.get_map_value(index_map, "quantize")) |qt| {
        if (types.atom_to_quantize_type(qt)) |quantize| {
            _ = zvec.zvec_index_params_set_quantize_type(params, quantize);
        }
    }

    if (idx_type == zvec.ZVEC_INDEX_TYPE_HNSW) {
        const m_term = common.get_map_value(index_map, "m");
        const ef_term = common.get_map_value(index_map, "ef_construction");
        const m: c_int = if (m_term) |t| (common.get_int_from_term(c_int, t) orelse 16) else 16;
        const ef: c_int = if (ef_term) |t| (common.get_int_from_term(c_int, t) orelse 200) else 200;
        _ = zvec.zvec_index_params_set_hnsw_params(params, m, ef);
    }

    if (idx_type == zvec.ZVEC_INDEX_TYPE_IVF) {
        const nl_term = common.get_map_value(index_map, "n_list");
        const ni_term = common.get_map_value(index_map, "n_iters");
        const soar_term = common.get_map_value(index_map, "use_soar");
        const n_list: c_int = if (nl_term) |t| (common.get_int_from_term(c_int, t) orelse 128) else 128;
        const n_iters: c_int = if (ni_term) |t| (common.get_int_from_term(c_int, t) orelse 10) else 10;
        const use_soar: bool = if (soar_term) |t| (beam.get(bool, t, .{}) catch false) else false;
        _ = zvec.zvec_index_params_set_ivf_params(params, n_list, n_iters, use_soar);
    }

    if (idx_type == zvec.ZVEC_INDEX_TYPE_INVERT) {
        const ro_term = common.get_map_value(index_map, "enable_range_opt");
        const wc_term = common.get_map_value(index_map, "enable_wildcard");
        const range_opt: bool = if (ro_term) |t| (beam.get(bool, t, .{}) catch false) else false;
        const wildcard: bool = if (wc_term) |t| (beam.get(bool, t, .{}) catch false) else false;
        _ = zvec.zvec_index_params_set_invert_params(params, range_opt, wildcard);
    }

    out.* = params;
    return beam.make(.ok, .{});
}

const FieldSchemaResult = struct { result: beam.term, field_schema: ?*zvec.zvec_field_schema_t };

pub fn build_field_schema(field_map: beam.term) FieldSchemaResult {
    const fname_term = common.get_map_value(field_map, "name") orelse
        return .{ .result = beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "field missing :name" } }, .{}), .field_schema = null };

    var fname_buf: [1024]u8 = undefined;
    const fname_cstr = common.get_binary_as_cstr(fname_term, &fname_buf) orelse
        return .{ .result = beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid field name" } }, .{}), .field_schema = null };

    const dtype_term = common.get_map_value(field_map, "data_type") orelse
        return .{ .result = beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "field missing :data_type" } }, .{}), .field_schema = null };

    const data_type = types.atom_to_data_type(dtype_term) orelse
        return .{ .result = beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "unknown data type" } }, .{}), .field_schema = null };

    const nullable_term = common.get_map_value(field_map, "nullable");
    const nullable: bool = if (nullable_term) |t| (beam.get(bool, t, .{}) catch false) else false;

    const dim_term = common.get_map_value(field_map, "dimension");
    const dimension: u32 = if (dim_term) |t| (common.get_int_from_term(u32, t) orelse 0) else 0;

    const field_schema = zvec.zvec_field_schema_create(fname_cstr, data_type, nullable, dimension) orelse
        return .{ .result = beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate field schema" } }, .{}), .field_schema = null };

    if (common.get_map_value(field_map, "index")) |index_map| {
        if (!common.atom_eql(index_map, "nil")) {
            const idx_result = setup_index_params(field_schema, index_map);
            if (!common.atom_eql(idx_result, "ok")) {
                zvec.zvec_field_schema_destroy(field_schema);
                return .{ .result = idx_result, .field_schema = null };
            }
        }
    }

    return .{ .result = beam.make(.ok, .{}), .field_schema = field_schema };
}

fn setup_index_params(field_schema: *zvec.zvec_field_schema_t, index_map: beam.term) beam.term {
    var params: ?*zvec.zvec_index_params_t = null;
    const result = build_index_params(index_map, &params);
    if (!common.atom_eql(result, "ok")) return result;

    const params_ptr = params orelse
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "index params unexpectedly null" } }, .{});

    zvec.zvec_clear_error();
    const rc = zvec.zvec_field_schema_set_index_params(field_schema, params_ptr);
    zvec.zvec_index_params_destroy(params_ptr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}

pub fn collection_create_and_open(path_term: beam.term, schema_map: beam.term, opts_map: beam.term) beam.term {
    var path_buf: [4096]u8 = undefined;
    const path_cstr = common.get_binary_as_cstr(path_term, &path_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid path" } }, .{});

    const name_term = common.get_map_value(schema_map, "name") orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "schema missing :name" } }, .{});

    var name_buf: [1024]u8 = undefined;
    const name_cstr = common.get_binary_as_cstr(name_term, &name_buf) orelse
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid schema name" } }, .{});

    const c_schema = zvec.zvec_collection_schema_create(name_cstr);
    if (c_schema == null)
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection schema" } }, .{});

    if (common.get_map_value(schema_map, "max_doc_count_per_segment")) |mdc_term| {
        if (common.get_int_from_term(u64, mdc_term)) |val| {
            _ = zvec.zvec_collection_schema_set_max_doc_count_per_segment(c_schema, val);
        }
    }

    const fields_term = common.get_map_value(schema_map, "fields") orelse {
        zvec.zvec_collection_schema_destroy(c_schema);
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "schema missing :fields" } }, .{});
    };

    var list = fields_term.v;
    var head: e.ErlNifTerm = undefined;
    var tail: e.ErlNifTerm = undefined;

    while (e.enif_get_list_cell(beam.context.env, list, &head, &tail) == 1) : (list = tail) {
        const field_map = beam.term{ .v = head };

        const built = build_field_schema(field_map);
        if (built.field_schema == null) {
            zvec.zvec_collection_schema_destroy(c_schema);
            return built.result;
        }

        zvec.zvec_clear_error();
        const add_rc = zvec.zvec_collection_schema_add_field(c_schema, built.field_schema);
        zvec.zvec_field_schema_destroy(built.field_schema);

        if (add_rc != zvec.ZVEC_OK) {
            zvec.zvec_collection_schema_destroy(c_schema);
            return common.make_error_result(add_rc);
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
        return common.make_error_result(rc);
    }

    const collection_ptr = collection orelse
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "collection pointer is null after create" } }, .{});

    const res = resource.CollectionResource.create(.{
        .ptr = collection_ptr,
    }, .{}) catch
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection resource" } }, .{});

    const resource_term = res.make(.{});
    return beam.make(.{ .ok, resource_term }, .{});
}

pub fn collection_open(path_term: beam.term, opts_map: beam.term) beam.term {
    var path_buf: [4096]u8 = undefined;
    const path_cstr = common.get_binary_as_cstr(path_term, &path_buf) orelse
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
        return common.make_error_result(rc);
    }

    const collection_ptr = collection orelse
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "collection pointer is null after open" } }, .{});

    const res = resource.CollectionResource.create(.{
        .ptr = collection_ptr,
    }, .{}) catch
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate collection resource" } }, .{});

    const resource_term = res.make(.{});
    return beam.make(.{ .ok, resource_term }, .{});
}

pub fn collection_get_schema(resource_term: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();

    zvec.zvec_clear_error();
    var c_schema: ?*zvec.zvec_collection_schema_t = null;
    const rc = zvec.zvec_collection_get_schema(data.ptr, &c_schema);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    const schema_ptr = c_schema orelse
        return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "schema returned null" } }, .{});

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
        return common.make_error_result(names_rc);
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
        const dt_atom = types.data_type_to_atom(dt);

        const is_nullable = zvec.zvec_field_schema_is_nullable(field_ptr);
        const dim = zvec.zvec_field_schema_get_dimension(field_ptr);
        const has_idx = zvec.zvec_field_schema_has_index(field_ptr);

        var field_entry: beam.term = undefined;

        if (has_idx) {
            const idx_type = zvec.zvec_field_schema_get_index_type(field_ptr);
            const idx_type_atom = types.index_type_to_atom(idx_type);

            const idx_params = zvec.zvec_field_schema_get_index_params(field_ptr);

            if (idx_params != null) {
                const metric = zvec.zvec_index_params_get_metric_type(idx_params);
                const metric_atom = types.metric_type_to_atom(metric);
                const quantize = zvec.zvec_index_params_get_quantize_type(idx_params);
                const quantize_atom = types.quantize_type_to_atom(quantize);

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
