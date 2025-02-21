const std = @import("std");
const berlisp = @import("berlisp.zig");

const LispObj = berlisp.base_types.LispObj;

/// Это менеджер памяти. Он управляет всем, что касается
/// памяти: выделением памяти и сборкой мусора.
///
/// TODO:
/// 1) Добавить полноценную сборку мусора.
///    Я пока не знаю как это сделать, так как ещё не готова
///    большая часть интерпретатора.
/// 2) Добавить гибкую систему управления сборкой мусора,
///    чтобы можно было включать и отключать сборщик,
///    запускать его принудительно, пока есть время.
/// 3) Написать правила, по которым сборщик мусора запускается.
pub const MemoryManager = struct {
    last_allocated_object: ?*GCObj,
    allocator: std.mem.Allocator,

    /// Создаёт новый менеджер памяти,
    /// у которого новый, пустой список всех выделенных объектов.
    pub fn init(allocator: std.mem.Allocator) !*MemoryManager {
        var mem_man = try allocator.create(MemoryManager);

        mem_man.last_allocated_object = null;
        mem_man.allocator = allocator;

        return mem_man;
    }

    pub fn deinit(self: *MemoryManager) void {
        self.deleteAll();
        self.allocator.destroy(self);
    }

    /// Создаёт в куче новый GCObj из LispObj, добавляет
    /// его в список объектов, созданных данным менеджером памяти.
    pub fn makeGCObj(self: *MemoryManager, obj: LispObj) !*GCObj {
        var mem_man = self;
        var gco = try self.allocator.create(GCObj);
        gco.obj = obj;
        gco.last_obj = mem_man.last_allocated_object;
        mem_man.last_allocated_object = gco;

        return gco;
    }

    /// Помечает все объекты, созданные данным менеджером
    /// памяти как недостижимые.
    pub fn markAllNotReachable(self: MemoryManager) void {
        var current_obj = self.last_allocated_object;
        while (current_obj) |obj| {
            obj.mark_not_reachable();
            current_obj = obj.last_obj;
        }
    }

    /// Этот метод удаляет все объекты, созданные при помощи данного
    /// менеджера памяти.
    pub fn deleteAll(self: *MemoryManager) void {
        var last_gco = self.last_allocated_object;
        while (last_gco) |obj| {
            last_gco = obj.last_obj;
            obj.delete(self);
        }
    }
};

pub const GCObj = struct {
    last_obj: ?*GCObj,
    is_reachable: bool,
    obj: LispObj,

    /// Помечает объект достижимым, рекурсивно
    /// помечает все объекты, на которые ссылается данный.
    pub fn recursivelyMarkReachable(obj: *GCObj) void {
        obj.is_reachable = true;
        switch (obj.obj) {
            .number => {},
            inline else => |val| {
                val.markPropogate();
            },
        }
    }

    /// Помечает объект, как недостижимый.
    pub fn markNotReachable(self: *GCObj) void {
        self.is_reachable = false;
    }

    /// Эта функция удаляет GCObj.
    /// При этом, она не занимается поддержанием списка всех
    /// объектов. Если использовать эту функцию неправильно,
    /// может оборваться список всех объектов.
    pub fn delete(gco: *GCObj, mem_man: *MemoryManager) void {
        switch (gco.obj) {
            .number => {}, // Числа передаются по значению.
            inline else => |val| {
                val.prepareToRemove(mem_man);
            },
        }

        mem_man.allocator.destroy(gco);
    }

    /// Этот метод предназначен для того, чтобы получать объект,
    /// коогда мы передаём его куда-то.
    /// Числа передаются по значени, всё остальное - по ссылке.
    pub fn take(gco: *GCObj, mem_man: *MemoryManager) !*GCObj {
        switch (gco.obj) {
            .number => |num| return try num.copyGCObj(mem_man),
            inline else => return gco,
        }
    }
};

const bt = berlisp.base_types;
const assert = std.debug.assert;

test "MemoryManager init and deinit" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    mem_man.deinit();
}

test "MemoryManager creating object" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    _ = try bt.Number.new(mem_man, i64, 55);

    mem_man.deinit();
}

test "take Number" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const initial_value = 5;
    const new_value = 123;

    const num_1 = try bt.Number.new(mem_man, i64, initial_value);
    const num_2 = try num_1.take(mem_man);

    assert(num_1 != num_2);

    num_1.obj.number.int = new_value;

    assert(num_2.obj.number.int == initial_value);
}
