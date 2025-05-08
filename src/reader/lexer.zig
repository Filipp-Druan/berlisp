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

const CodePoint = code_point.CodePoint;
const CodeIter = code_point.Iterator;

/// Это ленивый лексический анализатор. Он работает как итератор.
/// Считывает и выдаёт токены по одному.
///
/// У нас есть множество процедур, которые могут считать лексему, а могут не считать.
/// Если лексему считать получилось, то процедура устанавливает новое состояние лексера,
/// а в противном случае оставляет его как есть.
pub const Lexer = struct {
    code: CodeIter,
    pd: PropsData,

    pub fn init(code: CodeIter, pd: PropsData) Lexer {
        const lexer = Lexer{
            .code = code,
            .pd = pd,
        };

        return lexer;
    }

    pub fn initFromString(str: []const u8, pd: PropsData) Lexer {
        return Lexer.init(CodeIter{ .bytes = str }, pd);
    }

    pub fn next(self: *Lexer) !Token {
        return self.readNext();
    }

    pub fn peek(self: *Lexer) !Token {
        var lexer = self.*;
        return Lexer.readNext(&lexer);
    }

    pub fn skipWhiteSpace(self: *Lexer) void {
        var code = &self.code;
        while (code.peek()) |point| {
            if (self.pd.isWhitespace(point.code)) {
                _ = code.next();
                continue;
            } else {
                break;
            }
        }
    }

    pub fn readNext(self: *Lexer) !Token {
        self.skipWhiteSpace();

        switch (self.readEof()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readSymbol()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readOpenBracket()) {
            .tok => |token| return token,
            .fail => {},
        }
        switch (self.readCloseBracket()) {
            .tok => |token| return token,
            .fail => {},
        }

        return LexError.CantRead;
    }

    fn readEof(self: *Lexer) Res {
        var code = self.code;
        if (code.next()) |_| {
            return Res.fail;
        } else {
            return .{ .tok = Token{
                .tag = .Eof,
                .str = "",
                .start = code.i,
                .end = code.i,
            } };
        }
    }

    fn readOpenBracket(self: *Lexer) Res {
        var code = self.code;
        const start = code.i;

        if (isOpenBracket(code.next())) {
            var lexer = self;
            lexer.code = code;

            return Res.success(.OpenBracket, start, code);
        } else {
            return Res.fail;
        }
    }

    fn readCloseBracket(self: *Lexer) Res {
        var code = self.code;
        const start = code.i;

        if (isCloseBracket(code.next())) {
            var lexer = self;
            lexer.code = code;

            return Res.success(.CloseBracket, start, code);
        } else {
            return Res.fail;
        }
    }

    fn readSymbol(self: *Lexer) Res {
        var code = self.code;
        const start = code.i;

        if (isSymbolStartPoint(code.next(), self.pd)) {
            // Ничего не делаем.
        } else {
            return Res.fail;
        }

        while (code.peek()) |point| {
            if (isSymbolBodyPoint(point, self.pd)) {
                _ = code.next();
            } else {
                break;
            }
        }

        var lexer = self;
        lexer.code = code;

        return Res.success(.Symbol, start, code);
    }
};

const LexError = error{
    CantRead,
};

const Res = union(enum) {
    tok: Token,
    fail,

    pub fn success(tag: TokenTag, start: u32, code: CodeIter) Res {
        return .{ .tok = .{
            .tag = tag,
            .str = getSliceToNext(code, start),
            .start = start,
            .end = posOfNext(code),
        } };
    }
};

fn getSlice(code: CodeIter, start: u32, end: u32) []const u8 {
    return code.bytes[start..end];
}

fn getSliceToNext(code: CodeIter, start: u32) []const u8 {
    return getSlice(code, start, posOfNext(code));
}

fn isSymbolStartPoint(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        const code = point.code;
        return pd.isAlphabetic(code) or
            code == '+' or
            code == '-' or
            code == '*' or
            code == '/' or
            code == '<' or
            code == '=' or
            code == '>';
    } else {
        return false;
    }
}

fn isSymbolBodyPoint(cp: ?CodePoint, pd: PropsData) bool {
    if (cp) |point| {
        const code = point.code;

        return isSymbolStartPoint(cp, pd) or pd.isDecimal(code);
    } else {
        return false;
    }
}

fn isOpenBracket(cp: ?CodePoint) bool {
    if (cp) |point| {
        const code = point.code;
        return code == '(' or code == '[';
    } else {
        return false;
    }
}

fn isCloseBracket(cp: ?CodePoint) bool {
    if (cp) |point| {
        const code = point.code;
        return code == ')' or code == ']';
    } else {
        return false;
    }
}

fn posOfNext(code: CodeIter) u32 {
    return code.i;
}

pub const Token = struct {
    tag: TokenTag,
    str: []const u8,
    start: usize,
    end: usize,
};

pub const TokenTag = enum {
    Eof,
    Symbol,
    OpenBracket,
    CloseBracket,
};

test "getSliceToNext" {
    var iter = CodeIter{ .bytes = "abcd" };

    _ = iter.next();

    const start = iter.i;
    _ = iter.next();
    _ = iter.next();

    const res = getSliceToNext(iter, start);

    const ref = "bc";

    try std.testing.expectEqualStrings(ref, res);
}

test "Lexer.init" {
    const mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    const code = CodeIter{ .bytes = "sym" };
    _ = Lexer.init(code, pd);
}

test "Lexer.next" {
    const mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    const code = CodeIter{ .bytes = "(sym)" };
    var lexer = Lexer.init(code, pd);

    const obt = try lexer.next();
    const st = try lexer.next();
    const cbt = try lexer.next();

    try std.testing.expectEqualStrings("(", obt.str);
    try std.testing.expectEqualStrings("sym", st.str);
    try std.testing.expectEqualStrings(")", cbt.str);
}
