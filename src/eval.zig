//! В этом файле реализована функция eval,
//! которая исполняет код на Berlisp.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const env = berlisp.env;
const mem = berlisp.memory;
const bt = berlisp.base_types;

const assert = std.debug.assert;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;
const Environment = env.Environment;
const StackBuilder = berlisp.stack_builder.StackBuilder;

const EvalError = error{
    CalledNotAFunction,
    CallCodeNotList,
    NotImplemented,
};

/// TODO
pub fn eval(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) anyerror!*GCObj {
    switch (code.obj) {
        .nil => return code, // TODO
        .number => return code.take(mem_man),
        .str => return code.take(mem_man),
        .symbol => return current_env.obj.environment.takeValBySym(code, mem_man),
        .cons_cell => return evalCall(code, mem_man, current_env),
        else => return EvalError.NotImplemented,
    }
}

pub fn evalCall(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {
    if (isSpecialForm(code, mem_man)) {
        return evalSpecial(code, mem_man, current_env);
    } else {
        return EvalError.NotImplemented;
    }
}

fn evalSpecial(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {
    const first = code.obj.cons_cell.first();

    if (first == mem_man.spec.quote_sym) {
        return evalQuote(code, mem_man);
    } else if (first == mem_man.spec.if_sym) {
        return evalIf(code, mem_man, current_env);
    } else {
        return EvalError.NotImplemented;
    }
}

pub fn evalQuote(code: *GCObj, mem_man: *MemoryManager) !*GCObj {
    return (try code.obj.cons_cell.second()).take(mem_man);
}

pub fn evalIf(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {
    const condition = try eval(try code.obj.cons_cell.second(), mem_man, current_env);
    const then_expr = try code.obj.cons_cell.third();
    const else_expr = try code.obj.cons_cell.fourth();

    if (condition.obj != .nil) {
        return eval(then_expr, mem_man, current_env);
    } else {
        return eval(else_expr, mem_man, current_env);
    }
}

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
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();
    var sb = try StackBuilder.init(mem_man);
    defer sb.deinit();
    const global_env = try mem_man.build.env(null);

    const expr = try sb.nil().sym("hello").cons().sym("quote").cons().end();

    const res = try eval(expr, mem_man, global_env);

    assert(res == try mem_man.intern("hello"));
}

test "eval if" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();
    var sb = try StackBuilder.init(mem_man);
    defer sb.deinit();
    const global_env = try mem_man.build.env(null);

    const expr_1 = try sb.nil()
        .sym("hello").cons()
        .sym("world").cons()
        .sym("true").cons()
        .sym("if").cons()
        .end();

    const res_1 = try eval(expr_1, mem_man, global_env);

    assert(res_1 == try mem_man.intern("world"));

    const expr_2 = try sb.nil()
        .sym("hello").cons()
        .sym("world").cons()
        .sym("true").cons()
        .sym("if").cons()
        .nil().cons()
        .end();

    const res_2 = try eval(expr_2, mem_man, global_env);

    assert(res_2 == try mem_man.intern("hello"));
}
