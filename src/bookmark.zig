const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;
const File = fs.File;
const Dir = fs.Dir;

const ArrayList = std.ArrayList;

pub const Bookmark = struct { filePath: []const u8, line: usize, col: usize };
pub const WorktreeStore = struct {
    marks: []Bookmark,
    file: File,

    pub fn init(allocator: Allocator, worktreeRootPath: []const u8) !WorktreeStore {
        const appDataDir = try fs.getAppDataDir(allocator, "zigzag");
        defer allocator.free(appDataDir);

        const filePath = try getWorktreeStoreFilePath(allocator, worktreeRootPath);
        defer allocator.free(filePath);

        const cwd = fs.cwd();

        if (cwd.openFile(filePath, .{ .mode = .read_write })) |file| {
            const fileSize = (try file.stat()).size;
            if (fileSize == 0) {
                return WorktreeStore{
                    .marks = &[_]Bookmark{},
                    .file = file,
                };
            }
            const buffer = try allocator.alloc(u8, fileSize);
            defer allocator.free(buffer);

            _ = try file.readAll(buffer);

            if (buffer.len == 0) {
                return error.Unexpected;
            }

            const marks = try parseBookmarks(allocator, buffer);

            return WorktreeStore{
                .marks = marks.items,
                .file = file,
            };
        } else |err| switch (err) {
            File.OpenError.FileNotFound => {
                try Dir.makePath(cwd, appDataDir);
                const file = try fs.createFileAbsolute(filePath, .{ .truncate = true });

                const worktreeStore = WorktreeStore{ .marks = &[_]Bookmark{}, .file = file };

                return worktreeStore;
            },
            else => {
                return error.Unexpected;
            },
        }
    }

    pub fn save(self: *WorktreeStore, allocator: Allocator) !void {
        const joined = try join(allocator, self.marks);
        try self.file.setEndPos(0);
        try self.file.seekTo(0);
        try self.file.writeAll(joined);
    }

    pub fn deinit(self: *WorktreeStore, allocator: Allocator) void {
        allocator.free(self.marks);
        self.file.close();
    }

    pub fn getBookmarkAtPosition(self: *WorktreeStore, position: usize) !Bookmark {
        return self.marks[position];
    }

    pub fn addBookmark(self: *WorktreeStore, allocator: Allocator, bookmark: Bookmark) !void {
        var list = try ArrayList(Bookmark).initCapacity(allocator, 0);
        defer list.deinit(allocator);
        for (self.marks) |mark| {
            try list.append(allocator, mark);
        }
        try list.append(allocator, bookmark);
        self.marks = list.items;
        try self.save(allocator);
    }
};

pub fn join(allocator: Allocator, list: []Bookmark) ![]const u8 {
    var marks = try std.ArrayList(Bookmark).initCapacity(allocator, 0);
    defer marks.deinit(allocator);
    for (list) |mark| {
        try marks.append(allocator, mark);
    }
    var joined = try std.ArrayList(u8).initCapacity(allocator, 0);
    for (marks.items) |item| {
        try joined.appendSlice(allocator, item.filePath);
        const appendix = try std.fmt.allocPrint(allocator, ":{d}:{d}\n", .{ item.line, item.col });
        try joined.appendSlice(allocator, appendix);
    }
    return try joined.toOwnedSlice(allocator);
}

pub fn addBookmark(allocator: Allocator, worktreeRootPath: []const u8, bookmark: Bookmark) !void {
    if (worktreeRootPath.len == 0) {
        std.debug.print("ne ", .{});
        return;
    }
    var store = try WorktreeStore.init(allocator, worktreeRootPath);
    defer store.deinit(allocator);

    try store.addBookmark(allocator, bookmark);
}

/// Function to create a base64 representation of a filepath
pub fn encodeFilePathToBase64(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    const encoded_len = std.base64.url_safe.Encoder.calcSize(file_path.len);
    const encoded = try allocator.alloc(u8, encoded_len);

    const result = std.base64.url_safe.Encoder.encode(encoded, file_path);
    return result;
}

fn parseBookmarks(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Bookmark) {
    var list = try std.ArrayList(Bookmark).initCapacity(allocator, 0);

    var lines = std.mem.splitSequence(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue; // skip empty lines

        var parts = std.mem.splitSequence(u8, line, ":");
        const filePath = parts.next() orelse continue;
        const lineStr = parts.next() orelse continue;
        const colStr = parts.next() orelse continue;

        const lineNum = try std.fmt.parseInt(u8, lineStr, 10);
        const colNum = try std.fmt.parseInt(u8, colStr, 10);

        // Duplicate filePath to own the memory
        const filePathCopy = try allocator.dupe(u8, filePath);

        try list.append(allocator, Bookmark{
            .filePath = filePathCopy,
            .line = lineNum,
            .col = colNum,
        });
    }
    return list;
}

pub fn getWorktreeStoreFilePath(allocator: Allocator, worktreeRootPath: []const u8) ![]u8 {
    const appDataDir = try fs.getAppDataDir(allocator, "zigzag");
    defer allocator.free(appDataDir);

    const sanitizedPath = try encodeFilePathToBase64(allocator, worktreeRootPath);
    defer allocator.free(sanitizedPath);

    return try std.fmt.allocPrint(allocator, "{s}/{s}.txt", .{ appDataDir, sanitizedPath });
}
