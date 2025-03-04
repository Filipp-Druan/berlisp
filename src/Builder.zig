//! В этом файле реализован простой билдер.
//! Он может создавать только один объект за раз.
//! Для удобства, я хочу хранить его в менеджере памяти.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const bt = berlisp.base_types;
const assert = std.debug.assert;

const MemoryManager = berlisp.memory.MemoryManager;
const GCObj = berlisp.memory.GCObj;
const Environment = berlisp.env.Environment;

/// АХТУНГ! Эта структура используется как пространство имён
/// для конструкторов символов.
/// Она ВСЕГДА должна использоваться внутри менеджера
/// памяти, как одно из его полей.
/// НИКОГДА нельзя его копировать.
/// НИКОГДА нельзя создавать его вне менеджера!
pub const Builder = struct {
    fn getMan(self: *Builder) *MemoryManager {
        return @alignCast(@fieldParentPtr("build", self)); // АХТУНГ! Я не знаю тонкоостей того, как это работает!
        // Нужно изучить выравнивание.
    }

    pub fn number(self: *Builder, comptime T: type, num: T) !*GCObj {
        return bt.Number.new(self.getMan(), T, num);
    }

    pub fn nil(self: *Builder) !*GCObj {
        return bt.Nil.new(self.getMan());
    }

    pub fn cons(self: *Builder, car: *GCObj, cdr: *GCObj) !*GCObj {
        return bt.ConsCell.new(self.getMan(), car, cdr);
    }

    pub fn symbol(self: *Builder, name: []const u8) !*GCObj {
        return self.getMan().intern(name);
    }

    pub fn str(self: *Builder, text: []const u8) !*GCObj {
        return bt.Str.new(self.getMan(), text);
    }

    pub fn env(self: *Builder, next: ?*GCObj) !*GCObj {
        return Environment.new(self.getMan(), next);
    }
};

test "build Number" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    _ = try mem_man.build.number(i64, 5);
}

test "builb Nil" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    _ = try mem_man.build.nil();
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

test "build Environment" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const env_1 = try mem_man.build.env(null);
    _ = try mem_man.build.env(env_1);
}
