const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Cmp = enum {
    Bigger,
    Smaller,
    Equal,
};

pub fn BinaryTree(comptime T: type) type {
    return struct {
        const Self = @This();
        const CmpFn = *const fn (*const T, *const T) Cmp;
        const Node = struct {
            value: T,
            parent: ?*Node = null,
            right: ?*Node = null,
            left: ?*Node = null,

            fn new(alloc: Allocator, value: T) !*Node {
                const node = try alloc.create(Node);
                node.* = .{ .value = value };
                return node;
            }

            fn print(self: *Node, indent: u8) void {
                for (0..indent) |_| {
                    std.debug.print(" ", .{});
                }

                std.debug.print("{d} ", .{self.value});
                if (self.parent) |parent| {
                    std.debug.print("({d})\n", .{parent.value});
                } else {
                    std.debug.print(" (null)\n", .{});
                }

                if (self.left) |left| {
                    left.print(indent + 2);
                }
                if (self.right) |right| {
                    right.print(indent + 2);
                }
            }

            fn clean(self: *Node, alloc: Allocator) void {
                for ([_]?*Node{ self.left, self.right }) |maybe_node| {
                    if (maybe_node) |node| node.clean(alloc);
                }

                alloc.destroy(self);
            }

            fn search(self: *Node, cmp: CmpFn, key: *const T) ?*const T {
                switch (cmp(&self.value, key)) {
                    .Bigger => {
                        if (self.right) |right| {
                            return right.search(cmp, key);
                        }
                    },
                    .Smaller => {
                        if (self.left) |left| {
                            return left.search(cmp, key);
                        }
                    },
                    .Equal => {
                        return &self.value;
                    }
                }

                return null;
            }

            fn add(self: *Node, alloc: Allocator, cmp: CmpFn, value: T) !void {
                switch (cmp(&self.value, &value)) {
                    .Bigger => {
                        if (self.right) |right| {
                            return right.add(alloc, cmp, value);
                        } else {
                            const node = try Node.new(alloc, value);
                            node.parent = self;
                            self.right = node;
                        }
                    },
                    .Smaller => {
                        if (self.left) |left| {
                            return left.add(alloc, cmp, value);
                        } else {
                            const node = try Node.new(alloc, value);
                            node.parent = self;
                            self.left = node;
                        }
                    },
                    .Equal => {
                        if (self.left) |left| {
                            _ = left;
                        } else {
                            const node = try Node.new(alloc, value);
                            node.parent = self;
                            self.left = node;
                        }
                    }
                }
            }

            fn remove(self: *Node, alloc: Allocator, cmp: CmpFn, value: *const T) std.meta.Tuple(&.{?*Node, ?T}) {
                switch (cmp(&self.value, value)) {
                    .Bigger => {
                        if (self.right) |right| {
                            const val = right.remove(alloc, cmp, value);
                            if (val.@"0") |tree| {
                                tree.parent = self;
                            }
                            self.right = val.@"0";

                            return .{self, val.@"1"};
                        } else {
                            return .{null, null};
                        }
                    },
                    .Smaller => {
                        if (self.left) |left| {
                            const val = left.remove(alloc, cmp, value);
                            if (val.@"0") |tree| {
                                tree.parent = self;
                            }
                            self.left = val.@"0";

                            return .{self, val.@"1"};
                        } else {
                            return .{null, null};
                        }
                    },
                    .Equal => {
                        if (self.left == null) {
                            const tmp = .{self.right, self.value};

                            alloc.destroy(self);

                            return tmp;
                        } else if (self.right == null) {
                            const tmp = .{self.left, self.value};

                            alloc.destroy(self);

                            return tmp;
                        } else {
                            const next = b: {
                                var tmp = self.right.?;

                                if (tmp.left == null) {
                                    const val = self.value;
                                    self.value = tmp.value;

                                    self.right = tmp.remove(alloc, cmp, &tmp.value).@"0";

                                    return .{self, val};
                                }

                                while (tmp.left) |node| {
                                    tmp = node;
                                }

                                break :b tmp;
                            };
                            const val = self.value;
                            self.value = next.value;

                            const parent = next.parent.?;
                            const node = next.remove(alloc, cmp, &next.value).@"0";
                            if (node) |tree| {
                                tree.parent = parent;
                            }
                            parent.left = node;

                            return .{self, val};
                        }
                    }
                }
            }

            fn inorder(self: *Node, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
                if (self.left) |left| {
                    left.inorder(context, func);
                }
                func(context, &self.value);
                if (self.right) |right| {
                    right.inorder(context, func);
                }
            }

            fn preorder(self: *Node, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
                func(context, &self.value);
                if (self.left) |left| {
                    left.preorder(context, func);
                }
                if (self.right) |right| {
                    right.preorder(context, func);
                }
            }

            fn postorder(self: *Node, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
                if (self.left) |left| {
                    left.postorder(context, func);
                }
                if (self.right) |right| {
                    right.postorder(context, func);
                }
                func(context, &self.value);
            }
        };

        root: ?*Node,
        cmp: CmpFn,
        alloc: Allocator,

        pub fn new(alloc: Allocator, cmp: CmpFn) Self {
            return Self{ .root = null, .alloc = alloc, .cmp = cmp };
        }

        pub fn print(self: *Self) void {
            if (self.root) |root| root.print(0);
        }

        pub fn clean(self: *Self) void {
            if (self.root) |root| {
                root.clean(self.alloc);
            }
        }

        pub fn search(self: *Self, key: *const T) ?*const T {
            if (self.root) |root| {
                return root.search(self.cmp, key);
            }
            return null;
        }

        pub fn add(self: *Self, value: T) !void {
            if (self.root) |root| {
                return root.add(self.alloc, self.cmp, value);
            } else {
                self.root = try Node.new(self.alloc, value);
            }
        }

        pub fn remove(self: *Self, value: *const T) ?T {
            if (self.root) |root| {
                const ret = root.remove(self.alloc, self.cmp, value);
                self.root = ret.@"0";

                return ret.@"1";
            }

            return null;
        }

        pub fn inorder(self: *Self, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
            if (self.root) |root| {
                root.inorder(context, func);
            }
        }

        pub fn preorder(self: *Self, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
            if (self.root) |root| {
                root.preorder(context, func);
            }
        }

        pub fn postorder(self: *Self, context: anytype, func: *const fn (context: @TypeOf(context), value: *T) void) void {
            if (self.root) |root| {
                root.postorder(context, func);
            }
        }
    };
}

