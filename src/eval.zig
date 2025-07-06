//! В этом файле реализована функция eval,
//! которая исполняет код на Berlisp.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const env = berlisp.env;
const mem = berlisp.memory;
const bt = berlisp.base_types;
const reader = berlisp.reader;

const functions = berlisp.functions;

const assert = std.debug.assert;
const print = std.debug.print;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;
const Environment = env.Environment;
const StackBuilder = berlisp.stack_builder.StackBuilder;
const Interpreter = berlisp.interpreter.Interpreter;

const ListIter = bt.ConsCell.Iter;

const EvalError = error{
    CalledNotAFunction,
    CallCodeNotList,
    CallNotAFunction,
    NotImplemented,
};

/// TODO
pub fn eval(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) anyerror!*GCObj {
    switch (code.obj) {
        .nil => return code, // TODO
        .number => return code.take(interpreter.mem_man),
        .str => return code.take(interpreter.mem_man),
        .symbol => return current_env.obj.environment.takeValBySym(code, interpreter.mem_man),
        .cons_cell => return evalCall(code, interpreter, current_env),
        else => return EvalError.NotImplemented,
    }
}

pub fn evalCall(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) !*GCObj {
    if (isSpecialForm(code, interpreter.mem_man)) {
        return evalSpecial(code, interpreter, current_env);
    } else {
        return evalFunCall(code, interpreter, current_env);
    }
}

fn evalSpecial(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) !*GCObj {
    const first = code.obj.cons_cell.first();

    if (first == interpreter.mem_man.spec.quote_sym) {
        return evalQuote(code, interpreter);
    } else if (first == interpreter.mem_man.spec.if_sym) {
        return evalIf(code, interpreter, current_env);
    } else if (first == interpreter.mem_man.spec.fn_sym) {
        return evalFn(code, interpreter, current_env);
    } else {
        return EvalError.NotImplemented;
    }
}

fn evalFunCall(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) !*GCObj {
    var iter = berlisp.base_types.ConsCell.Iter.init(code);
    const operator = iter.next().?;

    var args = berlisp.functions.ArgList.init(interpreter.mem_man.allocator);

    while (iter.next()) |expr| {
        const param = try eval(expr, interpreter, current_env);
        try args.append(param);
    }
    const closure = try eval(operator, interpreter, current_env);

    if (closure.obj != .closure) return EvalError.CalledNotAFunction;

    return closure.obj.closure.call(&args, interpreter);
}

pub fn evalQuote(code: *GCObj, interpreter: *Interpreter) !*GCObj {
    return (try code.obj.cons_cell.second()).take(interpreter.mem_man);
}

pub fn evalIf(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) !*GCObj {
    const condition = try eval(try code.obj.cons_cell.second(), interpreter, current_env);
    const then_expr = try code.obj.cons_cell.third();
    const else_expr = try code.obj.cons_cell.fourth();

    if (condition.obj != .nil) {
        return eval(then_expr, interpreter, current_env);
    } else {
        return eval(else_expr, interpreter, current_env);
    }
}

// Исполняет форму fn которая создаёт функцию.
// (fn (arg1 ...) body ...)
pub fn evalFn(code: *GCObj, interpreter: *Interpreter, current_env: *GCObj) !*GCObj {
    var iter = ListIter.init(code);
    assert(iter.next() == interpreter.mem_man.spec.fn_sym); // Пропускаем имя специальной формы.

    var args: *GCObj = undefined;

    if (iter.next()) |args_list| {
        args = args_list;
    }

    var body_iter = iter;

    var args_iter = ListIter.init(args);
    var arg_list = functions.ArgList.init(interpreter.mem_man.allocator);

    while (args_iter.next()) |param| {
        if (param.obj != .symbol) return FnError.ArgumentIsntSymbol;

        try arg_list.append(param);
    }

    var body_list = functions.ArgList.init(interpreter.mem_man.allocator);

    while (body_iter.next()) |param| {
        try body_list.append(param);
    }

    return functions.Function.newLispFunction(interpreter.mem_man, arg_list, body_list, current_env);
}

pub const FnError = error{
    ListToShort,
    ArgumentIsntSymbol,
};

pub fn getOperator(code: *const GCObj) !*GCObj {
    if (code.obj == .list) {} else {
        return EvalError.CallCodeNotList;
    }
}

fn isSpecialForm(code: *const GCObj, mem_man: *const MemoryManager) bool {
    if (code.obj != .cons_cell) return false;

    const first = code.obj.cons_cell.first();

    return first.obj == .symbol and (first == mem_man.spec.quote_sym or
        first == mem_man.spec.def_sym or
        first == mem_man.spec.fn_sym or
        first == mem_man.spec.if_sym or
        first == mem_man.spec.let_sym);
}

// Мне нужно написать функцию, которая принимает код, и исполняет - eval.
// У нас есть несколько типов данный, которые eval принимает как код.
// Некоторые: числа, строки вычисляются сами в себя.
// Если мы получили символ, нам нужно обратиться в окружение, и получить значение,
// которое соответствует символу.
//
// Самое сложно получается тогда, когда приходится работать со списками.
// Проблема в том, что получать элементы списка очень неудообно.
//
// Кроме того, нам нужно проверять и длину списка. Решение:
// Написать специальные функции для этого.
//
// Дальше, какая у нас прооблема есть ещё?
// Не очень удобно сравнивать символы.
// Но я точно понял, что нужны отдельные процедуры для обработки каждой специальной формы.

// Другой важный момент - как организовать передачу параметров в функцию?
// Тут есть несколько важных моментов:
// 1) Я хотел бы как можно скорее перейти от списка из ячеек к ArrayList.
// Его проще передавать, проще определять его длину.
//
// Когда мне вычислять всё это? Когда мне превращать ячейки в массив?
// В файле functions.zig функции принимают уже сформированный список аргументов.
// Думаю, я буду формировать этот список в одной из функций eval.
//
// При этом, нужно иметь доступ к списку аргументов функции, чтобы проверить, что всё нормально.
//
// Тут есть ещё идея: заранее откомпилировать всё это из списков в разветвлённые структуры данных.
// Но это уже следующий шаг.
//
// А сегодня мне вообще предложили на первых парах выкинуть списки из cons ячеек!
// Так и сделаю!

test "eval quote" {
    var interp = try Interpreter.init(std.testing.allocator);
    defer interp.deinit();

    var interpreter = &interp;

    const expr = try reader.readFromString("(quote hello)", interpreter);

    const res = try eval(expr, interpreter, interpreter.env);

    assert(res == try interpreter.mem_man.intern("hello"));
}

test "eval if" {
    var interp = try Interpreter.init(std.testing.allocator);
    defer interp.deinit();

    var interpreter = &interp;

    const expr_1 = try reader.readFromString("(if nil (quote world) (quote hello))", interpreter);

    const res_1 = try eval(expr_1, interpreter, interpreter.env);

    assert(res_1 == try interpreter.mem_man.intern("hello"));

    const expr_2 = try reader.readFromString("(if (quote true) (quote world) (quote hello))", interpreter);

    const res_2 = try eval(expr_2, interpreter, interpreter.env);

    assert(res_2 == try interpreter.mem_man.intern("world"));
}
