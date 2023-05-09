const std = @import("std");

pub fn LinkedList(comptime alloc: std.mem.Allocator, comptime T: type) type {
    return struct {
        const Node = struct {
            val: T,
            next: ?*Node = null,

            fn new(val: T) !*Node {
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

        pub fn new(val: ?T) !Self {
            if (val == null) {
                return Self{ .head = null, .tail = Tail.no_head };
            }
            const node = try Node.new(val.?);
            return Self{ .head = node, .tail = Tail.head };
        }

        pub fn clean(self: *Self) void {
            var tmp = self.head;
            while (tmp) |next| {
                tmp = next.next;
                alloc.destroy(next);
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
            const node = try Node.new(val);
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
            const node = try Node.new(val);
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
                    alloc.destroy(tail);

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
                    alloc.destroy(self.head.?);
                    self.head = null;
                    self.tail = Tail.no_head;

                    return val;
                },
                .tail => {
                    const val = self.head.?.val;
                    const head = self.head.?;

                    self.head = head.next;
                    alloc.destroy(head);

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

                    alloc.destroy(self.head.?);
                    self.head = null;

                    return val;
                } else null,
                .tail => if (n == 0) {
                    const val = self.head.?.val;
                    const head = self.head.?;

                    self.head = head.next;
                    alloc.destroy(head);

                    return val;
                } else {
                    const node = self._nth(n) orelse return null;
                    const val = node.val;

                    (self._nth(n - 1) orelse unreachable).next = node.next;
                    alloc.destroy(node);

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

        const LinkedListIterator = struct {
            current: ?*Node,

            pub fn next(self: *LinkedListIterator) ?T {
                const ret = self.current orelse return null;
                self.current = ret.next;

                return ret.val;
            }

            pub fn clean(self: *LinkedListIterator) void {
                alloc.destroy(self);
            }
        };

        pub fn iter(self: *Self) !*LinkedListIterator {
            const iterator = try alloc.create(LinkedListIterator);
            iterator.* = .{ .current = self.head };
            return iterator;
        }
    };
}

test "LinkedList" {
    const expectEq = std.testing.expectEqual;
    const List = LinkedList(std.testing.allocator, u8);

    _ = struct {
        test "push&pop" {
            var list = try List.new(100);
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
            var list = try List.new(20);
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
            var list = try List.new(50);
            defer list.clean();

            try list.push_back(100);
            try expectEq(list.len(), 2);
            try list.push_back(101);
            try expectEq(list.len(), 3);
            try list.push_back(102);
            try expectEq(list.len(), 4);
        }
        test "iter" {
            var list1 = try List.new(1);
            var list2 = try List.new(null);
            defer list1.clean();
            defer list2.clean();

            try list1.push_back(2);
            try list1.push_back(3);
            try list1.push_back(4);

            const iter = try list1.iter();
            defer iter.clean();
            
            var i: u8 = 1;
            while (iter.next()) |node|: (i += 1) {
                try expectEq(node, i);
            }
        }
    };
}
