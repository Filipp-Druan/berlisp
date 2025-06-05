const std = @import("std");

const PropsData = @import("PropsData");

const berlisp = @import("berlisp.zig");
const read_module = berlisp.read_module;

const assert = std.debug.assert;

const GCObj = berlisp.memory.GCObj;
const Interpreter = berlisp.interpreter.Interpreter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var interpreter = try Interpreter.init(allocator);
    defer interpreter.deinit();

    var stdin = std.io.getStdIn().reader();
    var buffer: [4096]u8 = undefined;

    while (true) {
        const line_len = try stdin.read(&buffer);
        const expr = try interpreter.readEval(buffer[0..line_len]);
        berlisp.printer.print(expr);
        std.debug.print("\n", .{});
    }
}

test "main test" {
    std.testing.refAllDecls(berlisp.lexer);
    std.testing.refAllDecls(berlisp.parser);
}
