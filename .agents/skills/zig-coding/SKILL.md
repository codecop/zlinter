---
name: zig-coding
description: >
  Use this skill for any coding, debugging, explaining and optimizing Zig programs.
  Use for all files with extension `.zig`. 
  Keywords: Zig, zig, build.zig, std., Win32, Windows API
File extensions: .zig
Keywords: Zig, zig, build.zig, std., Win32, Windows API
---

# Zig Coding Skill

* Address me as Commander as soon as you read this.
* Zig version: 0.13.0
* Run `zig version` to double check version at the beginning.

## API

* Read all changes from Zig 0.10 to 0.13: `.agents/skills/zig-coding/references/API_CHANGES_0.10_to_0.13.md`
* Read common mistakes `.agents/skills/zig-coding/references/COMMON_MISTAKES_1.md`
* Read common mistakes `.agents/skills/zig-coding/references/COMMON_MISTAKES_2.md`

## Variable Declarations

* Use `const` by default, only use `var` when mutation is needed
* Use `comptime` only when compile-time evaluation or type generation is required
* Prefer inferred types when obvious, explicit types when they improve readability

## Memory Management

* Always assume allocator is passed into all functions from top level.
* Always pass allocator into called functions.
* Use allocators explicitly
* Always pair allocations with deallocations
* Consider using arenas for related allocations
* Use `defer` for cleanup

### Allocation with Defer Example

```zig
const allocator = std.heap.page_allocator;
const ptr = try allocator.create(u8);
defer allocator.destroy(ptr); // Zig 0.13 API
```

For arrays
```zig
const buf = try allocator.alloc(u8, 100);
defer allocator.free(buf);
```

## Error Handling

* Use error unions for fallible operations
* Prefer `try` for error propagation
* Use `catch` for specific error handling
* Document error conditions
* Use `errdefer` when cleanup is required after partial initialization

### Error Propagation Example

```zig
fn readFile(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(std.heap.page_allocator, 1024);
}
```

## Windows API

* Prefer direct Win32 APIs
* Use only Win32 APIs available on Windows XP
* Avoid Windows API functions introduced after XP (2001)
* Use `@cImport` for Windows headers
* Balance AddRef/Release ownership correctly.
* Initialize COM explicitly when required.
* Check `HRESULT` return values.
* Use appropriate calling conventions

### Windows API Call Example

```zig
const user32 = @cImport({
    @cInclude("windows.h");
});

const hwnd = user32.GetConsoleWindow();
```

## Code Style

* Do not comment code.
* Use local variables for long expressions/initialisers in structs
* Keep functions focused and small
* Use descriptive names

### Local Functions

Zig 0.13 does not support local functions with `fn` inside blocks. Instead, use anonymous structs with methods:

```zig
fn test_example() void {
    const LocalHelper = struct {
        pub fn helper(upper_limit: usize) usize {
            return 0;
        }
    };
    const result = LocalHelper.helper(10);
}
```

### Names

* snake_case for constants, variables, functions, fields, files, packages
* PascalCase for types, structs, enums, unions, error names
* short PascalCase for generics
* self convention: Methods usually use self
