//! В этом файле реализована функция eval,
//! которая исполняет код на Berlisp.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const env = berlisp.env;
const mem = berlisp.memory;
const bt = berlisp.base_types;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;
const Environment = env.Environment;

const EvalError = error {
    CalledNotAFunction,
};

/// TODO
pub fn eval(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {
    switch (code.obj) {
        .number => return code.take(mem_man),
        .str => return code.take(mem_man),
        .symbol => current_env.takeValBySym(code, mem_man),
        .cons_cell => evalCall(code, mem_man, current_env),
    }
}

pub fn evalCall(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {
    const first = code.obj.cons_cell.car;
    switch (first.obj) {
        .symbol => {
            switch (first) {
                mem_man.special_symbols.quote_sym => {
                    const
                }
            }
        }
    }
}

pub fn getOperator(code: *GCObj, mem_man: *MemoryManager, current_env: *GCObj) !*GCObj {

}

// Мне нужно написать функцию, которая принимает код, и исполняет - eval.
