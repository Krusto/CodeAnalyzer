const std = @import("std");

pub const StringUnmanaged = struct {
    slice: []const u8,
    len: usize,
    pub fn init(slice: []const u8) @This(){
        return StringUnmanaged{.slice = slice,.len = slice.len};
    }
    pub fn deinit() void {}

    pub fn at(self: @This(),index: usize) u8
    {
        return self.slice[index];
    }

    pub fn startsWith(self:*const @This(),value:[]const u8) bool
    {
        var result = true;
        if(value.len > self.len)
        {
            result = false;
        }
        else
        {
            var index: usize = 0;
            while(index < value.len):(index+=1)
            {
                if(self.slice[index] != value[index]) { result = false;break;}
            }
        }
        return result;
    }
    pub fn lstrip(self: *const @This()) !@This()
    {
        var index:u32 = 0;
        while(index < self.len) : (index+=1)
        {
            if(self.slice[index] != ' ') break;
        }
        return .{.slice = self.slice[index..],.len = self.len - index};
    }
    pub fn substr(self: *const @This(), offset: usize) !@This()
    {
        return .{.slice = self.slice[offset..],.len = self.len - offset};
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
