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

    pub fn getReference(self: GCObj) *GCObj {
        self.ref_counter += 1;
        return &self;
    }

    pub fn deleteReference(self: *GCObj, allocator: std.mem.Allocator) void {
        self.ref_counter -= 1;
        if (self.ref_counter == 0) {
            switch (self.obj) {
                .symbol => |_| {
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

const Symbol = struct {
    name: std.ArrayList(u8),
};

const Enviroment = std.ArrayHashMap(Symbol, *GCObj, true);

//pub fn read(str: []u8) !LispObj {} // TODO
