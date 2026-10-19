# Zig Programming Language Overview

## Overview

Zig is a modern, general-purpose systems programming language designed as a **successor to C**. It prioritizes **explicitness, simplicity, and control**, with no hidden allocations, no preprocessor, and no runtime. Zig compiles to native code, producing small, fast, and portable binaries.

### Key Characteristics

- **Paradigm**: Imperative, procedural (no OOP)
- **Memory Management**: Manual (with safety features like allocators, `defer`, `errdefer`)
- **Compilation**: Ahead-of-time (AOT) to native code
- **Target Platforms**: Windows, Linux, macOS, BSD, WebAssembly, and more
- **Cross-Compilation**: Built-in (no toolchain setup needed)
- **Dependencies**: No runtime dependencies by default

---

## Comparison with Mainstream Languages

| Feature | Zig | C | C++ | Rust | Go | Python | JavaScript |
|-------- |---- |-- |-----|------|----|--------|------------|
| **Memory Management** | Manual + Allocators | Manual | Manual + Smart Pointers | Borrow Checker | GC | GC | GC |
| **Compilation** | AOT, Native | AOT, Native | AOT, Native | AOT, Native | AOT, Native | Interpreted | JIT |
| **Runtime** | None (optional libc) | None (optional libc) | None (optional libstdc++) | Minimal | Medium (GC, scheduler) | Large | Large (V8/Node) |
| **Cross-Compile** | ✅ Built-in | ❌ Complex | ❌ Complex | ✅ Good | ✅ Good | ❌ No | ❌ No |
| **Binary Size** | +++++ Tiny | ++++ Small | +++ Medium | ++++ Small | +++ Medium | + N/A | + N/A |
| **Startup Time** | +++++ Instant | ++++ Instant | ++++ Instant | ++++ Instant | ++ Slow | + Slow | + Slow |
| **I/O Performance** | +++++ Native | +++++ Native | +++++ Native | +++++ Native | +++ Good | ++ Slow | ++ Slow |
| **Concurrency** | Async (manual) | Manual | Manual/Threads | Fearless (ownership) | Goroutines | GIL-limited | Event Loop |
| **Metaprogramming** | Comptime (+++++) | Preprocessor (+) | Templates (+++) | Macros (+++) | None | Reflection (++) | None |
| **Error Handling** | Explicit (!T types) | Return codes | Exceptions | Result/Option | Multiple returns | Exceptions | Exceptions/Callbacks |
| **Learning Curve** | Moderate | Hard | Very Hard | Hard | Easy | Easy | Easy |

### Best Language to Know Before Zig

**C** is the most valuable background (~90% transfer):

- Pointers and manual memory management
- Systems programming mindset
- Low-level control

Other languages in order of usefulness:

- **Go**: Explicit error handling (`!T` similar to Go's multi-return)
- **Rust**: Memory safety concepts (but ownership model is different)
- **Java/C#**: Basic syntax, but OOP patterns don't transfer well
- **Python/JS/TS**: General programming concepts only

---

## Build System & Dependency Management

### No Makefiles Needed

Zig has a **built-in build system** that replaces Make, CMake, etc.

### Core Files

- **`build.zig`** - Build script written in Zig (defines executables, libraries, dependencies)
- **`build.zig.zon`** - Package manifest (optional, for dependency declarations)

### Key Commands

```bash
zig build         # Build project
zig build run     # Build and run
zig build test    # Run tests
zig build install # Install
zig build --release=safe  # Release build
```

### Targeting Different Platforms

```bash
# Cross-compile to Windows 64-bit from any OS
zig build -Dtarget=x86_64-windows

# Cross-compile to Windows 32-bit (XP compatible)
zig build -Dtarget=x86-windows-gnu

# List all supported targets
zig targets
```

---

## Code Reuse & Project Structure

#### Option Separate Directories

```
myproject/
├── lib/
│   ├── utils.zig
│   └── common.zig
├── tools/
│   ├── tool1.zig
│   ├── tool2.zig
│   └── tool3.zig
└── build.zig
```

**In `tools/tool1.zig`:**

```zig
const utils = @import("../lib/utils.zig");
const common = @import("../lib/common.zig");
```

#### Option 2: Proper Library (For Larger Projects)

**In `build.zig`:**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Create a static library from shared code
    const lib = b.addStaticLibrary(.{
        .name = "mylib",
        .root_source_file = .{ .path = "lib/utils.zig" },
    });
    lib.addZigSourceFile(.{ .path = "lib/common.zig" });

    // Link library to all tools
    for ([_]"tool1", "tool2", "tool3") |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = .{ .path = "tools/" ++ name ++ ".zig" },
        });
        exe.linkLibrary(lib);
        b.installArtifact(exe);
    }
}
```

**In `tools/tool1.zig`:**

```zig
const mylib = @import("mylib");
```

---

## Static Compilation & Zero Dependencies

### Everything is Statically Compiled by Default

- Zig code is **always** compiled directly into your binary
- No runtime dependencies for pure Zig projects
- Can produce **single-file `.exe`** with zero external requirements

### For Fully Static Binaries

```zig
// In build.zig
executable.link_libc = false;  // No libc dependency
executable.link_libcpp = false; // No C++ dependency
```

**Command line:**

```bash
zig build -Doptimize=ReleaseSafe -Dstatic=true
```

**Result:** A standalone `.exe` (typically 200KB-2MB) that runs on any Windows machine without installing anything.

---

## Windows XP / 32-bit Support

### Yes, Zig Can Target 32-bit Windows XP

**Target for XP:**

```bash
zig build -target i386-windows-gnu
```

### Build Configuration

```zig
// In build.zig
const target = b.standardTargetOptions(.{
    .cpu_arch = .x86,    // 32-bit
    .os_tag = .windows,  // Windows
});

