const std = @import("std");
const beam = @import("beam");
const root = @import("root");
const common = @import("common.zig");
const zvec = common.zvec;

pub const CollectionData = struct {
    ptr: *zvec.zvec_collection_t,
    closed: bool,
    lock: std.Thread.RwLock = .{},
};

pub const CollectionCallbacks = struct {
    pub fn dtor(data: *CollectionData) void {
        if (@cmpxchgStrong(bool, &data.closed, false, true, .seq_cst, .seq_cst) == null) {
            _ = zvec.zvec_collection_close(data.ptr);
        }
    }
};

pub const CollectionResource = beam.Resource(CollectionData, root, .{ .Callbacks = CollectionCallbacks });

pub const CollectionGuard = struct {
    ptr: *zvec.zvec_collection_t,
    data: *CollectionData,

    pub fn release(self: *CollectionGuard) void {
        self.data.lock.unlockShared();
    }
};

pub const OpenCollection = union(enum) {
    ok: CollectionGuard,
    err: beam.term,
};

pub fn open_collection(resource_term: beam.term) OpenCollection {
    var res: CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return .{ .err = beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{}) };

    const data: *CollectionData = res.__payload;
    data.lock.lockShared();

    if (@atomicLoad(bool, &data.closed, .seq_cst)) {
        data.lock.unlockShared();
        return .{ .err = beam.make(.{ .@"error", .{ beam.make(.failed_precondition, .{}), "collection is closed" } }, .{}) };
    }

    return .{ .ok = .{ .ptr = data.ptr, .data = data } };
}

pub fn close_collection(resource_term: beam.term) beam.term {
    var res: CollectionResource = undefined;
    res.get(resource_term, .{ .released = false }) catch
        return beam.make(.{ .@"error", .{ beam.make(.invalid_argument, .{}), "invalid collection resource" } }, .{});

    const data: *CollectionData = res.__payload;
    data.lock.lock();
    defer data.lock.unlock();

    if (data.closed) {
        return beam.make(.ok, .{});
    }

    data.closed = true;

    zvec.zvec_clear_error();
    const rc = zvec.zvec_collection_close(data.ptr);

    if (rc != zvec.ZVEC_OK) {
        return common.make_error_result(rc);
    }

    return beam.make(.ok, .{});
}
