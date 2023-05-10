const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DoublyLinkedList(comptime T: type) type {
    return struct {
        const Node = struct {
            val: T,
            next: ?*Node = null,
            prev: ?*Node = null,

            fn new(alloc: Allocator, val: T) !*Node {
                const link = try alloc.create(Node);
                link.* = .{ .val = val };
                return link;
            }
        };

        const Self = @This();

        head: ?*Node,
        tail: ?*Node,
        len: usize,
        alloc: Allocator,

        pub fn new(alloc: Allocator, val: ?T) !Self {
            return Self{ .head = if (val == null) null else try Node.new(alloc, val.?), .tail = null, .len = if (val == null) 0 else 1, .alloc = alloc };
        }

        pub fn clean(self: *Self) void {
            var tmp = self.head;
            while (tmp) |next| {
                tmp = next.next;
                self.alloc.destroy(next);
            }
        }

        pub fn push_back(self: *Self, val: T) !void {
            const node = try Node.new(self.alloc, val);
            
            if (self.tail) |tail| {
                node.prev = tail;
                tail.next = node;
                self.tail = node;
            } else if (self.head) |head| {
                node.prev = head;
                head.next = node;
                self.tail = node;
            } else {
                self.head = node;
            }

            self.len += 1;
        }

        pub fn push_front(self: *Self, val: T) !void {
            const node = try Node.new(self.alloc, val);
            
            if (self.head) |head| {
                head.prev = node;
                node.next = head;
                self.head = node;
            } else {
                self.head = node;
            }

            self.len += 1;
        }

        pub fn pop_back(self: *Self) ?T {
            if (self.tail) |tail| {
                const val = tail.val;

                if (self.len == 2) {
                    self.tail = null;
                    self.head.?.next = null;
                } else {
                    tail.prev.?.next = null;
                    self.tail = tail.prev;
                }

                self.alloc.destroy(tail);

                self.len -= 1;
                return val;
            } else if (self.head) |head| {
                const val = head.val;

                self.head = null;

                self.alloc.destroy(head);

                self.len -= 1;
                return val;
            } else {
                return null;
            }
        }

        pub fn pop_front(self: *Self) ?T {
            if (self.head) |head| {
                const val = head.val;

                if (self.len == 2) {
                    const tail = self.tail.?;
                    tail.prev = null;
                    self.tail = null;
                    self.head = tail;
                } else {
                    const next = self.head.?.next.?;
                    next.prev = null;
                    self.head = next;
                }

                self.alloc.destroy(head);

                self.len -= 1;
                return val;
            } else {
                return null;
            }
        }

        pub fn nth(self: Self, n: usize) ?*const T {
            const res = self._nth(n) orelse return null;
            return &res.val;
        }

        pub fn removeNth(self: *Self, n: usize) ?T {
            if (n == 0) {
                return self.pop_front();
            } else if (n == self.len - 1) {
                return self.pop_back();
            } else {
                const node_rm = self._nth(n) orelse return null;
                const val = node_rm.val;
                const node_next = node_rm.next.?;
                const node_prev = node_rm.prev.?;

                self.alloc.destroy(node_rm);

                node_prev.next = node_next;
                node_next.prev = node_prev;

                self.len -= 1;
                return val;
            }
        }

        fn _nth(self: Self, n: usize) ?*Node {
            const l = self.len;

            if (l <= n) return null;

            if (l > n * 2) {
                var tmp = self.head orelse return null;
                for (0..n + 1) |i| {
                    if (n == i) return tmp;
                    tmp = tmp.next orelse return null;
                }
            } else {
                const stop = l - n;
                var tmp = self.tail orelse return null;

                for (0..stop) |i| {
                    if (i == stop - 1) return tmp;
                    tmp = tmp.prev orelse return null;
                }
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

        pub fn to_arr(self: *Self) ![]*const T {
            const buf = try self.alloc.alloc(*const T, self.len);
            var tmp = self.head;
            var i: usize = 0;

            while (tmp) |next|: (i += 1) {
                buf[i] = &next.val;
                tmp = next.next;
            }

            return buf;
        }
    };
}

test "LinkedList" {
    const expectEq = std.testing.expectEqual;
    const alloc = std.testing.allocator;
    const List = DoublyLinkedList(u8);

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
            var list = try List.from_arr(alloc, &[_]u8{ 50, 20, 30, 40});
            defer list.clean();

            try expectEq(list.nth(0).?.*, 50);
            try expectEq(list.nth(3).?.*, 40);
            try expectEq(list.nth(5), null);
            try expectEq(list.removeNth(1), 20);
            try expectEq(list.removeNth(5), null);
            try expectEq(list.removeNth(2), 40);
        }
        test "len" {
            var list = try List.new(alloc, 50);
            defer list.clean();

            try list.push_back(100);
            try expectEq(list.len, 2);
            try list.push_back(101);
            try expectEq(list.len, 3);
            try list.push_back(102);
            try expectEq(list.len, 4);
        }
        test "arrays" {
            var list = try List.from_arr(alloc, &[_]u8{ 1, 2, 3, 4, 5 });
            defer list.clean();

            const arr = try list.to_arr();
            defer alloc.free(arr);
            
            var i: u8 = 1;
            for (arr) |node| {
                try expectEq(node.*, i);
                i += 1;
            }

            i = 1;
            for (arr) |node| {
                try expectEq(node.*, i);
                i += 1;
            }
        }
    };
}
