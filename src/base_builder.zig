//! В этом файле реализован билдер.
//! Он позволяет при помощи fluent интерфейса
//! создавать объекты Берлиспа. Всё это похоже
//! на стековую машину Forth.
//!
//! У объекта Builder реализованы методы для
//! создания объектов Berlisp. При этом, они
//! кладутся на стек. Если при создании объекта
//! возникнет ошибка, то она сохраняется, а всякие вычисления
//! прерываются, и Билдер просто передаётся сквозь методы.

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
    err: ?anyerror,

    const Stack = std.ArrayList(*GCObj);

    pub fn init(mem_man: *MemoryManager) !*Builder {
        const builder = try mem_man.allocator.create(Builder);
        builder.* = Builder{
            .mem_man = mem_man,
            .stack = Stack.init(mem_man.allocator),
            .step = 1,
            .err = null,
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

    pub fn sym(self: *Builder, name: []const u8) *Builder {
        if (self.err == null) {
            return self;
        }

        const symbol = base.Symbol.new(self.mem_man, name) catch |err| {
            self.err = err;
            return self;
        };

        self.stack.append(symbol);

        self.step += 1;
        return self;
    }

    pub fn cons(self: *Builder) *Builder {
        if (self.is_error == null) {
            return self;
        }

        if (self.stack.items.len < 2) {
            self.is_error = true;
            return self;
        }

        const arg_2 = self.stack.pop();
        const arg_1 = self.stack.pop();

        const cell = base.ConsCell(self.mem_man, arg_1, arg_2) catch |err| {
            self.err = err;
            return self;
        };

        self.stack.append(cell);
        self.step += 1;

        return self;
    }
};

const assert = std.debug.assert();
test "Builder.init" {
    var mem_man = try MemoryManager.init(std.testing.allocator);

    const builder = try Builder.init(mem_man);
    builder.deinit();

    mem_man.deinit();
}

test "Builder.sym" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const builder = try Builder.init(mem_man);
    defer builder.deinit();

    builder.sym("hello");

    const res = builder.get();
    assert(res != null);
    assert(switch (res.?.obj) {
        .symbol => true,
        else => false,
    });
    assert(std.mem.eql(u8, res.?.obj.str.string, "hello"));
}