test "BinaryTree" {
    const expectEq = std.testing.expectEqual;
    const alloc = std.testing.allocator;
    const BTree = BinaryTree(u8);

    _ = struct {
        test "creation" {
            var btree = BTree.new(alloc, struct {
                fn cmp(a_c: *const u8, b_c: *const u8) Cmp {
                    const a = a_c.*;
                    const b = b_c.*;
                    return if (b > a) Cmp.Bigger else if (b < a) Cmp.Smaller else Cmp.Equal;
                }
            }.cmp);
            defer btree.clean();

            try btree.add(100);
            try btree.add(103);
            try btree.add(101);
            try btree.add(102);
            try btree.add(104);
            try btree.add(98);
            try btree.add(97);
            try btree.add(99);

            try expectEq(btree.search(&@as(u8, 0)), null);
            try expectEq(btree.search(&@as(u8, 99)).?.*, @as(u8, 99));

            try expectEq(btree.remove(&@as(u8, 99)), 99);
            try expectEq(btree.remove(&@as(u8, 98)), 98);
            try expectEq(btree.remove(&@as(u8, 100)), 100);

            std.debug.print("\n", .{});
            const LinkedList = @import("linked_list.zig").LinkedList(u8);
            const Tuple = std.meta.Tuple(&.{?error{Err}, LinkedList});
            var tuple: Tuple = .{null, try LinkedList.from_arr(alloc, &[_]u8{ 97, 101, 102, 103, 104 })};
            errdefer tuple.@"1".clean();

            btree.inorder(&tuple, struct {
                fn func(t: *Tuple, value: *u8) void {
                    if (t.@"0" != null) return;

                    expectEq(t.@"1".pop_front().?, value.*) catch {
                        t.@"0" = error.Err;
                        return;
                    };
                }
            }.func);
            try std.testing.expect(tuple.@"0" == null);
            tuple.@"1".clean();

            tuple = .{null, try LinkedList.from_arr(alloc, &[_]u8{ 101, 97, 103, 102, 104 })};

            btree.preorder(&tuple, struct {
                fn func(t: *Tuple, value: *u8) void {
                    if (t.@"0" != null) return;

                    expectEq(t.@"1".pop_front().?, value.*) catch {
                        t.@"0" = error.Err;
                        return;
                    };
                }
            }.func);
            try std.testing.expect(tuple.@"0" == null);
            tuple.@"1".clean();

            tuple = .{null, try LinkedList.from_arr(alloc, &[_]u8{ 97, 102, 104, 103, 101 })};
            defer tuple.@"1".clean();

            btree.postorder(&tuple, struct {
                fn func(t: *Tuple, value: *u8) void {
                    if (t.@"0" != null) return;

                    expectEq(t.@"1".pop_front().?, value.*) catch {
                        t.@"0" = error.Err;
                        return;
                    };
                }
            }.func);
            try std.testing.expect(tuple.@"0" == null);
        }
    };
}
