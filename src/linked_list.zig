const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn LinkedList(comptime T: type) type {
    return struct {
        const Node = struct {
            val: T,
            next: ?*Node = null,

            fn new(alloc: Allocator, val: T) !*Node {
                const link = try alloc.create(Node);
                link.* = .{ .val = val };
                return link;
            }
        };

        const TailTag = enum {
            tail,
            head,
            no_head,
        };
        const Tail = union(TailTag) {
            tail: *Node,
            head: void,
            no_head: void,
        };

        const Self = @This();

        head: ?*Node,
        tail: Tail,
        alloc: Allocator,

        pub fn new(alloc: Allocator, val: ?T) !Self {
            if (val == null) {
                return Self{ .head = null, .tail = Tail.no_head, .alloc = alloc };
            }
            const node = try Node.new(alloc, val.?);
            return Self{ .head = node, .tail = Tail.head, .alloc = alloc };
        }

        pub fn clean(self: *Self) void {
            var tmp = self.head;
            while (tmp) |next| {
                tmp = next.next;
                self.alloc.destroy(next);
            }
        }

        pub fn len(self: Self) usize {
            return switch (self.tail) {
                .no_head => 0,
                .head => 1,
                .tail => {
                    var l: usize = 0;
                    var tmp = self.head;
                    while (tmp) |next| : (l += 1) {
                        tmp = next.next;
                    }

                    return l;
                },
            };
        }

        pub fn push_back(self: *Self, val: T) !void {
            const node = try Node.new(self.alloc, val);
            switch (self.tail) {
                .no_head => {
                    self.head = node;
                    self.tail = TailTag.head;
                },
                .head => {
                    self.head.?.next = node;
                    self.tail = Tail{ .tail = node };
                },
                .tail => |tail| {
                    tail.next = node;
                    self.tail = Tail{ .tail = node };
                },
            }
        }

        pub fn push_front(self: *Self, val: T) !void {
            const node = try Node.new(self.alloc, val);
            switch (self.tail) {
                .no_head => {
                    self.head = node;
                    self.tail = TailTag.head;
                },
                .head => {
                    node.next = self.head;
                    self.head = node;
                    self.tail = Tail{ .tail = self.head.?.next.? };
                },
                .tail => {
                    node.next = self.head.?;
                    self.head = node;
                },
            }
        }

        pub fn pop_back(self: *Self) ?T {
            return switch (self.tail) {
                .tail => |tail| {
                    const val = tail.val;
                    const new_tail = self._nth(self.len() - 2).?;
                    new_tail.next = null;
                    self.alloc.destroy(tail);

                    if (self.len() == 1) {
                        self.tail = Tail.head;
                    }

                    return val;
                },
                else => self.pop_front(),
            };
        }

        pub fn pop_front(self: *Self) ?T {
            switch (self.tail) {
                .no_head => return null,
                .head => {
                    const val = self.head.?.val;
                    self.alloc.destroy(self.head.?);
                    self.head = null;
                    self.tail = Tail.no_head;

                    return val;
                },
                .tail => {
                    const val = self.head.?.val;
                    const head = self.head.?;

                    self.head = head.next;
                    self.alloc.destroy(head);

                    if (self.len() == 1) self.tail = Tail.head;

                    return val;
                },
            }
        }

        pub fn nth(self: Self, n: usize) ?T {
            const res = self._nth(n) orelse return null;
            return res.val;
        }

        pub fn removeNth(self: *Self, n: usize) ?T {
            return switch (self.tail) {
                .no_head => return null,
                .head => if (n == 0) {
                    const val = self.head.?.val;

                    self.alloc.destroy(self.head.?);
                    self.head = null;

                    return val;
                } else null,
                .tail => if (n == 0) {
                    const val = self.head.?.val;
                    const head = self.head.?;

                    self.head = head.next;
                    self.alloc.destroy(head);

                    return val;
                } else {
                    const node = self._nth(n) orelse return null;
                    const val = node.val;

                    (self._nth(n - 1) orelse unreachable).next = node.next;
                    self.alloc.destroy(node);

                    return val;
                },
            };
        }

        fn _nth(self: Self, n: usize) ?*Node {
            var tmp = self.head orelse return null;
            for (0..n + 1) |i| {
                if (n == i) return tmp;
                if (tmp.next == null) return null;
                tmp = tmp.next.?;
            }

            return null;
        }

        pub fn from_arr(alloc: Allocator, arr: []const T) !Self {
            return switch (arr.len) {
                0 => try Self.new(alloc, null),
                1 => try Self.new(alloc, arr[0]),
                else => {
                    var self = try Self.new(alloc, arr[0]);

                    for (arr[1..]) |val| {
                        try self.push_back(val);
                    }

                    return self;
                }
            };
        }

        pub fn to_arr(self: *Self) ![]T {
            const buf = try self.alloc.alloc(T, self.len());
            var tmp = self.head;
            var i: usize = 0;

            while (tmp) |next|: (i += 1) {
                buf[i] = next.val;
                tmp = next.next;
            }

            return buf;
        }
    };
}

test "LinkedList" {
    const expectEq = std.testing.expectEqual;
    const alloc = std.testing.allocator;
    const List = LinkedList(u8);

    _ = struct {
        test "push&pop" {
            var list = try List.new(alloc, 100);
            defer list.clean();

            try list.push_back(150);
            try list.push_back(200);
            try list.push_front(50);

            try expectEq(list.pop_back(), 200);
            try expectEq(list.pop_front(), 50);
            try expectEq(list.pop_front(), 100);
            try expectEq(list.pop_back(), 150);
            try expectEq(list.pop_back(), null);
            try expectEq(list.pop_front(), null);
        }
        test "nth" {
            var list = try List.new(alloc, 20);
            defer list.clean();

            try list.push_back(30);
            try list.push_back(40);
            try list.push_front(50);

            try expectEq(list.nth(0), 50);
            try expectEq(list.nth(3), 40);
            try expectEq(list.nth(5), null);
            try expectEq(list.removeNth(1), 20);
            try expectEq(list.removeNth(5), null);
            try expectEq(list.removeNth(2), 40);
        }
        test "len" {
            var list = try List.new(alloc, 50);
            defer list.clean();

            try list.push_back(100);
            try expectEq(list.len(), 2);
            try list.push_back(101);
            try expectEq(list.len(), 3);
            try list.push_back(102);
            try expectEq(list.len(), 4);
        }
        test "arrays" {
            var list = try List.from_arr(alloc, &[_]u8{ 1, 2, 3, 4, 5 });
            defer list.clean();

            const arr = try list.to_arr();
            defer alloc.free(arr);
            
            var i: u8 = 1;
            for (arr) |node| {
                try expectEq(node, i);
                i += 1;
            }

            i = 1;
            for (arr) |node| {
                try expectEq(node, i);
                i += 1;
            }
        }
    };
}
