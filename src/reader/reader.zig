const std = @import("std");
const unicode = std.unicode;

const berlisp = @import("../berlisp.zig");

const base_types = berlisp.base_types;
const mem = berlisp.memory;

const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

const Interpreter = berlisp.interpreter.Interpreter;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;

const Lexer = berlisp.lexer.Lexer;
const Parser = berlisp.parser.Parser;

pub fn readFromString(str: []const u8, interpreter: *Interpreter) !*GCObj {
    var parser = Parser.init(str, interpreter.mem_man, interpreter.pd);
    return parser.next();
}
