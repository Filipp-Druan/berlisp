//! В этом файле реализован простой билдер.
//! Он может создавать только один объект за раз.
//! Для удобства, я хочу хранить его в менеджере памяти.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const bt = berlisp.base_types;
const assert = std.debug.assert;

const MemoryManager = berlisp.memory.MemoryManager;
const GCObj = berlisp.memory.GCObj;

pub const Builder = struct {
    mem_man: *MemoryManager,

    pub fn number(self: *Builder, comptime T: type, num: T) !*GCObj {
        return bt.Number.new(self.mem_man, T, num);
    }

    pub fn cons(self: *Builder, car: *GCObj, cdr: *GCObj) !*GCObj {
        return bt.ConsCell.new(self.mem_man, car, cdr);
    }

    pub fn symbol(self: *Builder, name: []const u8) !*GCObj {
        return self.mem_man.intern(name);
    }

    pub fn str(self: *Builder, text: []const u8) !*GCObj {
        return bt.Str.new(self.mem_man, text);
    }
};

test "build Number" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    _ = try mem_man.build.number(i64, 5);
}

test "build Symbol" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    _ = try mem_man.build.symbol("zig");
}

test "build Str" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    _ = try mem_man.build.str("Hello!");
}

test "build ConsCell" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const sym_1 = try mem_man.build.symbol("sym-1");
    const sym_2 = try mem_man.build.symbol("sym-2");

    const cell = try mem_man.build.cons(sym_1, sym_2);

    assert(cell.obj.cons_cell.car == sym_1);
    assert(cell.obj.cons_cell.cdr == sym_2);
}
