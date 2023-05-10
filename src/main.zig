const std = @import("std");
const List = @import("doubly_linked_list.zig").DoublyLinkedList(u16);

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var list = try List.new(alloc, 100);
    defer list.clean();

    try list.push_back(200);
    try list.push_back(300);
    try list.push_back(400);

    const arr = try list.to_arr();
    defer alloc.free(arr);

    for (arr) |node| {
        std.debug.print("{d}\n", .{ node.* });
    }

    var list2 = try List.from_arr(alloc, &[_]u16{ 1000, 2000, 3000, 4000});
    defer list2.clean();

    var tmp = list2.head;
    while (tmp) |next| {
        std.debug.print("{d}\n", .{ next.val });
        tmp = next.next;
    }

}
