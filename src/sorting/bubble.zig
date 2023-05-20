const std = @import("std");

pub fn bubbleSort(comptime T: type, arr: []T, swap: fn (*const T, *const T) bool) void {
    for (0..arr.len) |i| {
        for (0..arr.len - i - 1) |j| {
            if (swap(&arr[j + 1], &arr[j])) {
                std.mem.swap(T, &arr[j], &arr[j + 1]);
            }
        }
    }
}
