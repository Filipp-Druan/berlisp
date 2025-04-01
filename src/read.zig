const std = @import("std");
const unicode = std.unicode;
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const berlisp = @import("berlisp.zig");

const base_types = berlisp.base_types;
const mem = berlisp.memory;

const assert = std.debug.assert;

const MemoryManager = mem.MemoryManager;
const GCObj = mem.GCObj;

const CodeIter = code_point.Iterator;

pub fn read(code: CodeIter, mem_man: *MemoryManager, pd: PropsData) ReadRes {
    var iter = code;

    while (iter.peek()) |point| : (_ = iter.next()) {
        if (pd.isWhitespace(point.code)) {
            continue;
        } else if (pd.isAlphabetic(point.code)) {
            return readSymbol(iter, mem_man, pd);
        } else if (point.code == '(' or point.code == '[') {} else {
            return ReadRes.fail(ReadError.IllegalChar, iter);
        }
    }

    return ReadRes.fail(ReadError.NotImlemented, iter);
}

pub fn readFromString(str: []const u8, mem_man: *MemoryManager, pd: PropsData) ReadRes {
    const iter = CodeIter{ .bytes = str };
    return read(iter, mem_man, pd);
}

pub fn readSymbol(code: CodeIter, mem_man: *MemoryManager, pd: PropsData) ReadRes {
    var iter = code;
    var buffer = Buffer.init(mem_man.allocator) catch |err| {
        return ReadRes.fail(err, iter);
    };
    defer buffer.deinit();

    while (iter.peek()) |point| : (_ = iter.next()) {
        if (canBeInSymbol(point.code, pd)) { // Первый символ конечно обязан быть буквой, но мы можем его не проверять,
            // Если эта функция не вызывается на абы каком коде, а только тогда, когда read встретила алфавитный символ.
            buffer.addPoint(point.code) catch |err| {
                return ReadRes.fail(err, iter);
            };
        } else {
            break;
        }
    }

    const sym = mem_man.intern(buffer.array.items) catch |err| {
        return ReadRes.fail(err, iter);
    };

    return ReadRes.success(sym, iter);
}

fn canBeInSymbol(point: u21, pd: PropsData) bool {
    return pd.isAlphabetic(point) or pd.isMath(point) or pd.isDecimal(point);
}

const Buffer = struct {
    array: *std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !Buffer {
        const array = try allocator.create(std.ArrayList(u8));
        array.* = std.ArrayList(u8).init(allocator);
        return .{ .array = array };
    }

    pub fn deinit(self: @This()) void {
        const allocator = self.array.allocator;
        self.array.deinit();
        allocator.destroy(self.array);
    }

    pub fn addPoint(self: @This(), point: u21) !void {
        var array = self.array;
        var out = [_]u8{ 0, 0, 0 };
        const len = try unicode.utf8Encode(point, &out);
        try array.appendSlice(out[0..len]);
    }
};

const ReadRes = struct {
    obj: ?*GCObj,
    rest: CodeIter,
    err: ?anyerror,

    pub fn fail(current_err: anyerror, rest: CodeIter) ReadRes {
        return .{ .obj = null, .err = current_err, .rest = rest };
    }

    pub fn success(obj: *GCObj, rest: CodeIter) ReadRes {
        return .{ .obj = obj, .err = null, .rest = rest };
    }
};

const ReadError = error{
    IllegalChar,
    NotImlemented,
};

test "read symbol" {
    const mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    const str = "sym";

    const etalon_sym = try mem_man.intern("sym");
    const res = read(CodeIter{ .bytes = str }, mem_man, pd);

    assert(res.obj != null);
    assert(res.obj.? == etalon_sym);

    std.debug.print("Read test ok", .{});
}
