//! В этом файле реализованы билдеры,
//! которые позволяют создавать объекты.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const base = berlisp.base_types;

const MemoryManager = berlisp.memory.MemoryManager;
const GCObj = berlisp.memory.GCObj;

/// У объекта StackBuilder реализованы методы для
/// создания объектов Berlisp. При этом, они
/// кладутся на стек. Если при создании объекта
/// возникнет ошибка, то она сохраняется, а всякие вычисления
/// прерываются, и Билдер просто передаётся сквозь методы.
const StackBuilder = struct {
    mem_man: *MemoryManager,
    stack: Stack,
    step: usize, // Эта переменная считает шаги. Если на каком-то шаге случается
    // ошибка, они перестают считаться.
    err: ?anyerror,

    const Stack = std.ArrayList(*GCObj);

    pub fn init(mem_man: *MemoryManager) !*StackBuilder {
        const builder = try mem_man.allocator.create(StackBuilder);
        builder.* = StackBuilder{
            .mem_man = mem_man,
            .stack = Stack.init(mem_man.allocator),
            .step = 1,
            .err = null,
        };

        return builder;
    }

    pub fn deinit(self: *StackBuilder) void {
        self.stack.deinit();
        self.mem_man.allocator.destroy(self);
    }

    pub fn get(self: StackBuilder) ?*GCObj {
        return self.stack.popOrNull();
    }

    pub fn sym(self: *StackBuilder, name: []const u8) *StackBuilder {
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

    pub fn cons(self: *StackBuilder) *StackBuilder {
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

    const builder = try StackBuilder.init(mem_man);
    builder.deinit();

    mem_man.deinit();
}

test "Builder.sym" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const builder = try StackBuilder.init(mem_man);
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
