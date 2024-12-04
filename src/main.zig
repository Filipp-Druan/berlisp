const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    env: Enviroment,
};

const RCObj = struct {
    ref_counter: isize,
    obj: LispObj,

    pub fn new(allocator: std.mem.Allocator, obj: LispObj) !*RCObj {
        var rco = try allocator.create(RCObj);

        rco.ref_counter = 1;
        rco.obj = obj;

        return rco;
    }

    pub fn getReference(self: RCObj) *RCObj {
        self.ref_counter += 1;
        return &self;
    }

    pub fn deleteReference(self: *RCObj, allocator: std.mem.Allocator) void {
        self.ref_counter -= 1;
        if (self.ref_counter == 0) {
            switch (self.obj) {
                .symbol => |sym| {
                    sym.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
                .cons_cell => |cell| {
                    cell.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
            }
        }
    }
};

const ConsCell = struct {
    car: *RCObj,
    cdr: *RCObj,

    fn new(allocator: std.mem.Allocator, car: *RCObj, cdr: *RCObj) *RCObj {
        return try RCObj.new(allocator, .{ .cons_cell = .{ .car = car, .cdr = cdr } });
    }

    fn prepareToRemove(self: ConsCell, allocator: std.mem.Allocator) void {
        self.car.deleteReference(allocator);
        self.cdr.deleteReference(allocator);
    }
};

const SymbolPackage = struct { symbols: std.StringHashMap(*RCObj) };

const Symbol = struct {
    name: []const u8,

    fn new(allocator: std.mem.Allocator, name: []const u8) !*RCObj {
        const name_memory = try allocator.alloc(u8, name.len);
        std.mem.copyForwards(u8, name_memory, name);

        const rco = try RCObj.new(.{
            .symbol = .{ .name = name_memory },
        });

        return rco;
    }

    fn prepareToRemove(self: Symbol, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Enviroment = std.ArrayHashMap(Symbol, *RCObj, true);

//pub fn read(str: []u8) !LispObj {} // TODO
