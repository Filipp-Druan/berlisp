const std = @import("std");

const PropsData = @import("PropsData");

const berlisp = @import("berlisp.zig");
const reader = berlisp.reader;
const readFromString = reader.readFromString;

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

    const quit_sym = try interpreter.mem_man.intern("quit");

    std.debug.print("Berlisp 0.1.0\n", .{});

    while (true) {
        std.debug.print("> ", .{});
        const line_len = try stdin.read(&buffer);
        const expr = readFromString(
            buffer[0..line_len],
            &interpreter,
        ) catch {
            std.debug.print("Ошибка чтения\n", .{});
            continue;
        };

        if (expr == quit_sym) {
            std.debug.print("Всего хорошего!\n", .{});
            break;
        }

        const res = interpreter.eval(expr) catch |err| switch (err) {
            error.NotImplemented => {
                std.debug.print("Не реализовано\n", .{});
                continue;
            },
            error.VariableNotDefined => {
                std.debug.print("Переменная не определена\n", .{});
                continue;
            },
            else => return err,
        };

        berlisp.printer.print(res);
        std.debug.print("\n", .{});
    }
}

test "main test" {
    std.testing.refAllDecls(berlisp.lexer);
    std.testing.refAllDecls(berlisp.parser);
}
