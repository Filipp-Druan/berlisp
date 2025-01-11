//! В этом файле реализован билдер.
//! Он позволяет при помощи fluent интерфейса
//! создавать объекты Берлиспа. Всё это похоже
//! на стековую машину Forth.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const base = berlisp.base_types;

const MemoryManager = berlisp.memory.MemoryManager;
const GCObj = berlisp.memory.GCObj;

const Builder = struct {
    mem_man: *MemoryManager,
    stack: Stack,
    step: usize, // Эта переменная считает шаги. Если на каком-то шаге случается
    // ошибка, они перестают считаться.
    is_error: bool,

    const Stack = std.ArrayList(*GCObj);

    pub fn init(mem_man: *MemoryManager) !*Builder {
        const builder = try mem_man.allocator.create(Builder);
        builder.* = Builder{
            .mem_man = mem_man,
            .stack = Stack.init(mem_man.allocator),
            .step = 1,
            .is_error = bool,
        };

        return builder;
    }

    pub fn deinit(self: *Builder) void {
        self.stack.deinit();
        self.mem_man.allocator.destroy(self);
    }

    pub fn get(self: Builder) ?*GCObj {
        return self.stack.popOrNull();
    }

    /// TODO в этом коде нет обработки ошибок.
    pub fn sym(self: *Builder, name: []const u8) *Builder {
        if (self.is_error) {
            return self;
        }

        const sym = base.Symbol.new(self.mem_man, name);
        self.stack.append(sym);
        return self;
    }
};

test "Stack.init" {
    var mem_man = try MemoryManager.init(std.testing.allocator);

    const builder = try Builder.init(mem_man);
    builder.deinit();

    mem_man.deinit();
}
