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

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;

const Lexer = berlisp.lexer.Lexer;

// Так, мне нужно спроектировать парсер. Он должен уметь считывать для начала из строки.
// Он за один раз считывает только одно выражение.
// Работает как итератор.
// Входные данные - строка.
// Выходные данные - !*GCObj
//

pub const Reader = struct {
    lexer: Lexer,
    mem_man: *MemoryManager,

    pub fn init(str: []const u8, mem_man: *MemoryManager, pd: PropsData) Reader {
        return .{
            .lexer = Lexer.initFromString(str, pd),
            .mem_man = mem_man,
        };
    }

    pub fn next(self: *Reader) !*GCObj {
        return self.readNext();
    }

    pub fn readNext(self: *Reader) !*GCObj {
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

    pub fn readSymbol(self: *Reader) !Res {
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
    pub fn readList(self: *Reader) anyerror!Res {
        var reader = self.*;
        const tok = try reader.lexer.next();

        std.debug.print("\nНачинаем считывать список\n", .{});

        if (tok.tag != .OpenBracket) {
            return Res.fail;
        }
        std.debug.print("Первая скобка считана!\n", .{});

        var acc = base_types.ConsCell.ListAccum.init(self.mem_man);

        while (true) {
            std.debug.print("Начинаем считывать элементы!\n", .{});
            const token = try reader.lexer.peek();
            std.debug.print("Следующий тег: {s}", .{@tagName(token.tag)});

            switch (token.tag) {
                .CloseBracket => {
                    self.* = reader;
                    return Res.success(acc.get());
                },
                .Eof => {
                    return ParsingError.Eof;
                },
                else => {
                    const obj = try reader.next();

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
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    var reader = Reader.init("sym", mem_man, pd);

    const sym = try reader.next();
    const sym_ref = mem_man.intern("sym");

    try std.testing.expectEqual(sym, sym_ref);
}

test "Read list" {
    var mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    const env = try berlisp.env.Environment.new(mem_man, null);

    var reader = Reader.init("(quote sym)", mem_man, pd);

    const code = try reader.next();

    assert(code.obj == .cons_cell);

    const res = try berlisp.eval.eval(code, mem_man, env);

    const ref = try mem_man.intern("sym");
    assert(res == ref);
}
