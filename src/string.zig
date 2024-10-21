const std = @import("std");

pub const StringUnmanaged = struct {
    slice:[]const u8,
    pub fn init(slice: []const u8) @This(){
        return StringUnmanaged{.slice = slice};
    }
    pub fn deinit() void {}

    pub fn at(self: @This(),index: usize) u8
    {
        return self.slice[index];
    }
};
pub const String = struct {
    slice: []const u8,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, slice: []const u8) @This() {
        return String{ .slice = slice, .allocator = allocator };
    }
    pub fn deinit(self: @This()) void {
        defer self.allocator.free(self.slice);
    }
    pub fn emptyInit() @This(){
        return String{.slice=undefined,.allocator=undefined};
    }
    pub fn unmanaged(self: @This()) StringUnmanaged{
        return StringUnmanaged.init(self.slice);
    }
    pub fn at(self: @This(),index: usize) u8
    {
        return self.slice[index];
    }
};
