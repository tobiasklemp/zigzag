const std = @import("std");
const process = std.process;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const json = std.json;
const builtin = @import("builtin");

pub fn getConfig(allocator: Allocator) Config {
    const path = getConfigPath(allocator) catch return Config{};

    const config = loadConfig(allocator, path) catch return Config{};
    return config;
}

fn loadConfig(allocator: Allocator, path: []const u8) !Config {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            // File doesn't exist, return default config
            return Config{};
        },
        else => return err,
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    var parsed = try json.parseFromSlice(Config, allocator, buffer, .{});
    defer parsed.deinit();

    // Deep copy the parsed config
    const result = Config{
        .editor = if (parsed.value.editor) |cmd| try allocator.dupe(u8, cmd) else null,
    };

    return result;
}

pub const Config = struct {
    editor: ?[]const u8 = "zed",
    args: ?[]const u8 = "{file_path}:{row}:{column}",

    // pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
    //     if (self.editor) |editor| allocator.free(editor);
    //     if (self.args) |args| allocator.free(args);
    // }
};

fn getConfigPath(allocator: Allocator) ![]const u8 {
    const customConfigPathKey = "ZIGZAG_CONFIG_PATH";

    const home_dir = if (builtin.os.tag == .windows)
        std.process.getEnvVarOwned(allocator, "USERPROFILE") catch
            try std.process.getEnvVarOwned(allocator, "HOMEDRIVE") // + HOMEPATH
    else
        std.process.getEnvVarOwned(allocator, "HOME") catch return "";

    defer allocator.free(home_dir);
    if (process.getEnvVarOwned(allocator, customConfigPathKey)) |value| {
        if (value.len > 0 and value[0] == '~') {
            const result = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home_dir, value });
            return result;
        }

        return value;
    } else |err| switch (err) {
        else => {},
    }

    switch (builtin.os.tag) {
        .windows => {
            const result = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home_dir, "AppData/Local/zigzag/config.json" });
            return result;
        },
        else => {
            const result = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home_dir, ".config/zigzag/config.json" });
            return result;
        },
    }
}
