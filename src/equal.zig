const std = @import("std");

const berlisp = @import("berlisp.zig");
const mem = berlisp.memory;
const base_types = berlisp.base_types;

const Symbol = base_types.Symbol;

const GCObj = mem.GCObj;

// В данном файле реализовано сравнение базовых типов данных.
//
// Есть такие варианты сравнения:
// 1) Сравнение указателя на объекты.
// 2) Сравнение по значению.

pub fn eq(obj_1: *GCObj, obj_2: *GCObj) bool {
    return obj_1 == obj_2;
}

pub fn sameActiveTag(comptime T: type, obj_1: T, obj_2: T) bool {
    return std.mem.eql(u8, @tagName(obj_1), @tagName(obj_2));
}

const assert = std.debug.assert;

test "eq" {
    const allocator = std.testing.allocator;
    const mem_man = try mem.MemoryManager.init(allocator);
    defer mem_man.deinit();
    const sym_1 = try Symbol.new(mem_man, "sym");
    const sym_2 = try Symbol.new(mem_man, "sym");

    assert(!eq(sym_1, sym_2));
    assert(eq(sym_1, sym_1));
}

test "sameActiveTag" {
    const Un = union(enum) {
        a: i64,
        b: f64,
    };

    const un_1 = Un{ .a = 5 };
    const un_2 = Un{ .a = 8 };
    const un_3 = Un{ .b = 6.5 };

    assert(sameActiveTag(Un, un_1, un_2));
    assert(!sameActiveTag(Un, un_1, un_3));
}