const exe = b.addExecutable(.{
    .name = "mytool",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
});
```

### XP Compatibility Notes

- **Works:** Pure Zig code, MinGW (`-gnu`) target uses `msvcrt.dll` (available on XP)
- **Caveats:**
  - Avoid Windows API functions introduced after XP (2001)
  - Avoid TLS (Thread Local Storage) - may not work on XP
  - For C dependencies, use older MinGW versions
  - Static linking (`exe.link_libc = false`) is safest

### Example: XP-Compatible Static Binary

```bash
zig build -target i386-windows-gnu -Doptimize=ReleaseSafe
```

-> Produces a single `.exe` that runs on Windows XP SP3+.

---

## Performance Characteristics

### Startup Time

| Language | Startup Time | Notes |
|----------|--------------|-------|
| Zig | **<1ms** | No runtime initialization |
| C | **<1ms** | Minimal runtime |
| Rust | **~1-2ms** | Small runtime |
| Go | **~50-100ms** | Runtime initialization overhead |
| PowerShell | **~300ms+** | .NET JIT |
| Python | **~100-500ms** | Interpreter startup |

### I/O Performance

Zig provides **native-speed I/O** by:

- Direct Win32 API calls (`ReadFile`, `WriteFile`, `FindFirstFileW`/`FindNextFileW`)
- No buffering overhead (unless explicitly added)
- Zero-cost abstractions

**Example: Fast Directory Scanner**

```zig
const std = @import("std");

pub fn main() !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        std.debug.print("{s}\n", .{entry.path});
    }
}
```

---

## Who Uses Zig? (2026)

### Companies & Organizations

- **Uber** - Cross-compilation and build systems
- **TigerBeetle** - Financial database (core written in Zig)
- **Lunatic Solutions** - Serverless and edge platforms

### Major Open-Source Projects

- **Bun** - JavaScript runtime (initially built with Zig; partial rewrite in progress)
- **Mach** - Game engine and graphics toolkit
- **River** - Wayland compositor for Linux
- **Ghostty** - GPU-accelerated terminal emulator
- **neon** - HTTP server
- **Zig Web Framework (ZWF)** - Backend services

### Adoption Trend

Zig is gaining traction in:

- Systems programming
- High-performance tools
- Embedded applications
- Cross-platform development
- As a modern alternative to C

---

## Key Language Features

### 1. Comptime (Compile-Time Code Execution)

```zig
fn factorial(comptime n: u32) u32 {
    return if (n == 0) 1 else n * factorial(n - 1);
}

const fact_5 = comptime factorial(5); // Calculated at compile time!
```

### 2. Error Handling with Error Unions

```zig
const File = struct {
    fd: std.os.windows.HANDLE,

    pub fn open(path: []const u8) !File {
        const fd = std.os.windows.CreateFileW(...);
        if (fd == std.os.windows.INVALID_HANDLE_VALUE) {
            return error.FileNotFound;
        }
        return File{ .fd = fd };
    }
};

// Usage
const file = try File.open("test.txt"); // Must handle error
```

### 3. Memory Management

```zig
const allocator = std.heap.page_allocator;

const buffer = try allocator.alloc(u8, 100);
defer allocator.free(buffer); // Always freed, even on error

// Or with errdefer (only runs on error)
const buffer = try allocator.alloc(u8, 100);
errdefer allocator.free(buffer);
```

### 4. Slices (Pointer + Length)

```zig
const slice: []u8 = buffer[0..100]; // Slice = pointer + length
const first_10 = slice[0..10];      // Sub-slice
```

### 5. No Hidden Allocations

```zig
// This allocates on the heap - MUST be explicit
const buffer = try allocator.alloc(u8, 100);

// This is stack-allocated - no heap involved
var stack_buffer: [100]u8 = undefined;
```

---

## Quick Start Example

### Hello World

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, {s}!\n", .{"World"});
}
```

### Build & Run

```bash
# Save as main.zig
zig run main.zig

# Or compile and run separately
zig build-exe main.zig -o hello
./hello
```

### Cross-Compile to Windows

```bash
# From Linux/macOS to Windows 64-bit
zig build-exe main.zig -target x86_64-windows -o hello.exe

# To Windows 32-bit (XP compatible)
zig build-exe main.zig -target i386-windows-gnu -o hello.exe
```

---

## Resources

- **Official Website**: [https://ziglang.org](https://ziglang.org)
- **Documentation**: [https://ziglang.org/documentation/](https://ziglang.org/documentation/)
- **Learn Zig in Y Minutes**: [https://github.com/nektro/zig-in-y-minutes](https://github.com/nektro/zig-in-y-minutes)
- **Zig Learn**: [https://ziglearn.org](https://ziglearn.org)
- **Package Registry**: [https://zig.pkg.xyz](https://zig.pkg.xyz)
- **GitHub**: [https://github.com/ziglang/zig](https://github.com/ziglang/zig)

---

## Summary

Zig is an excellent choice for:

- **Command-line tools** (fast startup, zero dependencies)
- **Systems programming** (OS, drivers, embedded)
- **Cross-platform development** (built-in cross-compilation)
- **Performance-critical applications** (native speed, no overhead)
- **Replacing C/C++** (safer, modern, but with similar control)

**Not ideal for:**

- GUI applications (limited libraries)
- Web development (use TypeScript/JavaScript instead)
- High-level abstraction (use Python/Ruby instead)
- Large ecosystem (smaller than C/C++/Rust/Go)

**Verdict:** If you're coming from C and want modern features without losing control, **Zig is a perfect fit**. For CLI tools on Windows with zero dependencies, it's one of the best choices available.
