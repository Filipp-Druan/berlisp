//! В этом файле реализован стековый билдер,
//! который позволяет создавать объекты.
//! Для хранения промежуточных результатов
//! используется стек.

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

    const StackBuiledrError = error{
        StackUnderflow,
    };

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

    fn put(self: *StackBuilder, obj: anyerror!*GCObj) *StackBuilder {
        const object = obj catch |err| {
            self.err = err;
            return self;
        };

        self.stack.append(object);
    }

    pub fn pop(self: *StackBuilder) ?*GCObj {
        if (self.stack.popOrNull()) |obj| {
            return obj;
        } else {
            self.err = StackBuiledrError.StackUnderflow;
            return null;
        }
    }

    fn stepForward(self: *StackBuilder) bool {
        if (self.err == null) {
            self.step += 1;
            return true;
        } else {
            return false;
        }
    }

    pub fn symbol(self: *StackBuilder, name: []const u8) *StackBuilder {
        if (!self.stepForward()) return self;

        self.put(self.mem_man.build.symbol(name));
        return self;
    }

    pub fn cons(self: *StackBuilder) *StackBuilder {
        if (!self.stepForward()) return self;

        const car = self.pop();
        const cdr = self.pop();

        if (self.err) return self;

        self.put(self.mem_man.build.cons(car, cdr));

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
