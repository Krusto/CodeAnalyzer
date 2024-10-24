const std = @import("std");
const algorithm = @import("algorithm.zig");
const stdtypes = @import("stdtypes.zig");

pub const FunctionDeclarationInfo = struct {
    lineNumber: usize,
    offset: usize,
    pub fn init(lineNumber: usize, offset: usize) FunctionDeclarationInfo {
        return FunctionDeclarationInfo{ .lineNumber = lineNumber, .offset = offset };
    }
};

pub const FunctionImplementationInfo = struct {
    lineNumber: usize,
    offset: usize,
    body: stdtypes.String,
    start_line: usize,
    end_line: usize,
    pub fn init(lineNumber: usize, offset: usize, body: stdtypes.String, start_line: usize, end_line: usize) FunctionImplementationInfo {
        return FunctionImplementationInfo{ .lineNumber = lineNumber, .offset = offset, .body = body, .start_line = start_line, .end_line = end_line };
    }
};

pub const CodeAnalyzer = struct {
    const Self = @This();

    fileData: stdtypes.FileData,
    functionDeclarations: std.ArrayList(stdtypes.StringUnmanaged),
    functionImplementations: std.ArrayList(stdtypes.StringUnmanaged),
    functionDeclarationInfos: std.StringArrayHashMap(FunctionDeclarationInfo),
    functionImplementationInfos: std.StringArrayHashMap(FunctionImplementationInfo),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, filePath: stdtypes.StringUnmanaged) !CodeAnalyzer {
        const fileData = stdtypes.read_file(allocator, filePath.slice) catch |err|
            {
            std.log.err("Error opening File!.", .{});
            return err;
        };
        const functionDeclarations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionImplementations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionDeclarationInfos = std.StringArrayHashMap(FunctionDeclarationInfo).init(allocator);
        const functionImplementationInfos = std.StringArrayHashMap(FunctionImplementationInfo).init(allocator);

        return CodeAnalyzer{ .fileData = fileData, .functionDeclarations = functionDeclarations, .functionImplementations = functionImplementations, .functionDeclarationInfos = functionDeclarationInfos, .functionImplementationInfos = functionImplementationInfos, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.fileData.deinit();
    }

    pub fn get_token(self: *Self) []const u8 {
        var len: usize = 0;
        var current: u8 = 0;

        var str = self.fileData.code.slice;
        const offset = self.fileData.offset;

        const non_literals = [_]u8{ ' ', ';', '}', '{', '(', ')', '.', ',', '\n', '\r' };
        while (algorithm.findInArray(&non_literals, current) == false) {
            if (offset + len >= str.len)
                break;
            current = str[offset + len];
            len += 1;
        }
        if (len > 1)
            len -= 1;
        return str[offset .. offset + len];
    }

    pub fn is_token_valid(token: []const u8) bool {
        return token.len != 0;
    }

    pub fn is_token_space(token: []const u8) bool {
        return token[0] == ' ';
    }

    pub fn get_current_declaration_length(self: *Self) usize{
        return Self.get_declaration_length(self.fileData.code.slice, self.fileData.offset);
    }

    pub fn get_declaration_length(code: []const u8, offset: usize) usize {
        var length: usize = 0;
        while (code[offset + length] != ';' and code[offset + length] != '{') {
            length += 1;
        }
        return length;
    }
    
    const extraction_result = struct {
        checkStatus: ?bool,
        token: ?stdtypes.StringUnmanaged,
        rawTokenLen: ?usize, 
    };

    pub fn pre_extract(self:*Self,lineNumber: *usize) extraction_result {
        if (self.is_end_of_line()) {
            lineNumber.* += 1;
            self.fileData.offset += 1;
        }
        const raw_token = self.get_token();
        
        if (!Self.is_token_valid(raw_token))
            return extraction_result{.checkStatus = false,.token = null,.rawTokenLen = null};

        if (Self.is_token_space(raw_token)) {
            self.fileData.offset += 1;
            return extraction_result{.checkStatus = true,.token = null,.rawTokenLen = null};
        }
        const token = stdtypes.StringUnmanaged.init(try algorithm.skipWhiteSpace(raw_token));

        return extraction_result{.checkStatus = null,.token = token,.rawTokenLen = raw_token.len};
    }

    pub fn add_declaration(self: *Self, declaration: []const u8, lineNumber: usize, offset: usize) !void {
        try self.functionDeclarations.append(stdtypes.StringUnmanaged.init(declaration));
        try self.functionDeclarationInfos.put(declaration, FunctionDeclarationInfo.init(lineNumber, offset));
    }
    pub fn extract_function_declaration(self: *Self,lineNumber:*usize,previousToken:*stdtypes.StringUnmanaged) !bool {

        const result = self.pre_extract(lineNumber);
        if(result.checkStatus != null) { return result.checkStatus.?; }

        const token = result.token.?;
        
        if (token.startsWith( "static") == true and
            previousToken.startsWith("inline") == false)
        {
            const length = self.get_current_declaration_length();
            const function_head = self.fileData.getRange(length);
            const stripped_function_head = try function_head.lstrip();

            try self.add_declaration(stripped_function_head.slice, lineNumber.*, self.fileData.offset);
            self.fileData.offset += function_head.len;
        } else {
            self.fileData.offset += result.rawTokenLen.?;
        }
        previousToken.* = token;
        return true;
    }

    pub fn extract_function_declarations(self: *Self) !void {
        var lineNumber: usize = 1;
        var previousToken = stdtypes.StringUnmanaged.init("");

        var continueExtraction: bool = true;

        while (continueExtraction and self.fileData.offset < self.fileData.code.slice.len) {
            continueExtraction = try self.extract_function_declaration(&lineNumber,&previousToken);
        }
        self.fileData.offset = 0;
    }

    pub fn add_implementation(self: *Self, declaration: []const u8, lineNumber: usize, offset: usize) !void {
        const stripedLine = try algorithm.skipWhiteSpace(declaration);

        try self.functionImplementations.append(stdtypes.StringUnmanaged.init(stripedLine));
        try self.functionImplementationInfos.put(stripedLine, FunctionImplementationInfo.init(lineNumber, offset, stdtypes.String.emptyInit(), 0, 0));
    }

    pub fn extract_all_functions_body(self: *Self) !void {
        for (self.functionImplementations.items) |declaration| {
            try self.extract_function_body(declaration);
        }
    }

    pub fn extract_function_body(self: *Self, declaration: stdtypes.StringUnmanaged) !void {
        const stripedLine = try algorithm.skipWhiteSpace(declaration.slice);
        const info: FunctionImplementationInfo = self.functionImplementationInfos.get(stripedLine).?;

        var braceCount: usize = 1;
        var i = info.offset + 1;

        while (braceCount > 0 and i < self.fileData.code.slice.len) {
            const current_char = self.fileData.code.at(i);
            if (current_char == '{') {
                braceCount += 1;
            } else if (current_char == '}') {
                braceCount -= 1;
            }
            i += 1;
        }

        const body = self.fileData.code.slice[info.offset..i];
        const value_ptr = self.functionImplementationInfos.getPtr(stripedLine).?;
        value_ptr.*.body = stdtypes.String.init(self.allocator, body);
    }
    
    pub fn is_end_of_line(self: *Self) bool {
        return self.fileData.current() == '\n';
    }

    pub fn extract_function_implementation_info(self: *Self, lineNumber:*usize) !bool {

        const result = self.pre_extract(lineNumber);
        if(result.checkStatus != null) { return result.checkStatus.?; }

            const token = result.token.?;

            if (token.startsWith("inline") == true) {

            const length = self.get_current_declaration_length();
            const function_head = self.fileData.getRange(length);
            const stripped_function_head = try function_head.lstrip();
            const inlineless_function_head = try stripped_function_head.substr(6);

            try self.add_implementation(inlineless_function_head.slice, lineNumber.*, self.fileData.offset);
            self.fileData.offset += function_head.len;
        } else {
            self.fileData.offset += result.rawTokenLen.?;
        }  
        return true;
    }
    pub fn extract_function_implementation_infos(self: *Self) !void {
        var lineNumber: usize = 1;
        var continueExtaction: bool = true;

        while (continueExtaction and self.fileData.offset < self.fileData.code.slice.len) {
            continueExtaction = try self.extract_function_implementation_info(&lineNumber);
        }
        self.fileData.offset = 0;
    }

    pub fn extract_function_implementations(self: *Self) !void {
        try self.extract_function_implementation_infos();
        try self.extract_all_functions_body();
    }

    pub fn extract_functions(self: *Self) !void {
        try self.extract_function_declarations();
        try self.extract_function_implementations();
    }

    pub fn check_function_order(self: *Self) void {
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

    var analyzer = try CodeAnalyzer.init(allocator, stdtypes.StringUnmanaged.init("./test_file2.h" ));

    try analyzer.extract_functions();

    std.log.debug("{d} declarations!", .{analyzer.functionDeclarations.items.len});
    std.log.debug("{d} implementations!", .{analyzer.functionImplementations.items.len});

    analyzer.check_function_order();

    defer analyzer.deinit();
}
