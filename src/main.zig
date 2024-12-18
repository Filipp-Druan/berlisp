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
                sym.markPropogate();
            },
            .cons_cell => |cell| {
                cell.markPropogate();
            },
            .str => |str| {
                str.markPropogate();
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

    pub fn markPropogate(self: ConsCell) void {
        self.car.recursivelyMarkReachable();
        self.cdr.recursivelyMarkReachable();
    }
};

const Symbol = struct {
    name: *GCObj, // Str

    pub fn new(mem_man: MemoryManager, name: *GCObj) !*GCObj {
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = name } });
    }

    pub fn markPropogate(self: Symbol) void {
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

    pub fn markPropogate(self: Str) void {
        _ = self;
    }
};

const Enviroment = struct {
    map: EnvMap,
    next: *GCObj,

    const EnvMap = std.AutoHashMap([]u8, *GCObj);

    pub fn new(mem_man: MemoryManager, next: *GCObj) !GCObj { // next - всегда Enviroment
        const map = EnvMap.init(mem_man.allocator);
        mem_man.makeGCObj(.{ .enviroment = .{
            .map = map,
            .next = next,
        } });
    }

    pub fn markPropagate(self: Enviroment) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |val| {
            val.value_ptr.*.recursivelyMarkReachable();
        }
    }
};
