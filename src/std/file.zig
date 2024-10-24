const std = @import("std");
const stdtypes = @import("string.zig");

pub const FileData = struct {
    code: stdtypes.String,
    lines: std.ArrayList(stdtypes.String),
    offset: usize,
    pub fn init(code: stdtypes.String, lines: std.ArrayList(stdtypes.String)) FileData {
        return FileData{
            .code = code,
            .lines = lines,
            .offset = 0
        };
    }
    pub fn deinit(self: @This()) void {
        for (self.lines.items) |line| {
            defer line.deinit();
        }
        defer self.code.deinit();
        defer self.lines.deinit();
    }
    pub fn current(self: *@This()) u8 {
        return self.code.slice[self.offset];
    }
    pub fn getRange(self:*const @This(),length:usize) stdtypes.StringUnmanaged {
        return stdtypes.StringUnmanaged.init(self.code.slice[self.offset..(self.offset+length)]);
    }
};
pub fn read_file(allocator: std.mem.Allocator, relative_path: []const u8) !FileData {
    const working_dir: std.fs.Dir = std.fs.cwd();
    const working_dir_str = try working_dir.realpathAlloc(allocator, ".");
    std.log.info("Working Directory: {s}", .{working_dir_str});
    defer allocator.free(working_dir_str);

    std.log.info("Trying to read: {s}", .{relative_path});
    var file = working_dir.openFile(relative_path, .{}) catch |err|
    {
        return err;
    };

    const file_stat = (try file.stat());

    std.log.info("File Size: {d}", .{file_stat.size});

    const code = try file.reader().readAllAlloc(allocator, file_stat.size);
    var lines_iterator = std.mem.splitSequence(u8, code, "\n");
    var lines_data: std.ArrayList(stdtypes.String) = std.ArrayList(stdtypes.String).init(allocator);
    while (lines_iterator.next()) |line| {
        const memory = try allocator.alloc(u8, line.len);
        @memcpy(memory, line);
        try lines_data.append(stdtypes.String.init(allocator, memory));
    }
    return FileData.init(stdtypes.String.init(allocator, code), lines_data);
}
