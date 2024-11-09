const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const num_1 = try allocator.create(LispObj);
    const num_2 = try allocator.create(LispObj);
    num_1.* = LispObj{ .number = 32 };
    num_2.* = LispObj{ .number = 32 };
    const cell = try ConsCell.new(allocator, num_1, num_2);
    std.debug.print("car = {d}, cdr = {d}", .{ cell.car.number, cell.cdr.number });

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
}
const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    number: i128,
};

const ConsCell = struct {
    car: *LispObj,
    cdr: *LispObj,

    pub fn new(
        allocator: std.mem.Allocator,
        car: *LispObj,
        cdr: *LispObj,
    ) !*ConsCell {
        var cell = try allocator.create(ConsCell);
        cell.car = car;
        cell.cdr = cdr;
        return cell;
    }
};

const Symbol = struct {
    name: []u8,
};
