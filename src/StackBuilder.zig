//! В этом файле реализован стековый билдер,
//! который позволяет создавать объекты.
//! Для хранения промежуточных результатов
//! используется стек.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const base = berlisp.base_types;
const assert = std.debug.assert;

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
        ManyValues,
    };

    const Stack = std.ArrayList(*GCObj);

    pub fn init(mem_man: *MemoryManager) !*StackBuilder {
        const builder = try mem_man.allocator.create(StackBuilder);
        builder.* = StackBuilder{
            .mem_man = mem_man,
            .stack = Stack.init(mem_man.allocator),
            .step = 0,
            .err = null,
        };

        return builder;
    }

    pub fn clear(self: *StackBuilder) void {
        self.stack.clearRetainingCapacity();
        self.err = null;
        self.step = 0;
    }

    pub fn deinit(self: *StackBuilder) void {
        self.stack.deinit();
        self.mem_man.allocator.destroy(self);
    }

    pub fn end(self: *StackBuilder) !*GCObj {
        if (self.stack.items.len > 1) return StackBuiledrError.ManyValues;
        if (self.err) |err| {
            return err;
        }
        if (self.pop()) |value| {
            self.clear();
            return value;
        } else {
            return StackBuiledrError.StackUnderflow;
        }
    }

    fn put(self: *StackBuilder, obj: anyerror!*GCObj) void {
        const object = obj catch |err| {
            self.err = err;
            return;
        };

        self.stack.append(object) catch |err| {
            self.err = err;
        };
    }

    fn pop(self: *StackBuilder) ?*GCObj {
        if (self.stack.pop()) |obj| {
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

    pub fn val(self: *StackBuilder, obj: *GCObj) *StackBuilder {
        if (self.stepForward() == false) return self;

        self.put(obj);

        return self;
    }

    pub fn symbol(self: *StackBuilder, name: []const u8) *StackBuilder {
        if (self.stepForward() == false) return self;

        self.put(self.mem_man.build.symbol(name));
        return self;
    }

    pub fn cons(self: *StackBuilder) *StackBuilder {
        if (self.stepForward() == false) return self;

        const car = self.pop();
        const cdr = self.pop();

        if (self.err) |_| return self;

        self.put(self.mem_man.build.cons(car.?, cdr.?)); // Строчкой выше
        // мы уже проверили, что всё нормально.
        // Если бы car или cdr был null, функция pop положила бы ошибку в билдер.

        return self;
    }
};

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

    const res = try builder.symbol("hello").end();

    switch (res.obj) {
        .symbol => |sym| {
            assert(std.mem.eql(u8, sym.name.obj.str.string, "hello"));
        },
        else => assert(false), // Результат - не символ!
    }
}

test "Builder.cons" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const builder = try StackBuilder.init(mem_man);
    defer builder.deinit();

    _ = try builder.symbol("nil").symbol("foo").cons().symbol("quote").cons().end();
}
