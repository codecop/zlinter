# ZigTools Process Improvements 20260801

Generated from session analyses `session_20260707_...` to `session_20260801_...`, consolidating learnings and rules for future work.

---

## Priority 1: Zig 0.13 Language Specifics

### Type Casting and Conversions

- **Rule**: Use `@as` **only for exact type matches without information loss**. For potentially lossy conversions (e.g., `u16` to `u8`), use `@intCast` instead.
- **Why**: `@as` performs a bit pattern reinterpretation and will fail at compile time if types don't match exactly. `@intCast` handles numeric conversions with potential truncation.
- **Frequency**: High

**Correct:**

```zig
const small: u8 = @intCast(result);  // u16 -> u8, potentially lossy
const same: u16 = @as(u16, value);   // Same size, no information loss
```

**Incorrect:**

```zig
const small: u8 = @as(u8, result);  // Compile error if result is u16
```

---

### Comptime-Only Operations

- **Rule**: Array multiplication (`**`) is a **comptime-only** operation. Cannot be used with runtime-dependent values.
- **Why**: Zig's array multiplication requires the multiplier to be known at compile time.
- **Solution**: Use explicit fixed-size array types like `[N]T` instead.

**Correct:**

```zig
const arr: [10]u8 = .{0} ** 10;
```

**Incorrect:**

```zig
const size: usize = getSize();
const arr = .{0} ** size;  // Compile error: size is not comptime-known
```

- **Rule**: All format strings in `std.fmt.*` functions must be **known at compile time** (comptime). Runtime-determined format strings are not supported.

---

### Format Specifiers

- **Rule**: `std.fmt` requires **explicit type specifiers** for slices and arrays. Never use `{}` for slices.
- **Why**: Zig's format strings require explicit type information.

**Correct:**

```zig
std.debug.print("String: {s}, Int: {d}, Hex: {X}", .{ "hello", 42, 0xff });
```

**Incorrect:**

```zig
std.debug.print("Value: {}", .{some_slice});  // Compile error
```

- **Rule**: Zig 0.13 does **not support** the 'O' format specifier for octal.
- **Solution**: Implement manual octal conversion using arithmetic: `value / 64`, `(value % 64) / 8`, `value % 8`.

- **Rule**: Use `{X:0>2}` for uppercase hex, `{x:0>2}` for lowercase hex. Pay attention to case requirements in formatting.

---

### Struct and Type Rules

- **Rule**: Methods that modify state require **mutable receivers** (`*Type` not `*const Type`).
- **Why**: Zig enforces mutability at the type system level.

**Correct:**

```zig
pub fn modify(self: *Type) void {
    self.value += 1;
}
```

**Incorrect:**

```zig
pub fn modify(self: *const Type) void {
    self.value += 1;  // Compile error: cannot modify const
}
```

- **Rule**: Struct methods can be type-level (static) without `self` parameter, which can be passed as function pointers. Bound methods (with self parameter) cannot be passed as simple function pointers.

- **Rule**: Method calls on value types automatically take the address. `value.method()` is equivalent to `(&value).method()`.

- **Rule**: In Zig, you **cannot reference a type by name in its own method signatures** during definition. Use forward declarations or restructure the code.

- **Rule**: Type aliases inside structs must be **separated from field declarations**. Mixing type declarations and field declarations in a struct body without proper separation causes compilation errors.

- **Rule**: Cannot declare `const` variables inside conditional expressions. Use `if (self.findFlagIndex(...)) |i|` not `if (const idx = self.findFlagIndex(...)) |i|`. Same applies to `while` loops.

- **Rule**: Cannot create type aliases for error union types using `!` syntax. `const MandatoryValue = ![]const u8` is **invalid**. Use `anyerror![]const u8` or explicit error sets.

- **Rule**: Function pointer types **cannot have inferred error sets**. Use `anyerror!void` or explicit error sets like `error{Err1, Err2}!void` instead of `!void` in function pointer type definitions.

- **Rule**: Zig requires **semicolons after all statements**, including `unreachable`. `unreachable` is a statement, not an expression.

- **Rule**: Zig warns about **unused function parameters**. Use `_ = param;` to explicitly ignore, or use the parameter.

---

## Priority 2: Memory Management

### Allocation and Freeing

- **Rule**: When allocating **multi-level structures**, ensure **all levels are freed**. Add cleanup loops: `for (words) |word| { a.free(word); }` before `a.free(words)`.
- **Frequency**: High

- **Rule**: Extract **duplicate cleanup logic** into dedicated functions. When the same cleanup pattern appears in multiple places, extract it (e.g., `free_words(allocator, words)`).

- **Rule**: **Allocated transform results must be freed**. If transform functions allocate strings, free each allocated result after use.

- **Rule**: Avoid **double transformation**. If transforming data twice (once for length calculation, once for building), store transformed strings in an array before use.

