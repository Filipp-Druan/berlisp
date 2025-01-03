//! В этом файле реализована функция eval,
//! которая исполняет код на Berlisp.

const std = @import("std");
const berlisp = @import("berlisp.zig");
const env = berlisp.env;
const mem = berlisp.memory;
const bt = berlisp.base_types;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;
const Enviroment = env.Environment;

/// TODO
pub fn eval(mem_man: MemoryManager, code: *GCObj, env: Enviroment) !*GCObj {
    switch (code.obj) {}
}
