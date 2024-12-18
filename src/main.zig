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
        return MemoryManager {
            .last_allocated_object = null,
            .allocator = allocator,
        }
    }

    pub fn makeGCObj(self: MemoryManager, obj: LispObj) !*GCObj {
        var gco = try self.allocator.create(GCObj);
        gco.obj = obj;
        gco.last_obj = self.last_allocated_object;
        self.last_allocated_object = gco;

        return gco;
    }

    pub fn mark_all_not_reachable(self: MemoryManager) void {
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

    pub fn recursively_mark_reachable(obj: *GCObj) void {
        obj.is_reachable = true;
        switch (obj.obj) {
            .symbol => |sym| {
                sym.name.recursively_mark_reachable();
            },
            .cons_cell => |cell| {
                cell.car.recursively_mark_reachable();
                cell.cdr.recursively_mark_reachable();
            },
            .str => {
                // Todo
            },

            .number => {

            },


        }
    }

    pub fn mark_not_reachable(self: *GCObj) void {
        self.is_reachable = false;
    }
};

const ConsCell = struct {
    car: *GCObj,
    cdr: *GCObj,
};

const Symbol = struct {
    name: *GCObj, // Str

    pub fn new(mem_man: MemoryManager, name: *GCObj) !*GCObj {
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = name } });
    }
};

const Str = struct {
    string: []u8,

    pub fn new(mem_man: MemoryManager, str: []u8) *GCObj {
        var str_mem = mem_man.allocator.alloc(u8, str.len);
        std.mem.copyForwards(u8, str_mem, str);

        return try mem_man.makeGCObj(.{ .str = str_mem });
    }
};
