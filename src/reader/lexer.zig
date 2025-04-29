const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const exre = @import("exre");

const berlisp = @import("berlisp.zig");

const base_types = berlisp.base_types;
const mem = berlisp.memory;

const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;

const CodeIter = code_point.Iterator;

const Regex = exre.Regex(.{});

/// Это ленивый лексический анализатор. Он работает как итератор.
/// Считывает и выдаёт токены по одному.
const Lexer = struct {
    code: CodeIter,
    current: ?Token,
    pd: PropsData,

    pub fn init(code: CodeIter, pd: PropsData) Lexer {
        const lexer = Lexer{
            .code = code,
            .current = null,
            .pd = pd,
        };

        return lexer;
    }

    pub fn next(self: *Lexer) Token {
        if (self.current) |token| {
            self.current = null;
            return token;
        } else {
            self.readNext();
        }
    }

    fn readNext(self: *Lexer) void {
        var code = &self.code;
        while (code.peek()) |point| {
            if (self.pd.isWhitespace(point.code)) {
                code.next();
                continue;
            }

            if (isSymbolStartChar(code, self.pd)) {}
        }
    }

    ///
    fn readSymbol(self: *Lexer) void {
        var code = &self.code;
        const start = code.i;

        while (code.peek()) |point| {
            if (isSymbolBodyChar(point, self.pd)) {
                code.next(); // Мы продвигаемся по итератору, и меняем его.
                continue;
            } else {
                break;
            }
        }

        self.current = Token{
            .tag = TokenTag.Symbol,
            .str = getSliceToNext(code, start),
            .start = start,
            .end = posOfNext(code),
        };
    }
};

fn getSlice(code: CodeIter, start: u32, end: u32) []const u8 {
    return code.bytes[start..end];
}

fn getSliceToNext(code: CodeIter, start: u32) []const u8 {
    return getSlice(code, start, posOfNext(code));
}

fn isSymbolStartChar(cp: u21, pd: PropsData) bool {
    return pd.isAlphabetic(cp) or pd.isMath(cp);
}

fn isSymbolBodyChar(cp: u21, pd: PropsData) bool {
    return pd.isAlphabetic(cp) or
        pd.isMath(cp) or
        pd.isDecimal(cp);
}

fn isOpenBracket(cp: u21) bool {
    return cp == '(' or cp == '[';
}

fn posOfNext(code: CodeIter) u32 {
    code.next();
    return code.i;
}

const Token = struct {
    tag: TokenTag,
    str: []const u8,
    start: usize,
    end: usize,
};

const TokenTag = enum {
    Symbol,
    OpenBracket,
    CloseBracket,
};

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

    const code = CodeIter{ .bytes = "sym" };
    var lexer = Lexer.init(code, pd);

    const token = lexer.next();

    std.testing.expectEqual("sym", token.str);
}
