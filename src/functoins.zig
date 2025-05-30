const std = @import("std");
const berlisp = @import("berlisp.zig");

const GCObj = berlisp.memory.GCObj;
const bt = berlisp.base_types;
const Builder = berlisp.builder.Builder;
const MemoryManager = berlisp.memory.MemoryManager;
const Interpreter = berlisp.interpreter.Interpreter;
const Environment = berlisp.env.Environment;
const eval_module = berlisp.eval;

const eval = eval_module.eval;

pub const ArgList = std.ArrayList(*GCObj);

pub const Function = union(enum) {
    lisp_fun: LispFun,
    zig_fun: ZigFun,

    pub fn call(self: *Function, args: *ArgList, interpreter: *Interpreter, env: ?*GCObj) !*GCObj {
        switch (self) {
            .lisp_fun => |fun| {
                return fun.call(args, interpreter, env);
            },
            .zig_fun => |fun| {
                return fun.call(args, interpreter, env);
            },
        }
    }
};

const LispFun = struct {
    arguments: std.ArrayList(*GCObj), // Тут всегда символы!!!
    body: std.ArrayList(*GCObj),

    pub fn call(self: *LispFun, args: *ArgList, interpreter: *Interpreter, next_env: ?*GCObj) !*GCObj {
        const env = self.argsToEnv(args, interpreter.mem_man, next_env);

        var val = undefined;
        for (self.body.items) |expression| {
            val = try eval(expression, interpreter, env);
        }

        return val;
    }

    fn argsToEnv(self: *LispFun, args: *ArgList, mem_man: *MemoryManager, next_env: ?*Environment) !*Environment {
        var env = try mem_man.build.env(next_env);
        for (self.arguments.items, args.items) |formal_arg, fact_arg| {
            try env.obj.environment.def(formal_arg, fact_arg, mem_man);
        }
        return env;
    }
};

const ZigFun = struct {
    fun: fn (*ArgList, *Interpreter, ?*GCObj) anyerror!*GCObj, // Этот ?*GCObj - это окружение, в котором вызывается функция.
};
