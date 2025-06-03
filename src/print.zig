const std = @import("std");

const berlisp = @import("berlisp.zig");

const base_types = berlisp.base_types;

const assert = std.debug.assert;

const stdPrint = std.debug.print;

const GCObj = berlisp.memory.GCObj;

pub fn print(obj: *GCObj) void {
    switch (obj.obj) {
        .symbol => |sym| {
            stdPrint("{s}", .{sym.name.obj.str.string});
        },
        .cons_cell => |cell| {
            stdPrint("(", .{});
            print(cell.car);
            printTail(cell.cdr);
        },
        else => {
            stdPrint("НЕГОТОВО", .{});
        },
    }
}

fn printTail(obj: *GCObj) void {
    switch (obj.obj) {
        .cons_cell => |cell| {
            stdPrint(" ", .{});
            print(cell.car);
            printTail(cell.cdr);
        },
        .nil => {
            stdPrint(")", .{});
        },
        else => {
            stdPrint(" . ", .{});
            print(obj);
        },
    }
}
