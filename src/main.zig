const std = @import("std");
const berlisp = @import("berlisp.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const mem_man = berlisp.memory.MemoryManager.new(allocator);
    _ = mem_man; // autofix

}
