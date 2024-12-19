const std = @import("std");
const berlisp = @import("berlisp.zig");

const GCObj = berlisp.memory.GCObj;
const MemoryManager = berlisp.memory.MemoryManager;
const Environment = berlisp.env.Environment;

pub const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
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

    pub fn markPropogate(self: ConsCell) void {
        self.car.recursivelyMarkReachable();
        self.cdr.recursivelyMarkReachable();
    }

    pub fn prepareToRemove(self: ConsCell, mem_man: *MemoryManager) void {
        _ = self;
        _ = mem_man;
    }
};

pub const Symbol = struct {
    name: *GCObj, // Str

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
        const str_mem = try mem_man.allocator.alloc(u8, str.len);
        std.mem.copyForwards(u8, str_mem, str);

        return try mem_man.makeGCObj(.{ .str = .{ .string = str_mem } });
    }

    pub fn markPropogate(self: Str) void {
        _ = self;
    }

    pub fn prepareToRemove(self: Str, mem_man: *MemoryManager) void {
        mem_man.allocator.free(self.string);
    }
};

/// Число. Над ним можно производить арифметические операции.
/// Может быть либо с плавающей точкой, либо целым.
/// Если одно число было с плавающей точкой, то результат операции тоже
/// будет таким.
///
/// Числа передаются не по ссылке, а по значению.
pub const Number = union(enum) {
    int: i64,
    double: f64,

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
