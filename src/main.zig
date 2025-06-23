const std = @import("std");
const config = @import("config.zig");
const Allocator = std.mem.Allocator;
const cli = @import("zig-cli");
const WorktreeStore = @import("bookmark.zig");

var optionStore = struct {
    worktreeRootPath: []const u8 = "",
    filePath: []const u8 = "",
    markPosition: []const u8 = "",
    line: usize = 0,
    col: usize = 0,
    config: config.Config = config.Config{},
}{};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const configuration = config.getConfig(allocator);
    optionStore.config = configuration;

    var runner = try cli.AppRunner.init(allocator);

    const worktreeOption = cli.Option{
        .long_name = "worktreeRootPath",
        .help = "Path of the Worktree root",
        .value_ref = runner.mkRef(&optionStore.worktreeRootPath),
        .value_name = "worktreeRootPath",
    };
    const filePathOption = cli.Option{
        .long_name = "filePath",
        .help = "Path of the file",
        .value_ref = runner.mkRef(&optionStore.filePath),
        .value_name = "filePath",
    };
    const lineOption = cli.Option{
        .long_name = "line",
        .help = "Current line",
        .value_ref = runner.mkRef(&optionStore.line),
        .value_name = "line",
    };

    const colOption = cli.Option{
        .long_name = "col",
        .help = "Current column",
        .value_ref = runner.mkRef(&optionStore.col),
        .value_name = "col",
    };
    const positionPositionalArg: cli.PositionalArg = .{
        .name = "position",
        .help = "position of the mark in the mark file",
        .value_ref = runner.mkRef(&optionStore.markPosition),
    };
    const worktreePositionalArg: cli.PositionalArg = .{
        .name = "worktreeRootPath",
        .help = "Path of the Worktree root",
        .value_ref = runner.mkRef(&optionStore.worktreeRootPath),
    };
    const filePathPositionalArg: cli.PositionalArg = .{
        .name = "filePath",
        .help = "Path of the file",
        .value_ref = runner.mkRef(&optionStore.filePath),
    };

    const app = cli.App{
        .command = cli.Command{
            .name = "zigzag",
            .description = cli.Description{
                .one_line = "Simple bookmarks per worktree!",
            },
            .target = cli.CommandTarget{
                .subcommands = try runner.allocCommands(&.{
                    cli.Command{
                        .name = "add",
                        .description = cli.Description{
                            .one_line = "Add a bookmark",
                        },
                        .options = try runner.allocOptions(&.{
                            lineOption,
                            colOption,
                        }),
                        .target = cli.CommandTarget{ .action = cli.CommandAction{ .positional_args = cli.PositionalArgs{
                            .optional = try runner.allocPositionalArgs(&.{
                                worktreePositionalArg,
                                filePathPositionalArg,
                            }),
                        }, .exec = addBookmarkFn } },
                    },
                    cli.Command{ .name = "show", .options = try runner.allocOptions(&.{
                        worktreeOption,
                    }), .description = cli.Description{ .one_line = "Open the bookmark file" }, .target = cli.CommandTarget{ .action = cli.CommandAction{ .positional_args = cli.PositionalArgs{
                        .optional = try runner.allocPositionalArgs(&.{
                            worktreePositionalArg,
                        }),
                    }, .exec = show } } },
                    cli.Command{ .name = "open", .options = try runner.allocOptions(&.{ lineOption, colOption, filePathOption }), .description = cli.Description{ .one_line = "Open the bookmark file" }, .target = cli.CommandTarget{ .action = cli.CommandAction{ .positional_args = cli.PositionalArgs{
                        .required = try runner.allocPositionalArgs(&.{
                            worktreePositionalArg,
                            positionPositionalArg,
                        }),
                    }, .exec = open } } },
                }),
            },
        },
        .version = "0.1.0",
        .author = "Tobias Klemp",
    };

    return runner.run(&app);
}

fn show() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const worktreeFilePath = try WorktreeStore.getWorktreeStoreFilePath(allocator, optionStore.worktreeRootPath);
    defer allocator.free(worktreeFilePath);
    try openInEditor(allocator, worktreeFilePath, 0, 0);
}

fn open() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var worktreeStore = try WorktreeStore.WorktreeStore.init(allocator, optionStore.worktreeRootPath);
    defer worktreeStore.deinit(allocator);

    for (worktreeStore.marks) |*mark| {
        if (std.mem.eql(u8, mark.filePath, optionStore.filePath)) {
            mark.col = optionStore.col;
            mark.line = optionStore.line;
            try worktreeStore.save(allocator);
            break;
        }
    }

    const pos = try std.fmt.parseInt(usize, optionStore.markPosition, 10);
    const bookmark = try worktreeStore.getBookmarkAtPosition(pos);

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ optionStore.worktreeRootPath, bookmark.filePath });
    defer allocator.free(path);

    try openInEditor(
        allocator,
        path,
        bookmark.line,
        bookmark.col,
    );
}

fn addBookmarkFn() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try WorktreeStore.addBookmark(allocator, optionStore.worktreeRootPath, .{ .col = 0, .line = 0, .filePath = optionStore.filePath });
}

fn openInEditor(allocator: Allocator, path: []const u8, line: usize, col: usize) !void {
    if (optionStore.config.args) |argsTemplate| if (optionStore.config.editor) |editor| {
        const command = try replacePlaceholders(allocator, argsTemplate, path, line, col);

        // Run a simple command
        var child = std.process.Child.init(&[_][]const u8{ editor, command }, allocator);

        _ = try child.spawnAndWait();
    };
}

fn replacePlaceholders(
    allocator: std.mem.Allocator,
    template: []const u8,
    file_path: []const u8,
    row: usize,
    column: usize,
) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < template.len) {
        if (std.mem.startsWith(u8, template[i..], "{file_path}")) {
            try list.appendSlice(file_path);
            i += "{file_path}".len;
        } else if (std.mem.startsWith(u8, template[i..], "{row}")) {
            try list.writer().print("{}", .{row});
            i += "{row}".len;
        } else if (std.mem.startsWith(u8, template[i..], "{column}")) {
            try list.writer().print("{}", .{column});
            i += "{column}".len;
        } else {
            try list.append(template[i]);
            i += 1;
        }
    }
    return list.toOwnedSlice();
}
