# ZigTools Process Improvements 20260606

Generated from session analyses `session_20260531_181923_36cacce3` to `session_20260606_191941_2fa2cef4`, consolidating learnings and rules for future work.

---

## Priority 1: Version & API Compatibility (Most Frequent Issues)

### Zig 0.13.0 Specific Rules

```zig
// Build.zig API (Zig 0.13.0)
const exe = b.addExecutable(.{
    .name = "tool",
    .root_source_file = .{ .path = "src/tool.zig" },  // Direct path, no module needed
});

// File operations
const file = try fs.cwd().openFile("file.txt", .{ .mode = .write_only });
try file.seekFromEnd(0);  // Append mode: seek to end, then write

// Environment
const home = try std.process.getEnvVarOwned(allocator, "HOME") orelse
            try std.process.getEnvVarOwned(allocator, "USERPROFILE");

// Date formatting (no strftime)
// Must manually convert epoch to date components using std.time.epoch
```

---

## Priority 2: API & Documentation Verification

### Never Assume API Exists

- **Rule**: Always verify struct fields, functions, and types in the standard library before use
- **How**: Use `grep` on Zig std lib source, or check official documentation
- **Frequency**: 15+ occurrences

**Common Mistakes:**

- Assuming `.install_dir` exists on `InstallArtifact.Options`
- Assuming `addCopyFile` exists on Build
- Assuming `link_lto` exists on ExecutableOptions
- Assuming `.path` exists on LazyPath

**Correct Approach:**

```bash
# Search std lib for the correct type/field
grep -r "InstallArtifact" $(zig env --path)/lib/std/
```

### Build System Constraints

- **Rule**: `.src_path` and other build configuration fields require **comptime-known** values
- **Why**: Zig's build system uses compile-time reflection
- **Implication**: Cannot use runtime string concatenation in `.sub_path`

**Correct:**

```zig
// Comptime-known path
const my_module = b.addModule("name", .{
    .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/tools/nothing.zig" } },
});
```

**Incorrect:**

```zig
// Runtime concatenation - FAILS
const path = "src/tools/" ++ name ++ ".zig";
const my_module = b.addModule("name", .{
    .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = path } },  // Error!
});
```

### Type Annotations for Anonymous Structs

- **Rule**: When extracting anonymous struct literals to variables, use **explicit type annotations**
- **Why**: Anonymous structs create new types that may not match expected function parameters

---

## Priority 3: File & Folder Operations

### Always Verify Before Proceeding

- **Rule**: After any file operation, **verify** the file exists and has correct content
- **Frequency**: 10+ occurrences

**Checklist:**

1. After `write_file`: Run `dir filename` or `ls filename`
2. After `edit`: Use `read` to verify the change
3. Before committing: Run `git status`
4. Use actual file name from git status, not assumed name

### Scope Clarification

- **Rule**: **ALWAYS clarify scope** before implementing file/folder operations
- **Ask**: "Which specific files/folders?", "Can you show me the directory structure?"
- **Frequency**: 4+ occurrences

**Don't Assume:**

- "temporary folders" means Windows system temp (`%TEMP%`)
- Folder names don't include hidden dots (`.zig-cache` vs `zig-cache`)
- Your assumed filename matches what the user wants

### Windows-Specific File Operations

- **Rule**: Windows has different behaviors than Unix
- **Frequency**: 8+ occurrences

**File Discovery:**

```bash
# Windows: Use native commands
dir /s /b *.zig
dir /b /s analysis.md

# Don't use Unix tools on Windows
grep -r "pattern" .  # May not work as expected
```

**File Deletion:**

```batch
:: Suppress "file not found" errors
rmdir /s /q .zig-cache 2>nul
rmdir /s /q zig-out 2>nul
del bin\*.exe /Q 2> nul
del bin\*.pdb /Q 2> nul
```

**Path Separators:**

