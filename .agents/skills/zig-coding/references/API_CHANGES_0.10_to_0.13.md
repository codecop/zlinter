# Changes to ZIG from 0.10.0 to 0.13.0

| Old code / API                            | -> instead use new code / API                       | Comment / clarification                   |
| ----------------------------------------- | --------------------------------------------------- | ----------------------------------------- |
| `std.build.Builder`                       | `std.Build`                                         | Build system namespace/type rename        |
| `std.build`                               | `std.Build`                                         | Capitalized namespace                     |
| `Pkg`                                     | `Module`                                            | Package replaced by module terminology    |
| `LibExeObjStep`                           | `Step.Compile`                                      | Compile step abstraction renamed          |
| `Builder`                                 | `Build`                                             | Build object rename                       |
| `FileSource`                              | `LazyPath`                                          | New lazy path abstraction in build system |
| `CrossTarget`                             | `ResolvedTarget`                                    | New target representation                 |
| `BuildMode`                               | `OptimizeMode`                                      | Optimization enum renamed                 |
| `exe.addPackage(...)`                     | `exe.root_module.addImport(...)`                    | Modules replace packages                  |
| `exe.addModule(...)`                      | `exe.root_module.addImport(...)`                    | Common migration failure                  |
| `b.addModule(...)`                        | `b.createModule(...)`                               | Explicit module creation                  |
| `@import("std").build`                    | `std.Build`                                         | Modern build API                          |
| `std.ChildProcess`                        | `std.process.Child`                                 | Process API namespace cleanup             |
| `std.ComptimeStringMap`                   | `std.StaticStringMap`                               | Renamed and extended                      |
| `zig-cache/`                              | `.zig-cache/`                                       | Cache directory renamed                   |
| `.iov_base`                               | `.base`                                             | iovec field cleanup                       |
| `.iov_len`                                | `.len`                                              | iovec field cleanup                       |
| `var x = ...` (never mutated)             | `const x = ...`                                     | Compiler now errors on immutable vars     |
| implicit integer casts                    | `@intCast(...)`                                     | Compiler stricter about casts             |
| implicit truncation                       | `@truncate(...)`                                    | Explicit truncation required              |
| implicit signed-ness conversion           | explicit casts                                      | More type safety                          |
| loose pointer coercions                   | stricter pointer typing                             | Sentinel/const coercions reduced          |
| older allocator passing styles            | `allocator = gpa.allocator()`                       | Allocator APIs normalized                 |
| `std.mem.Allocator` copies everywhere     | allocator handles/references                        | More explicit ownership patterns          |
| `@typeInfo(T).Enum`                       | `@typeInfo(T).@"enum"`                              | Reflection naming cleanup                 |
| `@typeInfo(T).Struct`                     | `@typeInfo(T).@"struct"`                            | Reflection fields now keyword-safe        |
| `@typeInfo(T).Union`                      | `@typeInfo(T).@"union"`                             | Reflection keyword escaping               |
| `@typeInfo(T).Fn`                         | `@typeInfo(T).@"fn"`                                | Reflection keyword escaping               |
| `@TypeOf(x)` assumptions                  | stricter comptime evaluation                        | Some inference became stricter            |
| `std.ArrayList.init(allocator)`           | still valid but APIs stricter                       | Capacity/ownership APIs tightened         |
| `std.heap.GeneralPurposeAllocator(.{}){}` | `var gpa = std.heap.GeneralPurposeAllocator(.{}){}` | GPA patterns standardized                 |
| `defer _ = gpa.deinit();` optional        | now expected/common                                 | Leak checking integrated                  |
| raw path strings in build APIs            | `LazyPath` objects                                  | Build graph laziness                      |
| `addIncludeDir(...)` patterns             | `addIncludePath(...)`                               | Modernized C integration                  |
| loose C integration                       | explicit `linkLibC()`                               | More explicit build configuration         |
| manual package inclusion                  | `build.zig.zon` dependencies                        | Official package manager introduced       |
| no dependency hashes                      | required `.hash` field                              | Reproducible dependency resolution        |
| ad-hoc dependency trees                   | `.dependencies = .{}`                               | Standardized package config               |
| old package directories                   | module imports                                      | Structural project cleanup                |
| older `std.Progress` APIs                 | redesigned progress API                             | CLI/progress tools affected               |
| `std.fs.path.sep` assumptions             | newer path utilities                                | Cross-platform cleanup                    |
| many optional coercions                   | explicit unwrap/coercion                            | Optional handling stricter                |
| implicit error union coercions            | explicit handling                                   | More compiler correctness                 |
| `[]u8` coercions                          | stricter const handling                             | `[]const u8` more enforced                |
| mutable string literals assumptions       | immutable literals enforced                         | String safety improvements                |
| old sentinel pointer coercions            | explicit sentinel handling                          | Safer pointer semantics                   |
| `[*]T` assumptions                        | stricter slice/pointer separation                   | More correctness                          |
| older `std.mem.copy` patterns             | newer slice-safe variants                           | Some APIs renamed/adjusted                |
| `std.mem.set` usage                       | newer memset-style helpers                          | Stdlib cleanup                            |
| old hash map initialization patterns      | allocator-explicit initialization                   | Containers more explicit                  |
| old enum reflection assumptions           | keyword-safe reflection names                       | Affects generic libraries                 |
| older `@fieldParentPtr` assumptions       | stricter pointer provenance                         | Safer low-level semantics                 |
| anonymous struct inference                | stricter inference                                  | Generic code may fail                     |
| ad-hoc package imports                    | explicit modules                                    | Dependency graph now formalized           |
| `std.rand.DefaultPrng`                   | `std.Random.DefaultPrng`                            | Random PRNG renamed (alias for Xoshiro256) |
| `std.mem.copy`                           | `std.mem.copyForwards` / `std.mem.copyBackwards` / `@memcpy` | mem.copy removed in Zig 0.13 |
| `std.testing.expectEqual(type, expected, actual)` | `std.testing.expectEqual(actual, expected)` | expectEqual now takes exactly 2 arguments |
| `std.testing.expectNotEqual(...)`       | `std.testing.expectEqual` with positive checks or custom negation | expectNotEqual does not exist |
| `std.debug.print` for main content       | `std.io.getStdOut().writer().print()`             | debug.print writes to stderr by default |
| `std.time.timestamp()` (i64) for Random  | `@intCast(u64, std.time.timestamp())`             | timestamp returns i64, Random expects u64 |
| `link_library`                          | `linkSystemLibrary`                                | Build API renamed |
| `target.os.tag`                         | `target.result.os.tag`                             | ResolvedTarget contains result field |
| `exe.root_module` as pointer             | `&exe.root_module`                                | root_module is value type, not pointer |
| `b.createModule`                        | returns `*std.Build.Module`                        | Returns non-const pointer |
| `addImport` with value type             | `addImport(m: *Module, name: []const u8, module: *Module)` | Module parameter must be pointer |

