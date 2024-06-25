const std = @import("std");

const help = @embedFile("bf/help.bf");
const version = @embedFile("bf/version.bf");
const no_program = @embedFile("bf/no_program.bf");
const open_error = @embedFile("bf/open_error.bf");
const newline = "+++[>+++<-]>+.";

var allocator: std.mem.Allocator = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();

    defer {
        const gpa_deinit = gpa.deinit();
        if (gpa_deinit == .leak) std.log.err("gpa leaked!", .{});
    }

    var program: []const u8 = "";
    var filename: ?[]const u8 = null;

    var args = std.process.args();
    _ = args.skip();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h")) {
            try run(help);
            try run(newline);
            try run(version);
            return;
        } else if (std.mem.eql(u8, arg, "-v")) {
            try run(version);
            return;
        } else if (std.mem.eql(u8, arg, "-f")) {
            filename = args.next();
        } else {
            if (filename == null) {
                program = arg;
                break;
            }
        }
    }

    if (filename != null) {
        const file = std.fs.cwd().openFile(filename.?, .{}) catch {
            try run(open_error);
            return;
        };
        defer file.close();

        program = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    }
    defer if (filename != null) allocator.free(program);

    if (program.len > 0) {
        try run(program);
    } else {
        try run(no_program);
        try run(newline);
        try run(help);
        try run(newline);
        try run(version);
    }
}

fn run(program: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const memory = try allocator.alloc(u8, 30000);
    @memset(memory, 0x00);
    defer allocator.free(memory);

    var ip: usize = 0;
    var dp: usize = 0;

    while (ip < program.len) {
        switch (program[ip]) {
            '>' => dp += 1,
            '<' => dp -= 1,
            '+' => memory[dp] = @addWithOverflow(memory[dp], 1)[0],
            '-' => memory[dp] = @subWithOverflow(memory[dp], 1)[0],
            '.' => try stdout.writeByte(memory[dp]),
            ',' => memory[dp] = try stdin.readByte(),
            '[' => if (memory[dp] == 0) {
                ip = try findMatchingBracket(program, ip, false);
            },
            ']' => if (memory[dp] != 0) {
                ip = try findMatchingBracket(program, ip, true);
            },
            else => {},
        }

        ip += 1;
    }
}

fn findMatchingBracket(program: []const u8, ip: usize, reverse: bool) !usize {
    const open: u8 = if (reverse) ']' else '[';
    const close: u8 = if (reverse) '[' else ']';

    var brackets = std.ArrayList(usize).init(allocator);
    defer brackets.deinit();

    var pointer = ip;

    try brackets.append(pointer);
    while(true) {
        if (reverse) pointer -= 1 else pointer += 1;

        if (program[pointer] == open) {
            try brackets.append(pointer);
        } else if (program[pointer] == close) {
            _ = brackets.popOrNull() orelse return error.UnmatchedBracket;
            if (brackets.items.len == 0) return pointer;
        }

        if (pointer == 0 or pointer == program.len - 1) return error.UnmatchedBracket;
    }
}