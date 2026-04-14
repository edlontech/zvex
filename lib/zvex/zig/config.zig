const beam = @import("beam");
const common = @import("common.zig");
const zvec = common.zvec;
const types = @import("types.zig");

fn create_log_config(log_map: beam.term) ?*zvec.zvec_log_config_t {
    const type_term = common.get_map_value(log_map, "type") orelse return null;
    const level_term = common.get_map_value(log_map, "level");
    const level: c_uint = if (level_term) |lt| (types.atom_to_log_level(lt) orelse zvec.ZVEC_LOG_LEVEL_INFO) else zvec.ZVEC_LOG_LEVEL_INFO;

    if (common.atom_eql(type_term, "console")) {
        return zvec.zvec_config_log_create_console(level);
    }

    return null;
}

pub fn initialize_with_config(config_map: beam.term) beam.term {
    zvec.zvec_clear_error();

    const config_data = zvec.zvec_config_data_create();
    if (config_data == null) {
        return beam.make(.{ .@"error", .{ beam.make(.resource_exhausted, .{}), "failed to allocate config" } }, .{});
    }

    if (common.get_map_value(config_map, "memory_limit")) |ml| {
        if (common.get_int_from_term(u64, ml)) |val| {
            const rc = zvec.zvec_config_data_set_memory_limit(config_data, val);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_config_data_destroy(config_data);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(config_map, "query_threads")) |qt| {
        if (common.get_int_from_term(u32, qt)) |val| {
            const rc = zvec.zvec_config_data_set_query_thread_count(config_data, val);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_config_data_destroy(config_data);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(config_map, "optimize_threads")) |ot| {
        if (common.get_int_from_term(u32, ot)) |val| {
            const rc = zvec.zvec_config_data_set_optimize_thread_count(config_data, val);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_config_data_destroy(config_data);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(config_map, "invert_to_forward_scan_ratio")) |ratio| {
        if (common.get_float_from_term(ratio)) |val| {
            const rc = zvec.zvec_config_data_set_invert_to_forward_scan_ratio(config_data, val);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_config_data_destroy(config_data);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(config_map, "brute_force_by_keys_ratio")) |ratio| {
        if (common.get_float_from_term(ratio)) |val| {
            const rc = zvec.zvec_config_data_set_brute_force_by_keys_ratio(config_data, val);
            if (rc != zvec.ZVEC_OK) {
                zvec.zvec_config_data_destroy(config_data);
                return common.make_error_result(rc);
            }
        }
    }

    if (common.get_map_value(config_map, "log")) |log_map| {
        const log_config = create_log_config(log_map);
        if (log_config == null) {
            zvec.zvec_config_data_destroy(config_data);
            return beam.make(.{ .@"error", .{ beam.make(.internal_error, .{}), "failed to create log configuration" } }, .{});
        }
        const rc = zvec.zvec_config_data_set_log_config(config_data, log_config);
        if (rc != zvec.ZVEC_OK) {
            zvec.zvec_config_log_destroy(log_config);
            zvec.zvec_config_data_destroy(config_data);
            return common.make_error_result(rc);
        }
    }

    const rc = zvec.zvec_initialize(config_data);
    zvec.zvec_config_data_destroy(config_data);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }
    return beam.make(.ok, .{});
}
