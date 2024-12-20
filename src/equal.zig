const std = @import("std");

const berlisp = @import("berlisp.zig");
const mem = berlisp.memory;
const base_types = berlisp.base_types;

const GCObj = mem.GCObj;

// В данном файле реализовано сравнение базовых типов данных.
//
// Есть такие варианты сравнения:
// 1) Сравнение указателя на объекты.

pub fn eq(obj_1: *GCObj, obj_2: *GCObj) bool {
    return obj_1 == obj_2;
}
