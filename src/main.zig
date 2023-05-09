const std = @import("std");
const List = @import("linked_list.zig").LinkedList(std.heap.page_allocator, u16);

pub fn main() !void {
    var list = try List.new(100);
    try list.push_back(200);
    try list.push_back(300);
    try list.push_back(400);

    const iter = try list.iter();
    defer iter.clean();

    while (iter.next()) |node| {
        std.debug.print("{d}\n", .{ node });
    }
}
