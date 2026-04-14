const std = @import("std");
const beam = @import("beam");
const e = @import("erl_nif");
const common = @import("common.zig");
const zvec = common.zvec;

pub fn atom_to_log_level(term_val: beam.term) ?c_uint {
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

pub fn atom_to_data_type(term_val: beam.term) ?zvec.zvec_data_type_t {
    if (common.atom_eql(term_val, "string")) return zvec.ZVEC_DATA_TYPE_STRING;
    if (common.atom_eql(term_val, "int32")) return zvec.ZVEC_DATA_TYPE_INT32;
    if (common.atom_eql(term_val, "int64")) return zvec.ZVEC_DATA_TYPE_INT64;
    if (common.atom_eql(term_val, "uint32")) return zvec.ZVEC_DATA_TYPE_UINT32;
    if (common.atom_eql(term_val, "uint64")) return zvec.ZVEC_DATA_TYPE_UINT64;
    if (common.atom_eql(term_val, "float")) return zvec.ZVEC_DATA_TYPE_FLOAT;
    if (common.atom_eql(term_val, "double")) return zvec.ZVEC_DATA_TYPE_DOUBLE;
    if (common.atom_eql(term_val, "bool")) return zvec.ZVEC_DATA_TYPE_BOOL;
    if (common.atom_eql(term_val, "binary")) return zvec.ZVEC_DATA_TYPE_BINARY;
    if (common.atom_eql(term_val, "vector_fp32")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP32;
    if (common.atom_eql(term_val, "vector_fp16")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP16;
    if (common.atom_eql(term_val, "vector_fp64")) return zvec.ZVEC_DATA_TYPE_VECTOR_FP64;
    if (common.atom_eql(term_val, "vector_int4")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT4;
    if (common.atom_eql(term_val, "vector_int8")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT8;
    if (common.atom_eql(term_val, "vector_int16")) return zvec.ZVEC_DATA_TYPE_VECTOR_INT16;
    if (common.atom_eql(term_val, "vector_binary32")) return zvec.ZVEC_DATA_TYPE_VECTOR_BINARY32;
    if (common.atom_eql(term_val, "vector_binary64")) return zvec.ZVEC_DATA_TYPE_VECTOR_BINARY64;
    if (common.atom_eql(term_val, "sparse_vector_fp16")) return zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP16;
    if (common.atom_eql(term_val, "sparse_vector_fp32")) return zvec.ZVEC_DATA_TYPE_SPARSE_VECTOR_FP32;
    if (common.atom_eql(term_val, "array_string")) return zvec.ZVEC_DATA_TYPE_ARRAY_STRING;
    if (common.atom_eql(term_val, "array_int32")) return zvec.ZVEC_DATA_TYPE_ARRAY_INT32;
    if (common.atom_eql(term_val, "array_int64")) return zvec.ZVEC_DATA_TYPE_ARRAY_INT64;
    if (common.atom_eql(term_val, "array_uint32")) return zvec.ZVEC_DATA_TYPE_ARRAY_UINT32;
    if (common.atom_eql(term_val, "array_uint64")) return zvec.ZVEC_DATA_TYPE_ARRAY_UINT64;
    if (common.atom_eql(term_val, "array_float")) return zvec.ZVEC_DATA_TYPE_ARRAY_FLOAT;
    if (common.atom_eql(term_val, "array_double")) return zvec.ZVEC_DATA_TYPE_ARRAY_DOUBLE;
    if (common.atom_eql(term_val, "array_bool")) return zvec.ZVEC_DATA_TYPE_ARRAY_BOOL;
    if (common.atom_eql(term_val, "array_binary")) return zvec.ZVEC_DATA_TYPE_ARRAY_BINARY;
    return null;
}

pub fn data_type_to_atom(dt: zvec.zvec_data_type_t) beam.term {
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

pub fn atom_to_index_type(term_val: beam.term) ?zvec.zvec_index_type_t {
    if (common.atom_eql(term_val, "hnsw")) return zvec.ZVEC_INDEX_TYPE_HNSW;
    if (common.atom_eql(term_val, "ivf")) return zvec.ZVEC_INDEX_TYPE_IVF;
    if (common.atom_eql(term_val, "flat")) return zvec.ZVEC_INDEX_TYPE_FLAT;
    if (common.atom_eql(term_val, "invert")) return zvec.ZVEC_INDEX_TYPE_INVERT;
    return null;
}

pub fn index_type_to_atom(it: zvec.zvec_index_type_t) beam.term {
    return switch (it) {
        zvec.ZVEC_INDEX_TYPE_HNSW => beam.make(.hnsw, .{}),
        zvec.ZVEC_INDEX_TYPE_IVF => beam.make(.ivf, .{}),
        zvec.ZVEC_INDEX_TYPE_FLAT => beam.make(.flat, .{}),
        zvec.ZVEC_INDEX_TYPE_INVERT => beam.make(.invert, .{}),
        else => beam.make(.undefined, .{}),
    };
}

pub fn atom_to_metric_type(term_val: beam.term) ?zvec.zvec_metric_type_t {
    if (common.atom_eql(term_val, "l2")) return zvec.ZVEC_METRIC_TYPE_L2;
    if (common.atom_eql(term_val, "ip")) return zvec.ZVEC_METRIC_TYPE_IP;
    if (common.atom_eql(term_val, "cosine")) return zvec.ZVEC_METRIC_TYPE_COSINE;
    if (common.atom_eql(term_val, "mipsl2")) return zvec.ZVEC_METRIC_TYPE_MIPSL2;
    return null;
}

pub fn metric_type_to_atom(mt: zvec.zvec_metric_type_t) beam.term {
    return switch (mt) {
        zvec.ZVEC_METRIC_TYPE_L2 => beam.make(.l2, .{}),
        zvec.ZVEC_METRIC_TYPE_IP => beam.make(.ip, .{}),
        zvec.ZVEC_METRIC_TYPE_COSINE => beam.make(.cosine, .{}),
        zvec.ZVEC_METRIC_TYPE_MIPSL2 => beam.make(.mipsl2, .{}),
        else => beam.make(.@"nil", .{}),
    };
}

pub fn atom_to_quantize_type(term_val: beam.term) ?zvec.zvec_quantize_type_t {
    if (common.atom_eql(term_val, "fp16")) return zvec.ZVEC_QUANTIZE_TYPE_FP16;
    if (common.atom_eql(term_val, "int8")) return zvec.ZVEC_QUANTIZE_TYPE_INT8;
    if (common.atom_eql(term_val, "int4")) return zvec.ZVEC_QUANTIZE_TYPE_INT4;
    return null;
}

pub fn quantize_type_to_atom(qt: zvec.zvec_quantize_type_t) beam.term {
    return switch (qt) {
        zvec.ZVEC_QUANTIZE_TYPE_FP16 => beam.make(.fp16, .{}),
        zvec.ZVEC_QUANTIZE_TYPE_INT8 => beam.make(.int8, .{}),
        zvec.ZVEC_QUANTIZE_TYPE_INT4 => beam.make(.int4, .{}),
        else => beam.make(.@"nil", .{}),
    };
}
