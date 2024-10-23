const std = @import("std");
const stdtypes = @import("string.zig");
const file = @import("file.zig");
const utils = @import("utils.zig");

pub const FunctionDeclarationInfo = struct {
    line_number: usize,
    offset: usize,
    pub fn init(line_number: usize, offset: usize) FunctionDeclarationInfo {
        return FunctionDeclarationInfo{ .line_number = line_number, .offset = offset };
    }
};

pub const FunctionImplementationInfo = struct {
    line_number: usize,
    offset: usize,
    body: stdtypes.String,
    start_line: usize,
    end_line: usize,
    pub fn init(line_number: usize, offset: usize, body: stdtypes.String, start_line: usize, end_line: usize) FunctionImplementationInfo {
        return FunctionImplementationInfo{ .line_number = line_number, .offset = offset, .body = body, .start_line = start_line, .end_line = end_line };
    }
};

pub const CodeAnalyzer = struct {
    fileData: file.FileData,
    functionDeclarations: std.ArrayList(stdtypes.StringUnmanaged),
    functionImplementations: std.ArrayList(stdtypes.StringUnmanaged),
    functionDeclarationInfos: std.StringArrayHashMap(FunctionDeclarationInfo),
    functionImplementationInfos: std.StringArrayHashMap(FunctionImplementationInfo),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, filePath: stdtypes.StringUnmanaged) !CodeAnalyzer {
        const fileData = try file.read_file(allocator, filePath.slice);
        const functionDeclarations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionImplementations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionDeclarationInfos = std.StringArrayHashMap(FunctionDeclarationInfo).init(allocator);
        const functionImplementationInfos = std.StringArrayHashMap(FunctionImplementationInfo).init(allocator);

        return CodeAnalyzer{ .fileData = fileData, .functionDeclarations = functionDeclarations, .functionImplementations = functionImplementations, .functionDeclarationInfos = functionDeclarationInfos, .functionImplementationInfos = functionImplementationInfos, .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        self.fileData.deinit();
    }
    
    pub fn addDeclaration(self: *@This(), declaration: []const u8, line_number: usize, offset: usize) !void {
        try self.functionDeclarations.append(stdtypes.StringUnmanaged.init(declaration));
        try self.functionDeclarationInfos.put(declaration, FunctionDeclarationInfo.init(line_number, offset));
    }
    
    pub fn getDeclarationLength(code: []const u8, offset: usize) usize {
        var length: usize = 0;
        while (code[offset + length] != ';' and code[offset + length] != '{') {
            length += 1;
        }
        return length;
    }
    
    pub fn extractFunctionDeclarations(self: *@This()) !void {
        var line_number: usize = 1;
        var previous_token: []const u8 = undefined;
        previous_token.len = 0;
        while (self.fileData.offset < self.fileData.code.slice.len) {
            if (self.fileData.current() == '\n') {
                line_number += 1;
                self.fileData.offset += 1;
            }

            const token = utils.getToken(self.fileData.code.slice, self.fileData.offset);

            var stripedToken = stdtypes.StringUnmanaged{ .slice = undefined };
            if (token.len == 0)
                break;

            if (token[0] != ' ') {
                stripedToken = stdtypes.StringUnmanaged.init(try utils.skipWhiteSpace(token));

                if (utils.startsWith(stripedToken.slice, "static") == true and
                    utils.startsWith(previous_token, "inline") == false)
                {
                    const length = CodeAnalyzer.getDeclarationLength(self.fileData.code.slice, self.fileData.offset);
                    const declaration = try utils.skipWhiteSpace(self.fileData.currentRange(length));
                    try addDeclaration(self, declaration, line_number, self.fileData.offset);
                    self.fileData.offset += self.fileData.currentRange(length).len;
                } else {
                    self.fileData.offset += token.len;
                }
                previous_token = stripedToken.slice;
            } else {
                self.fileData.offset += 1;
            }
        }
        self.fileData.offset = 0;
    }

    pub fn addImplementation(self: *@This(), declaration: []const u8, line_number: usize, offset: usize) !void {
        const striped_line = try utils.skipWhiteSpace(declaration);

        try self.functionImplementations.append(stdtypes.StringUnmanaged.init(striped_line));
        try self.functionImplementationInfos.put(striped_line, FunctionImplementationInfo.init(line_number, offset, stdtypes.String.emptyInit(), 0, 0));
    }

    pub fn extractFunctionBody(self: *@This(), declaration: stdtypes.StringUnmanaged) !void {
        const striped_line = try utils.skipWhiteSpace(declaration.slice);
        const info: FunctionImplementationInfo = self.functionImplementationInfos.get(striped_line).?;

        var brace_count: usize = 1;
        var i = info.offset + 1;

        while (brace_count > 0 and i < self.fileData.code.slice.len) {
            const current_char = self.fileData.code.at(i);
            if (current_char == '{') {
                brace_count += 1;
            } else if (current_char == '}') {
                brace_count -= 1;
            }
            i += 1;
        }

        const body = self.fileData.code.slice[info.offset..i];
        const value_ptr = self.functionImplementationInfos.getPtr(striped_line).?;
        value_ptr.*.body = stdtypes.String.init(self.allocator, body);
    }

    pub fn extractFunctionImplementations(self : *@This()) !void {
        var line_number: usize = 1;

        while (self.fileData.offset < self.fileData.code.slice.len) {
            if (self.fileData.current() == '\n') {
                line_number += 1;
                self.fileData.offset += 1;
            }

            const token = utils.getToken(self.fileData.code.slice, self.fileData.offset);
            var stripedToken = stdtypes.StringUnmanaged{ .slice = undefined };
            if (token.len == 0)
                break;
            if (token[0] != ' ') {
                stripedToken = stdtypes.StringUnmanaged.init(try utils.skipWhiteSpace(token));

                if (utils.startsWith(stripedToken.slice, "inline") == true) {
                    const length = CodeAnalyzer.getDeclarationLength(self.fileData.code.slice, self.fileData.offset);
                    const declaration = try utils.skipWhiteSpace(self.fileData.currentRange(length));
                    self.fileData.offset += self.fileData.currentRange(length).len;
                    try self.addImplementation(declaration[6..], line_number, self.fileData.offset);
                } else {
                    self.fileData.offset += token.len;
                }
            } else {
                self.fileData.offset += 1;
            }
        }
        self.fileData.offset = 0;

        for (self.functionImplementations.items) |declaration| {
            try self.extractFunctionBody(declaration);
        }
    }

    pub fn extractFunctions(self: *@This()) !void {
        try extractFunctionDeclarations(self);
        try extractFunctionImplementations(self);
    }

    pub fn checkFunctionOrder(self: *@This()) void {
        std.log.info("Checking Function Order...", .{});
        if (self.functionDeclarations.items.len != self.functionImplementations.items.len) {
            std.log.err("\nError: Function declarations and definitions do not match.", .{});
            return;
        }
    }

};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var analyzer = try CodeAnalyzer.init(allocator, .{.slice="./test_file.h"});

    try analyzer.extractFunctions();

    std.log.debug("{d} declarations!", .{analyzer.functionDeclarations.items.len});
    std.log.debug("{d} implementations!", .{analyzer.functionImplementations.items.len});

    analyzer.checkFunctionOrder();

    defer analyzer.deinit();
}
