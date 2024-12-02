const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    env: Enviroment,
};

const GCObj = struct {
    ref_counter: isize,
    obj: LispObj,

    pub fn new(allocator: std.mem.Allocator, obj: LispObj) !*GCObj {
        var gco = try allocator.create(GCObj);

        gco.ref_counter = 1;
        gco.obj = obj;

        return gco;
    }

    pub fn getReference(self: GCObj) *GCObj {
        self.ref_counter += 1;
        return &self;
    }

    pub fn deleteReference(self: *GCObj, allocator: std.mem.Allocator) void {
        self.ref_counter -= 1;
        if (self.ref_counter == 0) {
            switch (self.obj) {
                .symbol => |sym| {
                    sym.delete(allocator);
                    allocator.destroy(self);
                },
                .cons_cell => |cell| {
                    deleteReference(cell.car, allocator);
                    deleteReference(cell.cdr, allocator);
                    allocator.destroy(self);
                },
            }
        }
    }
};

const ConsCell = struct {
    car: *GCObj,
    cdr: *GCObj,
};

const SymbolPackage = struct { symbols: std.StringHashMap(*GCObj) };

const Symbol = struct {
    name: []const u8,

    fn new(allocator: std.mem.Allocator, name: []const u8) !*GCObj {
        const name_memory = try allocator.alloc(u8, name.len);
        std.mem.copyForwards(u8, name_memory, name);

        const gco = try GCObj.new(.{
            .symbol = .{ .name = name_memory },
        });

        return gco;
    }

    fn delete(self: Symbol, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Enviroment = std.ArrayHashMap(Symbol, *GCObj, true);

//pub fn read(str: []u8) !LispObj {} // TODO
