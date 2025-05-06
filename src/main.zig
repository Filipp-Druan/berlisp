const std = @import("std");

const PropsData = @import("PropsData");

const berlisp = @import("berlisp.zig");
const read_module = berlisp.read_module;

const assert = std.debug.assert;

const MemoryManager = berlisp.memory.MemoryManager;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer gpa.deinit();
}

test "main test" {
    const mem_man = try MemoryManager.init(std.testing.allocator);
    defer mem_man.deinit();

    const pd = try PropsData.init(std.testing.allocator);
    defer pd.deinit();

    const res = read_module.readFromString("sym", mem_man, pd);

    assert(res.err == null);
    std.testing.refAllDecls(berlisp.lexer);
    std.testing.refAllDecls(berlisp.parser);
}
