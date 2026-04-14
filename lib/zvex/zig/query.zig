const beam = @import("beam");
const e = @import("erl_nif");
const common = @import("common.zig");
const zvec = common.zvec;
const types = @import("types.zig");
const document = @import("document.zig");
const resource = @import("resource.zig");

pub fn collection_query(resource_term: beam.term, query_map: beam.term) beam.term {
    var res: resource.CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data = res.unpack();


    const query = zvec.zvec_vector_query_create() orelse
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate query" } }, .{});

    const field_term = common.get_map_value(query_map, "field") orelse {
        zvec.zvec_vector_query_destroy(query);
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "missing field" } }, .{});
    };
    var field_buf: [4096]u8 = undefined;
    const field_cstr = common.get_binary_as_cstr(field_term, &field_buf) orelse {
        zvec.zvec_vector_query_destroy(query);
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid field name" } }, .{});
    };
    zvec.zvec_clear_error();
    {
        const rc = zvec.zvec_vector_query_set_field_name(query, field_cstr);
        if (rc != zvec.ZVEC_OK) {
            zvec.zvec_vector_query_destroy(query);
            return common.make_error_result(rc);
        }
    }

    const vector_term = common.get_map_value(query_map, "vector") orelse {
        zvec.zvec_vector_query_destroy(query);
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "missing vector" } }, .{});
    };
    {
        var vec_bin: e.ErlNifBinary = undefined;
        if (e.enif_inspect_binary(beam.context.env, vector_term.v, &vec_bin) == 0) {
            zvec.zvec_vector_query_destroy(query);
            return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid vector binary" } }, .{});
        }
        zvec.zvec_clear_error();
        const rc = zvec.zvec_vector_query_set_query_vector(query, vec_bin.data, vec_bin.size);
        if (rc != zvec.ZVEC_OK) {
            zvec.zvec_vector_query_destroy(query);
            return common.make_error_result(rc);
        }
    }

    if (common.get_map_value(query_map, "top_k")) |topk_term| {
        if (common.get_int_from_term(c_int, topk_term)) |topk| {
            _ = zvec.zvec_vector_query_set_topk(query, topk);
        }
    }

    if (common.get_map_value(query_map, "filter")) |filter_term| {
        if (!common.atom_eql(filter_term, "nil")) {
            var filter_buf: [65536]u8 = undefined;
            if (common.get_binary_as_cstr(filter_term, &filter_buf)) |filter_cstr| {
                zvec.zvec_clear_error();
                const rc = zvec.zvec_vector_query_set_filter(query, filter_cstr);
                if (rc != zvec.ZVEC_OK) {
                    zvec.zvec_vector_query_destroy(query);
                    return common.make_error_result(rc);
                }
            }
        }
    }

    if (common.get_map_value(query_map, "output_fields")) |fields_list_term| {
        var fields_arr = document.build_pk_array(fields_list_term) orelse {
            zvec.zvec_vector_query_destroy(query);
            return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to build output fields array" } }, .{});
        };
        defer fields_arr.deinit();
        if (fields_arr.count > 0) {
            zvec.zvec_clear_error();
            const rc = zvec.zvec_vector_query_set_output_fields(query, @ptrCast(fields_arr.ptrs), fields_arr.count);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_vector_query_destroy(query);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(query_map, "include_vector")) |iv_term| {
        _ = zvec.zvec_vector_query_set_include_vector(query, common.atom_eql(iv_term, "true"));
    }
    if (common.get_map_value(query_map, "include_doc_id")) |id_term| {
        _ = zvec.zvec_vector_query_set_include_doc_id(query, common.atom_eql(id_term, "true"));
    }

    if (common.get_map_value(query_map, "params")) |params_term| {
        if (!common.atom_eql(params_term, "nil")) {
            var arity: c_int = undefined;
            var tuple_ptr: [*c]const e.ErlNifTerm = undefined;
            if (e.enif_get_tuple(beam.context.env, params_term.v, &arity, &tuple_ptr) == 1 and arity == 2) {
                const type_term = beam.term{ .v = tuple_ptr[0] };
                const opts_map = beam.term{ .v = tuple_ptr[1] };

                if (common.atom_eql(type_term, "hnsw")) {
                    const hnsw_ef: c_int = if (common.get_map_value(opts_map, "ef")) |t| (common.get_int_from_term(c_int, t) orelse 0) else 0;
                    const hnsw_radius: f32 = if (common.get_map_value(opts_map, "radius")) |t| (common.get_float_from_term(t) orelse 0.0) else 0.0;
                    const hnsw_linear: bool = if (common.get_map_value(opts_map, "is_linear")) |t| common.atom_eql(t, "true") else false;
                    const hnsw_refiner: bool = if (common.get_map_value(opts_map, "use_refiner")) |t| common.atom_eql(t, "true") else false;
                    const hnsw = zvec.zvec_query_params_hnsw_create(hnsw_ef, hnsw_radius, hnsw_linear, hnsw_refiner) orelse {
                        zvec.zvec_vector_query_destroy(query);
                        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate hnsw params" } }, .{});
                    };
                    zvec.zvec_clear_error();
                    const rc = zvec.zvec_vector_query_set_hnsw_params(query, hnsw);
                    if (rc != zvec.ZVEC_OK) {
                        zvec.zvec_query_params_hnsw_destroy(hnsw);
                        zvec.zvec_vector_query_destroy(query);
                        return common.make_error_result(rc);
                    }
                } else if (common.atom_eql(type_term, "ivf")) {
                    const ivf_nprobe: c_int = if (common.get_map_value(opts_map, "nprobe")) |t| (common.get_int_from_term(c_int, t) orelse 0) else 0;
                    const ivf_refiner: bool = if (common.get_map_value(opts_map, "use_refiner")) |t| common.atom_eql(t, "true") else false;
                    const ivf_scale: f32 = if (common.get_map_value(opts_map, "scale_factor")) |t| (common.get_float_from_term(t) orelse 1.0) else 1.0;
                    const ivf = zvec.zvec_query_params_ivf_create(ivf_nprobe, ivf_refiner, ivf_scale) orelse {
                        zvec.zvec_vector_query_destroy(query);
                        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate ivf params" } }, .{});
                    };
                    if (common.get_map_value(opts_map, "radius")) |r_term| {
                        if (common.get_float_from_term(r_term)) |r| {
                            zvec.zvec_clear_error();
                            const rc = zvec.zvec_query_params_ivf_set_radius(ivf, r);
                            if (rc != zvec.ZVEC_OK) {
                                zvec.zvec_query_params_ivf_destroy(ivf);
                                zvec.zvec_vector_query_destroy(query);
                                return common.make_error_result(rc);
                            }
                        }
                    }
                    if (common.get_map_value(opts_map, "is_linear")) |il_term| {
                        zvec.zvec_clear_error();
                        const rc = zvec.zvec_query_params_ivf_set_is_linear(ivf, common.atom_eql(il_term, "true"));
                        if (rc != zvec.ZVEC_OK) {
                            zvec.zvec_query_params_ivf_destroy(ivf);
                            zvec.zvec_vector_query_destroy(query);
                            return common.make_error_result(rc);
                        }
                    }
                    zvec.zvec_clear_error();
                    const rc = zvec.zvec_vector_query_set_ivf_params(query, ivf);
                    if (rc != zvec.ZVEC_OK) {
                        zvec.zvec_query_params_ivf_destroy(ivf);
                        zvec.zvec_vector_query_destroy(query);
                        return common.make_error_result(rc);
                    }
                } else if (common.atom_eql(type_term, "flat")) {
                    // Flat (brute-force) search is implemented via HNSW params
                    // with is_linear=true, which forces a linear scan. Using the
                    // flat params API directly segfaults because the C library
                    // dispatches on the *index* type (e.g. HNSW) and then
                    // dynamic_casts the query params to the matching C++ class
                    // without a null-check.
                    const flat_radius: f32 = if (common.get_map_value(opts_map, "radius")) |r_term| (common.get_float_from_term(r_term) orelse 0.0) else 0.0;
                    const flat_refiner: bool = if (common.get_map_value(opts_map, "use_refiner")) |ur| common.atom_eql(ur, "true") else false;
                    const hnsw = zvec.zvec_query_params_hnsw_create(0, flat_radius, true, flat_refiner) orelse {
                        zvec.zvec_vector_query_destroy(query);
                        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate flat params" } }, .{});
                    };
                    zvec.zvec_clear_error();
                    const rc = zvec.zvec_vector_query_set_hnsw_params(query, hnsw);
                    if (rc != zvec.ZVEC_OK) {
                        zvec.zvec_query_params_hnsw_destroy(hnsw);
                        zvec.zvec_vector_query_destroy(query);
                        return common.make_error_result(rc);
                    }
                }
            }
        }
    }

    zvec.zvec_clear_error();
    var result_docs: [*c]?*zvec.zvec_doc_t = undefined;
    var result_count: usize = 0;
    const rc = zvec.zvec_collection_query(data.ptr, query, @ptrCast(&result_docs), &result_count);

    if (rc != zvec.ZVEC_OK) {
        zvec.zvec_vector_query_destroy(query);
        return common.make_error_result(rc);
    }

    var results_list = beam.make_empty_list(.{});
    var ri: usize = result_count;
    while (ri > 0) {
        ri -= 1;
        if (result_docs[ri]) |doc_ptr| {
            const result_term = document.extract_query_result_to_term(doc_ptr);
            results_list = beam.make_list_cell(result_term, results_list, .{});
        }
    }

    zvec.zvec_docs_free(@ptrCast(result_docs), result_count);
    zvec.zvec_vector_query_destroy(query);

    return beam.make(.{ .ok, results_list }, .{});
}