## Zig 0.13 Builtin Migration

| Old                    | New                                                |
| ---------------------- | -------------------------------------------------- |
| `@intCast(T, x)`       | `@intCast(x)` or `@as(T, @intCast(x))`             |
| `@floatCast(T, x)`     | `@floatCast(x)` or `@as(T, @floatCast(x))`         |
| `@truncate(T, x)`      | `@truncate(x)` or `@as(T, @truncate(x))`           |
| `@bitCast(T, x)`       | `@bitCast(x)` or `@as(T, @bitCast(x))`             |
| `@ptrCast(T, x)`       | `@ptrCast(x)` or `@as(T, @ptrCast(x))`             |
| `@alignCast(T, x)`     | `@alignCast(x)` or `@as(T, @alignCast(x))`         |
| `@addrSpaceCast(T, x)` | `@addrSpaceCast(x)` or `@as(T, @addrSpaceCast(x))` |
| `@enumFromInt(T, x)`   | `@enumFromInt(x)` or `@as(T, @enumFromInt(x))`     |
| `@errorCast(T, x)`     | `@errorCast(x)` or `@as(T, @errorCast(x))`         |

**Rule:** Most builtins changed from `@builtin(Type, value)` to `@builtin(value)`, with the destination type inferred from context. If inference fails, wrap with `@as(Type, ...)`.
