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
            std.debug.print("GCObj deleted", .{});
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
            .symbol => |sym| {
                sym.markPropogate();
            },
            .cons_cell => |cell| {
                cell.markPropogate();
            },
            .str => |str| {
                str.markPropogate();
            },

            .number => {},
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
            .symbol => |sym| {
                sym.prepareToRemove(mem_man);
            },
            .cons_cell => |cell| {
                cell.prepareToRemove(mem_man);
            },
            .str => |str| {
                str.prepareToRemove(mem_man);
            },
            .number => {}, // Числа передаются по значению.
            .environment => |env| {
                env.prepareToRemove(mem_man);
            },
        }

        mem_man.allocator.destroy(gco);
    }
};

test "MemoryManager init and deinit" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    mem_man.deinit();
}

test "MemoryManager creating object" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    const num = try mem_man.makeGCObj(.{ .number = .{ .int = 5 } });
    std.debug.print("Объект аллоцирован\n", .{});
    _ = num;
    mem_man.deinit();
}
