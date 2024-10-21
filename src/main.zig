const std = @import("std");
const stdtypes = @import("string.zig");
const file = @import("file.zig");
const utils = @import("utils.zig");

pub const FunctionDeclarationInfo = struct { 
    line_number: usize,
    offset:usize,
    pub fn init(line_number: usize, offset:usize) FunctionDeclarationInfo{
        return FunctionDeclarationInfo{.line_number = line_number,.offset = offset};
    }
};

pub const FunctionImplementationInfo = struct { 
    line_number: usize,
    offset:usize, 
    body: stdtypes.String,
    pub fn init(line_number: usize, offset:usize, body: stdtypes.String) FunctionImplementationInfo{
        return FunctionImplementationInfo{.line_number = line_number,.offset = offset,.body = body};
    } 
};

pub const CodeAnalyzer = struct { 
    fileData: file.FileData,
    functionDeclarations: std.ArrayList(stdtypes.StringUnmanaged), 
    functionImplementations: std.ArrayList(stdtypes.StringUnmanaged),
    functionDeclarationInfos: std.StringArrayHashMap(FunctionDeclarationInfo), 
    functionImplementationInfos: std.StringArrayHashMap(FunctionImplementationInfo), 
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator,filePath: stdtypes.StringUnmanaged) !CodeAnalyzer
    {
        const fileData = try file.read_file(allocator, filePath.slice);
        const functionDeclarations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionImplementations = std.ArrayList(stdtypes.StringUnmanaged).init(allocator);
        const functionDeclarationInfos = std.StringArrayHashMap(FunctionDeclarationInfo).init(allocator);
        const functionImplementationInfos = std.StringArrayHashMap(FunctionImplementationInfo).init(allocator);

        return CodeAnalyzer{.fileData = fileData,
        .functionDeclarations = functionDeclarations,
        .functionImplementations=functionImplementations,
        .functionDeclarationInfos=functionDeclarationInfos,
        .functionImplementationInfos=functionImplementationInfos,
        .allocator = allocator};
    }
    pub fn deinit(self:@This()) void
    {
        self.fileData.deinit();
    }
};
pub fn addDeclaration(analyzer: *CodeAnalyzer,declaration : []const u8,line_number: usize,offset: usize) !void
{
    try analyzer.functionDeclarations.append(stdtypes.StringUnmanaged.init(declaration));
    try analyzer.functionDeclarationInfos.put(declaration,FunctionDeclarationInfo.init(line_number, offset));
}
pub fn getDeclarationLength(code: [] const u8,offset: usize) usize
{
    var length : usize = 0;
    while(code[offset + length] != ';')
    {
        length += 1;
    }
    return length;
}
pub fn extractFunctionDeclarations(analyzer: *CodeAnalyzer) !void
{
    var line_number:usize = 0;

    while(analyzer.fileData.offset < analyzer.fileData.code.slice.len)
    {
        if(analyzer.fileData.current() == '\n')
        {
            line_number += 1;
            analyzer.fileData.offset += 1;
        
        }

        const token = utils.getToken(analyzer.fileData.code.slice, analyzer.fileData.offset);
        var stripedToken = stdtypes.StringUnmanaged{.slice = undefined}; 
        if(token[0] != ' ')
        {
            stripedToken = stdtypes.StringUnmanaged.init(try utils.skipWhiteSpace(token));

            std.log.debug("Token {s}",.{token});
            if(utils.startsWith(stripedToken.slice,"static") == true)
            {
                const length = getDeclarationLength(analyzer.fileData.code.slice, analyzer.fileData.offset);
                const declaration =try utils.skipWhiteSpace(analyzer.fileData.currentRange(length));
                try addDeclaration(analyzer,declaration,line_number,analyzer.fileData.offset);
                analyzer.fileData.offset += analyzer.fileData.currentRange(length).len;
            }else{
                analyzer.fileData.offset += token.len-1;
            }
        }else { analyzer.fileData.offset += 1;}
    }

    // for (analyzer.fileData.lines.items) |line|{
    //     const stripedLine = try utils.skipWhiteSpace(line.slice);
    //     if (utils.startsWith(stripedLine, "static") == true)
    //     {
    //         try addDeclaration(analyzer, stripedLine, line_number, offset);
    //     }
    //     offset += line.slice.len;
    //     line_number += 1;
    // }
}
pub fn addImplementation(analyzer: *CodeAnalyzer,declaration : []const u8,line_number: usize,offset: usize) !void
{
    const striped_line = try utils.skipWhiteSpace(declaration);
    
    try analyzer.functionImplementations.append(stdtypes.StringUnmanaged.init(striped_line));
    try analyzer.functionImplementationInfos.put(striped_line,FunctionImplementationInfo.init(line_number,offset,stdtypes.String.emptyInit()));
}
pub fn extractFunctionImplementations(analyzer: *CodeAnalyzer) !void
{
    var line_number:usize = 0;
    var offset:usize = 0;
    for (analyzer.fileData.lines.items) |line|{
        const stripedLine = try utils.skipWhiteSpace(line.slice);
        if (utils.startsWith(stripedLine, "inline") == true)
        {
            std.log.debug("Starts with inline",.{});
            try addImplementation(analyzer, stripedLine[6..], line_number, offset + line.slice.len - 1);
        }
        offset += line.slice.len + 1;

        line_number += 1;
    }
}
pub fn extractFunctionBody(analyzer: *CodeAnalyzer,declaration:stdtypes.StringUnmanaged) !void
{
    std.log.debug("extracting body...",.{});

    const striped_line = try utils.skipWhiteSpace(declaration.slice); 
    const info: FunctionImplementationInfo = analyzer.functionImplementationInfos.get(striped_line).?;

    var brace_count:usize = 1;
    var i = info.offset;

    while ( brace_count > 0 and i < analyzer.fileData.code.slice.len)
    {
        const current_char = analyzer.fileData.code.at(i); 
        if(current_char == '{')
        {
            brace_count += 1;
        }
        else if(current_char == '}')
        {
            brace_count -= 1;
        }
        i+= 1;
    }    

    const body = analyzer.fileData.code.slice[info.offset .. i-1];
    const value_ptr = analyzer.functionImplementationInfos.getPtr(striped_line).?;
    value_ptr.*.body = stdtypes.String.init(analyzer.allocator,body);
}
pub fn extractFunctions(analyzer: *CodeAnalyzer) !void
{
    try extractFunctionDeclarations(analyzer);
    try extractFunctionImplementations(analyzer);
    for (analyzer.functionImplementations.items) |declaration|
    {
        try extractFunctionBody(analyzer,declaration);
    }
    for(analyzer.functionImplementationInfos.values()) |implInfo|
    {
        std.log.debug("Function {d}",.{implInfo.line_number});
        std.log.debug("{s}",.{implInfo.body.slice});
    }
}
pub fn main() !void 
{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file_path = stdtypes.StringUnmanaged.init("./test_file.h");

    var analyzer = try CodeAnalyzer.init(allocator,file_path);

    try extractFunctions(&analyzer);

    for (analyzer.functionDeclarations.items) |declaration|
    {
        std.log.debug("{s}",.{declaration.slice});
    }
    for (analyzer.functionImplementations.items) |implementation|
    {
        std.log.debug("{s}",.{implementation.slice});
    }

    std.log.debug("{d} declarations!",.{analyzer.functionDeclarations.items.len});
    std.log.debug("{d} implementations!",.{analyzer.functionImplementations.items.len});




    defer analyzer.deinit();
}
