const std = @import("std");
const berlisp = @import("berlisp.zig");

const GCObj = berlisp.memory.GCObj;
const MemoryManager = berlisp.memory.MemoryManager;
const Environment = berlisp.env.Environment;

pub const LispObj = union(enum) {
    nil,
    symbol: Symbol,
    cons_cell: ConsCell,
    list: Vector,
    environment: Environment,
    str: Str,
    number: Number,
};

pub const ConsCell = struct {
    car: *GCObj,
    cdr: *GCObj,

    pub fn new(mem_man: *MemoryManager, car: *GCObj, cdr: *GCObj) !*GCObj {
        return try mem_man.makeGCObj(.{ .cons_cell = .{
            .car = car,
            .cdr = cdr,
        } });
    }

    pub fn markPropogate(self: *ConsCell) void {
        self.car.recursivelyMarkReachable();
        self.cdr.recursivelyMarkReachable();
    }

    pub fn prepareToRemove(self: *ConsCell, mem_man: *MemoryManager) void {
        _ = self;
        _ = mem_man;
    }

    pub fn len(self: *ConsCell) isize {
        switch (self.cdr.obj) {
            .nil => return 1,
            .cons_cell => |cell| {
                return 1 + cell.len();
            },
            else => return 2,
        }
    }
};

pub const Vector = struct {
    list: std.ArrayList(*GCObj),

    pub fn new(mem_man: *MemoryManager) !*GCObj {
        return try mem_man.makeGCObj(.{ .list = .{
            .list = std.ArrayList(*GCObj).init(mem_man.allocator),
        } });
    }

    pub fn markPropogate(self: *Vector) void {
        for (self.list.items) |value| {
            value.recursivelyMarkReachable();
        }
    }

    pub fn prepareToRemove(self: *Vector, mem_man: *MemoryManager) void {
        _ = mem_man;
        self.list.deinit();
    }

    pub fn len(self: *Vector) isize {
        return self.list.items.len;
    }
};

pub const Symbol = struct {
    name: *GCObj, // Str

    /// Низкоуровневый метод создания символа.
    /// Может создать несколько символов с одним именем.
    /// А этого нам не надо.
    /// Так что лучше использовать MemoryManager.intern
    pub fn new(mem_man: *MemoryManager, name: []const u8) !*GCObj {
        const name_str = try Str.new(mem_man, name);
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = name_str } });
    }

    pub fn fromStr(mem_man: *MemoryManager, str: Str) !*GCObj {
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = str } });
    }

    pub fn markPropogate(self: Symbol) void {
        self.name.recursivelyMarkReachable();
    }

    pub fn prepareToRemove(self: Symbol, mem_man: *MemoryManager) void {
        _ = self;
        _ = mem_man;
    }
};

pub const Str = struct {
    string: []u8,

    pub fn new(mem_man: *MemoryManager, str: []const u8) !*GCObj {
        const str_mem = try mem_man.allocator.dupe(u8, str);
        errdefer mem_man.allocator.free(str_mem);

        return try mem_man.makeGCObj(.{ .str = .{ .string = str_mem } });
    }

    pub fn copyGCObj(str: *Str, mem_man: *MemoryManager) !*GCObj {
        return try Str.new(mem_man, str.string);
    }

    pub fn markPropogate(self: *Str) void {
        _ = self;
    }

    pub fn prepareToRemove(self: *Str, mem_man: *MemoryManager) void {
        mem_man.allocator.free(self.string);
    }
};

/// Число. Над ним можно производить арифметические операции.
/// Может быть либо с плавающей точкой, либо целым.
/// Если одно число было с плавающей точкой, то результат операции тоже
/// будет таким.
///
/// Числа передаются не по ссылке, а по значению.
///
/// TODO:
///    1) Нужно разобраться, когда именно нужно аллоцировать число.
pub const Number = union(enum) {
    int: i64,
    double: f64,

    pub fn new(
        mem_man: *MemoryManager,
        comptime T: type,
        num: T,
    ) !*GCObj {
        var number: Number = undefined;

        switch (T) {
            i64 => number = .{ .int = num },
            f64 => number = .{ .double = num },
            else => @compileError("Bad type of Number"),
        }

        return try mem_man.makeGCObj(.{ .number = number });
    }

    pub fn copyGCObj(number: Number, mem_man: *MemoryManager) !*GCObj {
        const new_number = LispObj{ .number = number };
        return try mem_man.makeGCObj(new_number);
    }

    pub fn add(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 + val_2 },
                    .int => |val_2| Number{ .int = val_1 + @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) + val_2 },
                    .int => |val_2| Number{ .int = val_1 + val_2 },
                }
            },
        };
    }

    pub fn sub(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 - val_2 },
                    .int => |val_2| Number{ .int = val_1 - @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) - val_2 },
                    .int => |val_2| Number{ .int = val_1 - val_2 },
                }
            },
        };
    }

    pub fn mul(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 * val_2 },
                    .int => |val_2| Number{ .int = val_1 * @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) * val_2 },
                    .int => |val_2| Number{ .int = val_1 * val_2 },
                }
            },
        };
    }

    pub fn div(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 / val_2 },
                    .int => |val_2| Number{ .int = val_1 / @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) / val_2 },
                    .int => |val_2| if (val_1 % val_2 == 0)
                        val_1 / val_2
                    else
                        @as(f64, val_1) / @as(f64, val_2),
                }
            },
        };
    }
};

test "Number creating" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    const num = try Number.new(mem_man, i64, 123);
    _ = num;
    mem_man.deinit();
}

test "Str creating" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    const str = try Str.new(mem_man, "Строка");
    _ = str;
    mem_man.deinit();
}

test "Symbol creating" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    const sym = try mem_man.intern("symbol");
    _ = sym;
    mem_man.deinit();
}

test "ConsCell creating" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();
    const sym_1 = try mem_man.intern("symbol-1");
    const sym_2 = try mem_man.intern("symbol-2");

    const cell = try ConsCell.new(mem_man, sym_1, sym_2);
    _ = cell;
}
