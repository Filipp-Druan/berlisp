const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    enviroment: Enviroment,
    str: Str,
    number: Number,
};

const MemoryManager = struct {
    last_allocated_object: ?*GCObj,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator) MemoryManager {
        return MemoryManager{
            .last_allocated_object = null,
            .allocator = allocator,
        };
    }

    pub fn makeGCObj(self: MemoryManager, obj: LispObj) !*GCObj {
        var gco = try self.allocator.create(GCObj);
        gco.obj = obj;
        gco.last_obj = self.last_allocated_object;
        self.last_allocated_object = gco;

        return gco;
    }

    pub fn markAllNotReachable(self: MemoryManager) void {
        var current_obj = self.last_allocated_object;
        while (current_obj) {
            current_obj.mark_not_reachable();
        }
    }
};

const GCObj = struct {
    last_obj: ?*GCObj,
    is_reachable: bool,
    obj: LispObj,

    pub fn recursivelyMarkReachable(obj: *GCObj) void {
        obj.is_reachable = true;
        switch (obj.obj) {
            .symbol => |sym| {
                sym.mark_propogate();
            },
            .cons_cell => |cell| {
                cell.mark_propogate();
            },
            .str => |str| {
                str.mark_propogate();
            },

            .number => {},
        }
    }

    pub fn markNotReachable(self: *GCObj) void {
        self.is_reachable = false;
    }
};

const ConsCell = struct {
    car: *GCObj,
    cdr: *GCObj,

    pub fn mark_propogate(self: ConsCell) void {
        self.car.recursivelyMarkReachable();
        self.cdr.recursivelyMarkReachable();
    }
};

const Symbol = struct {
    name: *GCObj, // Str

    pub fn new(mem_man: MemoryManager, name: *GCObj) !*GCObj {
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = name } });
    }

    pub fn mark_propogate(self: Symbol) void {
        self.name.recursivelyMarkReachable();
    }
};

const Str = struct {
    string: []u8,

    pub fn new(mem_man: MemoryManager, str: []u8) *GCObj {
        const str_mem = mem_man.allocator.alloc(u8, str.len);
        std.mem.copyForwards(u8, str_mem, str);

        return try mem_man.makeGCObj(.{ .str = str_mem });
    }

    pub fn mark_propogate(self: Str) void {
        _ = self;
    }
};
