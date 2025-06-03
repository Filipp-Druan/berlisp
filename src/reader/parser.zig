const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const exre = @import("exre");

const berlisp = @import("../berlisp.zig");

const base_types = berlisp.base_types;
const mem = berlisp.memory;

const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

const Interpreter = berlisp.interpreter.Interpreter;
const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;

const Lexer = berlisp.lexer.Lexer;

// Так, мне нужно спроектировать парсер. Он должен уметь считывать для начала из строки.
// Он за один раз считывает только одно выражение.
// Работает как итератор.
// Входные данные - строка.
// Выходные данные - !*GCObj
//

pub const Parser = struct {
    lexer: Lexer,
    mem_man: *MemoryManager,

    pub fn init(str: []const u8, mem_man: *MemoryManager, pd: PropsData) Parser {
        return .{
            .lexer = Lexer.initFromString(str, pd),
            .mem_man = mem_man,
        };
    }

    pub fn next(self: *Parser) !*GCObj {
        return self.readNext();
    }

    pub fn readNext(self: *Parser) !*GCObj {
        switch (try self.readSymbol()) {
            .obj => |obj| return obj,
            .fail => {},
        }

        switch (try self.readList()) {
            .obj => |obj| return obj,
            .fail => {},
        }

        return ParsingError.CantParse;
    }

    pub fn readSymbol(self: *Parser) !Res {
        var lexer = self.lexer;

        const tok = try lexer.next();

        if (tok.tag == .Symbol) {
            var reader = self;
            reader.lexer = lexer;

            return Res.success(try self.mem_man.intern(tok.str));
        } else {
            return Res.fail;
        }
    }
    /// Первый токен обязательно должен быть левой скобкой. Иначе это не список
    pub fn readList(self: *Parser) anyerror!Res {
        var reader = self.*; // Копируем ридер, чтобы вносить изменения в копию. Если всё считается
        // Можно будет заменить оригинал изменеённой копией.
        const tok = try reader.lexer.next(); // Пробуем посмотреть, какой символ следующий.

        // std.debug.print("\nНачинаем считывать список\n", .{});

        if (tok.tag != .OpenBracket) { // Этот символ обязан быть открывающей скобкой.
            return Res.fail;
        }
        // std.debug.print("Первая скобка считана!\n", .{});

        var acc = base_types.ConsCell.ListAccum.init(self.mem_man);

        while (true) {
            // std.debug.print("Начинаем считывать элементы!\n", .{});
            const token = try reader.lexer.peek();
            // std.debug.print("Следующий тег: {s}", .{@tagName(token.tag)});

            switch (token.tag) {
                .CloseBracket => {
                    _ = try reader.lexer.next();
                    self.* = reader;
                    return Res.success(acc.get());
                },
                .Eof => {
                    return ParsingError.Eof;
                },
                else => {
                    const obj = try reader.readNext();

                    try acc.addToEnd(obj);

                    continue;
                },
            }
        }
    }
};

const Res = union(enum) {
    obj: *GCObj,
    fail,

    pub fn success(obj: *GCObj) Res {
        return .{ .obj = obj };
    }
};

const ParsingError = error{
    CantParse,
    Eof,
};

test "Reader.next" {
    var interpreter = try Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    var reader = Parser.init("sym", interpreter.mem_man, interpreter.pd);

    const sym = try reader.next();
    const sym_ref = interpreter.mem_man.intern("sym");

    try std.testing.expectEqual(sym, sym_ref);
}

test "Read list" {
    var interpreter = try Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    var reader = Parser.init("(quote sym)", interpreter.mem_man, interpreter.pd);

    const code = try reader.next();

    assert(code.obj == .cons_cell);

    const res = try interpreter.eval(code);

    const ref = try interpreter.mem_man.intern("sym");
    assert(res == ref);
}

test "Read nested list" {
    var interpreter = try Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    var reader = Parser.init("(hello (quote sym))", interpreter.mem_man, interpreter.pd);

    const code = try reader.next();

    const len = try code.obj.cons_cell.len();

    assert(len == 2);
}

test "Read nested list 2" {
    var interpreter = try Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    var reader = Parser.init("(hello (quote sym) (quote sym))", interpreter.mem_man, interpreter.pd);

    const code = try reader.next();

    const len = try code.obj.cons_cell.len();
    std.debug.print("\nlen = {}\n", .{len});
    berlisp.printer.print(code);

    assert(len == 3);
}
