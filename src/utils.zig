const std = @import("std");
pub fn skipWhiteSpace(data:[]const u8) ![]const u8
{
    var index:u32 = 0;
    while(index < data.len) : (index+=1)
    {
        if(data[index] != ' ') break;
    }
    return data[index..];
}
pub fn startsWith(str:[]const u8,value:[]const u8) bool
{
    var result = true;
    if(value.len > str.len)
    {
        result = false;
    }
    else
    {
        var index: usize = 0;
        while(index < value.len):(index+=1)
        {
            if(str[index] != value[index]) { result = false;break;}
        }
    }
    return result;
}
pub fn findInArray(arr:[]const u8,value:u8) bool
{
    for(arr) |arrValue|
    {
        if(arrValue == value)
        {
            return true;
        }
    }
    return false;
}
pub fn getToken(str:[]const u8,offset:usize) []const u8
{
    var len:usize = 0;
    var current : u8 = 0;

    const non_literals = [_]u8{' ',';','}','{','(',')','.',',','\n','\r'};
    while(findInArray(&non_literals, current) == false)
    {
        if(offset + len >= str.len)
            break;
        current = str[offset + len];
        len += 1;
    }
    if(len > 1)
        len-=1;
    return str[offset..offset+len];
}