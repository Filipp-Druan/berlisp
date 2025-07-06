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
pub const BodyList = std.ArrayList(*GCObj);

pub const Function = union(enum) {
    lisp_fun: LispFun,
    zig_fun: ZigFun,

    pub fn newLispFunction(mem_man: *MemoryManager, args: ArgList, body: BodyList, env: *GCObj) !*GCObj {
        const lisp_fun = LispFun{ .arguments = args, .env = env, .body = body };
        return mem_man.makeGCObj(.{ .closure = .{ .lisp_fun = lisp_fun } });
    }

    pub fn call(self: *Function, args: *ArgList, interpreter: *Interpreter) !*GCObj {
        switch (self.*) {
            .lisp_fun => {
                return self.lisp_fun.call(args, interpreter);
            },
            .zig_fun => {
                return self.zig_fun.call(args, interpreter);
            },
        }
    }

    pub fn prepareToRemove(self: *Function, mem_man: *MemoryManager) void {
        switch (self.*) {
            .lisp_fun => {
                self.lisp_fun.prepareToRemove(mem_man);
            },
            .zig_fun => {},
        }
    }
};

const LispFun = struct {
    arguments: ArgList,
    env: *GCObj,
    body: BodyList,

    pub fn call(
        self: *const LispFun,
        args: *ArgList,
        interpreter: *Interpreter,
    ) !*GCObj {
        const env = try self.argsToEnv(args, interpreter.mem_man, self.env);

        var val = interpreter.mem_man.nil;
        for (self.body.items) |expression| {
            val = try eval(expression, interpreter, env);
        }

        return val;
    }

    fn argsToEnv(self: *const LispFun, args: *ArgList, mem_man: *MemoryManager, next_env: ?*GCObj) !*GCObj {
        var env = try mem_man.build.env(next_env);
        for (self.arguments.items, args.items) |formal_arg, fact_arg| {
            _ = try env.obj.environment.def(formal_arg, fact_arg, mem_man);
        }
        return env;
    }

    pub fn prepareToRemove(self: *LispFun, mem_man: *MemoryManager) void {
        _ = mem_man;
        self.arguments.deinit();
        self.body.deinit();
    }
};

const ZigFun = struct {
    fun: *fn (*ArgList, *Interpreter) anyerror!*GCObj, // Этот ?*GCObj - это окружение, в котором вызывается функция.

    pub fn call(self: *const ZigFun, args: *ArgList, interpreter: *Interpreter) anyerror!*GCObj {
        return self.fun(args, interpreter);
    }
};
