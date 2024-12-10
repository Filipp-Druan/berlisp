const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    enviroment: Enviroment,
};

const RCObj = struct {
    ref_counter: isize,
    obj: LispObj,

    pub fn new(allocator: std.mem.Allocator, obj: LispObj) !*RCObj {
        var rco = try allocator.create(RCObj);

        rco = .{ .ref_counter = 1, .obj = obj };

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
                .enviroment => |env| {
                    env.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
            }
        }
    }
};

const ConsCell = struct {
    car: *RCObj,
    cdr: *RCObj,

    fn new(allocator: std.mem.Allocator, car: *RCObj, cdr: *RCObj) !*RCObj {
        return RCObj.new(allocator, .{ .cons_cell = .{ .car = car, .cdr = cdr } });
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

        const rco = try RCObj.new(allocator, .{
            .symbol = .{ .name = name_memory },
        });

        return rco;
    }

    fn prepareToRemove(self: Symbol, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Enviroment = struct {
    map: std.AutoHashMap(
        Symbol,
        *RCObj,
    ),

    pub fn prepareToRemove(self: Enviroment, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

test "Создаём и удаляем объекты, ищем утечки памяти" {
    const allocator = std.testing.allocator;
    const sym_1 = try Symbol.new(allocator, "Hello!");
    const sym_2 = try Symbol.new(allocator, "Friends!p");
    var list = try ConsCell.new(allocator, sym_1, sym_2);
    list.deleteReference(allocator);
}