- **Rule**: **All function parameters must be used** in Zig. Use `_ = param;` to explicitly mark unused parameters and silence warnings.

### Ownership and Return Types

- **Rule**: When changing memory ownership patterns, **update all callers** to handle the new ownership correctly.

- **Rule**: Helper functions should have **clear signatures that indicate mutability**. Use `[]T` (mutable slice) vs `[]const T` (const slice) appropriately.

---

## Priority 3: Error Handling

### Unused Variables

- **Rule**: **Unused error capture**: use `catch { ... }` without naming the error, not `catch |err| { ... }` when err is not used.

- **Rule**: **Unused local constants** must be explicitly marked as used with `_ = variable;` or they cause compilation errors.

- **Rule**: When refactoring to add new variables, **ensure all are marked as used** or removed to avoid compilation errors.

### Error Sets

- **Rule**: Error sets must be **explicitly defined** for function pointer types. `!void` (inferred) is not allowed; use `anyerror!void` or `error{...}!void`.

- **Rule**: When defining custom error types, avoid using `!CustomError` in return types. Prefer `!void` and let Zig infer the error set, or use explicit forms.

- **Rule**: Function signature: `?[*:0]T` vs `[*:0]T` vs `[]T` have **different semantics**. Be careful with nullable types and null-terminated slices.

---

## Priority 4: Code Quality & Maintainability

### Documentation

- **Rule**: **Initial file documentation should be comprehensive** enough to avoid follow-up clarification requests. Aim for sufficient detail from the start.

- **Rule**: When adding documentation, **anticipate** that users may want more context and provide it proactively.

- **Rule**: **Document language-specific quirks** and workarounds as they are discovered. Add to skill documentation.

### Code Structure

- **Rule**: **Remove unreachable code** after early returns. Dead code after `return` statements should be deleted.

- **Rule**: **Avoid repeated array lookups**. Store in local variables for clarity and potential performance. E.g., `const selected_dice_words = dice_words[selected_dice]` then use the variable.

- **Rule**: **Ensure random/expensive functions are called once** per logical operation, not per loop iteration. Store results in variables before loops.

- **Rule**: **Separation of concerns**: Platform-specific code (Windows native code, SYSTEMTIME structs, extern declarations) should be **isolated in its own module** for better maintainability and testability.

- **Rule**: When a function directly uses types from another module, **consider moving it** to that same module for better organization.

### Naming Conventions

- **Rule**: When defining namespaces, use **module names** not type names. Types are accessed as `glob.Glob`, `glob.FilePath`, etc.

---

## Priority 5: Refactoring Best Practices

### Extraction and Duplication

- **Rule**: **Extract helper methods** (`getNameType`, `getCasing`, etc.) to improve code organization and reduce duplication.

- **Rule**: Use **constants for repeated string literals** to ease maintenance. E.g., `name_types` array for repeated values.

- **Rule**: When extracting types to new modules, **update all import statements** referencing those types.

- **Rule**: During refactoring, **check for redundant aliases** and ensure all related code is moved together.

- **Rule**: If a function's primary purpose is to format/process a type from another module, it should **live in that same module**.

### Function Extraction

- **Rule**: Extract functions when they improve **readability**, **testability**, or **reusability** - not just for extraction's sake.

- **Rule**: **Break refactorings into smallest possible steps**: create module -> verify import works -> remove old code -> verify tests pass.

- **Rule**: When changing function signatures, **verify and update all call sites** including tests.

- **Rule**: For **separation of concerns**, extract logical components (e.g., `generateHeader`, `generateRows` from `generateTable`).

- **Rule**: Use **explicit allocator parameters** even when accessible through other means (e.g., `ArrayList.allocator`) for better code clarity.

### Incremental Approach

- **Rule**: **Check git status frequently** during refactoring to detect unintended modifications early.

- **Rule**: **Make minimal, focused edits**. When an edit fails, re-read the file and try smaller changes.

- **Rule**: Prefer **complete file rewrites** over partial edits to avoid corruption when doing major changes.

- **Rule**: After refactoring, **verify file modifications match intentions** before committing.

### Code Patterns

- **Rule**: **Pass ArrayList to functions** to avoid intermediate allocations. Format into stack buffer, then append to ArrayList. Pattern: `format into buffer` -> `result.appendSlice(buf[0..len])`.

- **Rule**: Use **stack-allocated buffers** (`var buf: [N]u8`) for small, known-size formatting operations.

- **Rule**: Use **type aliases** for complex compound types to improve readability. E.g., `Words` for `[][]const u8`.

- **Rule**: Use **`anyerror!void`** for function pointer type definitions instead of `!void` (which has inferred error sets).

- **Rule**: Use **`_ = unused_param;`** pattern to silence unused variable warnings in Zig.