- Windows: Use backslash (`\`)
- Windows: Don't use forward slash (`/`) in batch files

### Hidden Folders

- **Rule**: **ALWAYS check for hidden folders** (starting with `.`)
- **Example**: Zig uses `.zig-cache`, not `zig-cache`
- **Verify**: Use `dir /a` on Windows to show all files including hidden

---

## Priority 4: Code Quality & Maintainability

### Avoid Over-Engineering

- **Rule**: Start simple, add complexity only when needed
- **Frequency**: 5+ occurrences
- **Example**: ToolUsageLogger reduced from 99 lines to 62 lines

### Limit Consecutive Edits

- **Rule**: After **3 failed attempts** on the same problem, **stop and research**
- **Why**: Trial-and-error without research wastes effort and causes user frustration
- **Frequency**: 3+ occurrences

### Extract Complex Expressions

- **Rule**: Extract complex expressions into **named local variables** before using in structs
- **Benefits**: Better readability, easier debugging, maintainability

**Before:**

```zig
const install = b.addInstallArtifact(exe, .{
    .dest_dir = .{ .override = .{ .custom = try std.fs.path.join(b.allocator, &[_][]const u8{ "..", output_dir }) } },
});
```

**After:**

```zig
const actual_target_folder = try std.fs.path.join(b.allocator, &[_][]const u8{ "..", output_dir });
const install = b.addInstallArtifact(exe, .{
    .dest_dir = .{ .override = .{ .custom = actual_target_folder } },
});
```

### Descriptive Naming

- **Rule**: Use function names that describe **what** the function does, not just **what it returns**
- **Example**: `formatTimestamp()` > `getTimestamp()` (conveys string formatting)

---

## Priority 5: Build System Options & Configuration

### Zig 0.13 Build Options

- **Rule**: `b.option()` **both declares AND retrieves** build options
- **Warning**: Calling `b.option()` multiple times with the same name causes **panic**
- **Solution**: Declare option **once** in `build()`, store in variable, pass to functions

**Correct:**

```zig
// In build()
const output_dir = b.option([]const u8, "output_dir", "bin");
addTool(b, output_dir);  // Pass as parameter
```

**Incorrect:**

```zig
// In addTool() - called multiple times
const output_dir = b.option([]const u8, "output_dir", "bin");  // PANIC on duplicate!
```

### Install Artifact Paths

- **Rule**: Install artifact `.custom` paths are **relative to `zig-out/`**, not project root
- **Solution**: Prepend `..` to reach project root

**Correct:**

```zig
const dest_path = try std.fs.path.join(allocator, &[_][]const u8{ "..", "bin" });
const install = b.addInstallArtifact(exe, .{
    .dest_dir = .{ .override = .{ .custom = dest_path } },
});
```

**Incorrect:**

```zig
// Installs to zig-out/bin/, not project root bin/
const install = b.addInstallArtifact(exe, .{
    .dest_dir = .{ .override = .{ .custom = "bin" } },
});
```

---

## Priority 6: Testing

### Update All Call Sites

- **Rule**: When changing a public API, **update ALL call sites** including tests
- **Frequency**: 3+ occurrences

### Graceful Test Skipping

- **Rule**: Tests should gracefully skip when environment requirements aren't met

```zig
const home = std.process.getEnvVarOwned(allocator, "HOME") orelse
            std.process.getEnvVarOwned(allocator, "USERPROFILE") orelse
            return error.Skip;
```

### Test Frequently

- **Rule**: Test Zig build script changes **immediately** after modification
- **Why**: Catch type errors and API mismatches early

---

## Priority 7: Error Handling

### Build Script Error Handling

- **Rule**: Error handling in build scripts **may differ** from regular Zig code
- **Research**: Check Zig version's build system documentation

### File Operations

- **Rule**: Always handle errors from filesystem operations

**Zig 0.13 Pattern:**

```zig
const dir = try fs.cwd().openDir("path", .{ .iterate = true });  // Must have .iterate = true
const walker = try dir.walk(allocator);
while (try walker.next()) |entry| {
    // entry.path is relative to walked directory
}
```

**Zig 0.13 Append Mode:**

```zig
const file = try fs.cwd().openFile("log.txt", .{ .mode = .write_only });
try file.seekFromEnd(0);  // Move to end
try file.writeAll("content");
```

---

## Priority 8: Respect User Constraints

### Never Modify Forbidden Files

- **Rule**: If user says "do not change X", **find alternative solutions** or accept limitations
- **Frequency**: 2+ occurrences
- **Example**: Don't modify `build.zig` if user explicitly forbids it

### Monitor User's Manual Commands

- **Rule**: When user executes commands manually, check if they've **already solved the problem**
- **Ask**: "I see you ran [command] - did this achieve what you needed?"

---

## Quick Reference Cards

### Before Starting Any Task

1. Check zig version
2. Clarify scope with user
3. Verify current state (dir, git status)
4. Research version-specific API

### When Writing Zig Code

1. Verify all struct fields exist in std lib
2. Check if values need to be comptime-known
3. Use explicit type annotations for anonymous structs
4. Limit to 3 consecutive edits without research

### When Working with Files

1. Ask: "Which specific files/folders?"
2. Check for hidden folders (.)
3. Verify file exists after creation
4. Check git status before committing

### Windows Batch Files

```batch
:: File discovery
dir /s /b *.zig

:: File deletion (suppress errors)
rmdir /s /q .zig-cache 2>nul
rmdir /s /q zig-out 2>nul
del bin\*.exe /Q 2> nul

:: Path separators
:: Use backslash: \
:: Don't use forward slash: /
```

---
