const std = @import("std");

const PropsData = @import("PropsData");

const berlisp = @import("berlisp.zig");
const read_module = berlisp.read_module;

const assert = std.debug.assert;

const Interpreter = berlisp.interpreter.Interpreter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var interpreter = try Interpreter.init(allocator);
    defer interpreter.deinit();

    _ = try interpreter.readEval("(foo (quote sym) (quote sym))");
}

test "main test" {
    std.testing.refAllDecls(berlisp.lexer);
    std.testing.refAllDecls(berlisp.parser);
}
