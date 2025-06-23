<p align="center">
  <img src="https://raw.githubusercontent.com/tobiasklemp/zigzag/main/assets/logo_zigzag.png" alt="zigzag logo" width="120" />
</p>

<p align="center">
  <b>CLI tool to bookmark files and open them in your editor of choice. Inspired by <a href="https://github.com/ThePrimeagen/harpoon">Harpoon</a></b><br>
  <a href="https://github.com/tobiasklemp/zigzag/releases"><img src="https://img.shields.io/github/v/release/tobiasklemp/zigzag" alt="Latest Release"></a>
  <a href="https://ziglang.org/"><img src="https://img.shields.io/badge/zig-0.12.0-orange" alt="zig"></a>
</p>

---

## ✨ Features

- 📑 **Bookmark files** (with line and column) per worktree
- ⚡ **Open bookmarks** in your favorite editor (default: [Zed](https://zed.dev))
- 🛠️ **Configurable** editor and arguments (JSON config)
- 🖥️ **Simple CLI** with add, show, and open commands
- 🧩 **Zed integration** via tasks

---

## Disclaimer

This is a small weekend project and I'm fairly new to zig. This repo is a hot mess i guess. For now it does what i need it to do. Hopefully zed gets a more comprehensive extension api that allows to do stuff like this soon.
The task approach works but it is not ideal. Launching a task takes aprox 500ms, zigzag does its work in a few ms, so a native extension in zed will most certainly be more responsive.

---

## 🚀 Quick Start

### 1. **Install**

Download a release from [GitHub Releases](https://github.com/tobiasklemp/zigzag/releases) or build from source:

```sh
zig build -Drelease=fast
cp zig-out/bin/zigzag /usr/local/bin/
```

### 2. **Bookmark a File**

```sh
zigzag add <worktreeRootPath> <filePath> --line <line> --col <column>
```

### 3. **Show Bookmarks**

```sh
zigzag show <worktreeRootPath>
```

### 4. **Open a Bookmark**

```sh
zigzag open <worktreeRootPath> <position> --filePath <filePath> --line <line> --col <column>
```

---

## 📝 Usage

### **Commands**

| Command | Description | Example |
|---------|-------------|---------|
| `add`   | Add a bookmark for a file (optionally with line/col) | `zigzag add ~/project src/main.zig --line 42 --col 7` |
| `show`  | Show the bookmarks file for a worktree | `zigzag show ~/project` |
| `open`  | Open a bookmark in your editor. If you provide `filePath`, `line`, and `col` and the file has a bookmark, zigzag will save your current position, so next time you open that file, you return to your last location. | `zigzag open ~/project 0 --filePath src/main.zig --line 42 --col 7` |

### **Smart Bookmark Positioning**

When you use the `open` command and provide a `filePath`, `line`, and `col`, **zigzag** will:

- **Save your current position** for that file in the bookmark.
- The next time you open that file with zigzag, you’ll be returned to your last saved location (line and column).
- This makes it easy to jump back to exactly where you left off in any bookmarked file!

**Example:**

```sh
zigzag open ~/project 0 --filePath src/main.zig --line 42 --col 7
```

- This will open `src/main.zig` at line 42, column 7 in your editor.
- zigzag will remember this position for the next time you open this bookmark.

---

## ⚙️ Configuration

By default, zigzag uses **Zed** as the editor.
You can override this by creating a JSON config file at `~/.config/zigzag/config.json`:

```json
{
  "editor": "code",
  "args": "{file_path}:{row}:{column}"
}
```

- **editor**: The command to launch your editor (must be in your PATH)
- **args**: Arguments to pass to the editor.
  Use `{file_path}`, `{row}`, `{column}` as placeholders.

**Default config:**
```json
{
  "editor": "zed",
  "args": "{file_path}:{row}:{column}"
}
```

---

## 🧩 Zed Integration

Add these tasks to your `.zed/tasks.json` for seamless workflow:

```json
[
  {
    "label": "Show bookmarks",
    "command": "zigzag show $ZED_WORKTREE_ROOT"
  },
  {
    "label": "Add bookmark",
    "command": "zigzag add",
    "args": ["$ZED_WORKTREE_ROOT", "$ZED_RELATIVE_FILE"]
  },
  {
    "label": "Open bookmark 1",
    "command": "zigzag open",
    "args": [
      "$ZED_WORKTREE_ROOT",
      "0",
      "--filePath $ZED_RELATIVE_FILE",
      "--line $ZED_ROW",
      "--col $ZED_COLUMN"
    ]
  }
  // ...add more for other bookmarks
]
```

Then you can add keymaps for the tasks:

```json
...
      "space h e": ["task::Spawn", { "task_name": "Show bookmarks" }],
      "space h a": ["task::Spawn", { "task_name": "Add bookmark" }],
      "space 1": ["task::Spawn", { "task_name": "Open bookmark 1" }],
...
```

## 🛠️ Advanced

- **Bookmarks are stored per worktree** for easy project-based navigation.
- **Editor command is fully customizable** via config.
- **Supports any editor** that can open files from the command line.

---

## 👤 Author

- **Tobias Klemp**
  [@tobiasklemp](https://github.com/tobiasklemp)

---

## 📄 License

MIT

---

<p align="center">
  <b>zigzag</b> — Simple bookmarks per worktree!
</p>
