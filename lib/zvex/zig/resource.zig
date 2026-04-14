const beam = @import("beam");
const root = @import("root");
const common = @import("common.zig");
const zvec = common.zvec;

pub const CollectionData = struct {
    ptr: *zvec.zvec_collection_t,
    closed: bool,
};

pub const CollectionCallbacks = struct {
    pub fn dtor(data: *CollectionData) void {
        if (!data.closed) {
            _ = zvec.zvec_collection_close(data.ptr);
        }
    }
};

pub const CollectionResource = beam.Resource(CollectionData, root, .{ .Callbacks = CollectionCallbacks });
