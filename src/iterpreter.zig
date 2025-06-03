const std = @import("std");

const berlisp = @import("berlisp.zig");
const PropsData = @import("PropsData");

const eval_mod = berlisp.eval;
const reader = berlisp.reader;

const MemoryManager = berlisp.memory.MemoryManager;
const GCObj = berlisp.memory.GCObj;

// Зачем нам нужен объект интерпретатор?
// Для того, чтобы хранить в нём те объекты, которые бывают нужны во всё время работы программы.
// Например, таблицу Юникода, менеджер памяти.
//
// Полагаю, что Интерпретатор может понадобиться в функциях, которые написаны на Zig.

pub const Interpreter = struct {
    mem_man: *MemoryManager,
    pd: PropsData,
    env: *GCObj,

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        const mem_man = try MemoryManager.init(allocator);

        const pd = try PropsData.init(allocator);

        const env = try berlisp.env.Environment.new(mem_man, null);

        var interpreter = Interpreter{ .mem_man = mem_man, .pd = pd, .env = env };

        try interpreter.defGlobal("nil", mem_man.nil);

        return interpreter;
    }

    pub fn deinit(self: *Interpreter) void {
        self.pd.deinit(self.mem_man.allocator);
        self.mem_man.deinit();
    }

    pub fn eval(self: *Interpreter, code: *GCObj) !*GCObj {
        return eval_mod.eval(code, self, self.env);
    }

    pub fn defGlobal(self: *Interpreter, name: []const u8, value: *GCObj) !void {
        const sym = try self.mem_man.intern(name);
        _ = try self.env.obj.environment.def(sym, value, self.mem_man);
    }

    pub fn readEval(self: *Interpreter, src: []const u8) !*GCObj {
        return self.eval(try reader.readFromString(src, self));
    }
};