- **Rule**: Use **optional types** (`?*T` for pointers, `""` for strings) to unify function signatures when some parameters aren't always needed.

- **Rule**: Use **const aliases for functions** to maintain backward compatibility during refactoring: `const addToolsFromDir = addFromDir;`.

---

## Priority 6: Build System

### Binary Size Optimization

- **Rule**: Zig **does aggressively eliminate dead code** at the function/type level. Binary bloat typically comes from module-level imports, not from Zig failing to optimize.

- **Rule**: **Module-scope imports** (`const windows = std.os.windows;`) create **transitive dependencies** that pull in entire modules. Avoid at module scope when only a few functions are needed.

- **Rule**: **Direct Windows API calls** via `extern` declarations add **minimal size** (~1-4KB). Prefer over importing large std modules.

- **Rule**: Large std modules (like `std.os.windows` at 5532 lines) should be **avoided** when only a few types are needed. Duplicate minimal type definitions locally instead.

- **Rule**: Import libraries (.lib) contain **only stubs** (~5-10 bytes each). Actual DLL code (user32.dll, kernel32.dll) is loaded at runtime.

### Linking and Dependencies

- **Rule**: When using extern declarations for Win32 APIs, **explicitly link** against the corresponding .lib files using `exe.linkSystemLibrary("user32")`, `exe.linkSystemLibrary("kernel32")`, etc.

- **Rule**: Windows APIs use **`.Stdcall`** calling convention on x86 architecture. Use conditional compilation: `const CallConv = if (builtin.cpu.arch == .x86) .Stdcall else .C`.

- **Rule**: Use **`@cImport` sparingly**. Prefer direct `extern` declarations for Win32 API to avoid C header dependencies.

- **Rule**: When module resolution fails in tests, ensure **build.zig has proper module import setup**: `test_compilation.root_module.addImport("common", lib_common)`.

### Build API Usage

- **Rule**: When extracting duplicated build code, **carefully match the types** of all parameters. Zig's type system is strict; small mismatches cause compilation errors.

- **Rule**: **Verify refactoring by building** to catch type errors early. Use `git diff` to track changes incrementally.

- **Rule**: When build fails, **restore original code** and verify it builds to establish a baseline, then investigate the difference.

---

## Priority 7: Platform-Specific Rules

### Random Seeding

- **Rule**: For rapid successive invocations, use **high-resolution timestamps**: `std.time.nanoTimestamp()` or `std.time.microTimestamp()` instead of `timestamp()` (1-second resolution).

- **Rule**: When combining values for seeds, **prefer addition and bit shifts** over multiplication to avoid integer overflow. E.g., `timestamp + (@as(u64, pid) << 32)` instead of `timestamp * large_constant`.

- **Rule**: Always **verify platform-specific API availability**. Use `std.os.windows.*` for Windows; check if functions exist for the target platform.

### Windows API

- **Rule**: For **cross-compilation** or when C headers aren't available, use **manual `extern` declarations** instead of `@cImport` with windows.h.

- **Rule**: For minimal dependencies, **define local type aliases** rather than importing large std modules. E.g., `HANDLE = ?*anyopaque`, `HWND = ?*anyopaque`.

- **Rule**: Use **platform-specific calling conventions** for architecture compatibility. Windows uses `.Stdcall` on x86, `.C` on others.

### Timestamp and Process

- **Rule**: `std.os.getpid()` **does not exist** in Zig 0.13.0 on Windows. Use `std.os.windows.GetCurrentProcessId()` instead.

- **Rule**: For **deterministic testing** of random-based functions, inject a mock `nextFn` into the Random struct. Use `alwaysZero` and `alwaysOne` patterns for testing specific code paths.

---

## Priority 8: Investigation Process

### Testing Approach

- **Rule**: Use **inline shell commands** for quick tests when possible. If files are needed, reuse them and clean up immediately.

- **Rule**: Once a hypothesis is confirmed through testing, **provide the answer**. One or two confirmations are sufficient; don't over-verify.

- **Rule**: **Clean as you go**: Delete test files immediately after they've served their purpose.

---

## Priority 9: Windows-Specific Rules

### Batch Files

- **Rule**: In Windows batch files, the `^` continuation character must be the **absolute last character** on the line (no trailing spaces). Continuation lines should start with a space.

- **Rule**: In batch files, `^` is an **escape character**. Regex patterns containing `^` (start of line) should use single `^`, not `^^`. Double `^^` results in a literal `^` in the final command.

### Command Line and Shell

- **Rule**: Windows cmd.exe **does not support** bash here-documents. Use temporary files for multi-line input instead.

### Build Output

- **Rule**: **`zig build` writes to stderr** by design on all platforms (following Unix conventions). Use `2>&1` redirection in Windows batch files to capture build output.

- **Rule**: Build systems and compilers typically write **diagnostics to stderr** and normal output to stdout. This is standard Unix convention.

---
