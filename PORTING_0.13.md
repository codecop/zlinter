# Porting Zlinter to Zig 0.13 — Analysis & Task List

> Branch: `0.13.x` | Target: Zig 0.13.0 | Source: `0.14.x` branch
> Created: 2026-10-19

---

## Executive Summary

Zlinter targets Zig 0.14+ and uses ZLS 0.14.0 as a dependency. Porting to Zig 0.13.0 requires changes across **19 source files**, the **build system**, and the **ZLS dependency**. The single biggest blocker is that **`std.zon` does not exist in Zig 0.13** — the ZON parser was introduced in 0.14. This affects rule config file parsing.

The `std.zig.Ast` API is largely compatible between 0.13 and 0.14 (both use `data.lhs`/`data.rhs`), which means the AST shims need minimal changes. The build system API and ZLS API have the most significant differences.

---

## Critical Blockers

### BLOCKER-1: `std.zon` does not exist in Zig 0.13

| Aspect | Details |
|--------|---------|
| Impact | HIGH — Rule configs parsed from `.zon` files will not work |
| Affected files | `src/lib/zon.zig`, `src/exe/run_linter.zig`, `build.zig` (rule config serialization) |
| Current usage | `std.zon.parse.fromSlice(T, gpa, slice, diagnostics, options)` and `std.zon.parse.Status` |
| Options | (a) Write a minimal ZON parser (~500 lines), (b) Use ZLS 0.13's internal ZON parser if available, (c) Switch to JSON configs, (d) Embed configs as Zig source instead of ZON |

**Recommendation:** Option (b) first — check if ZLS 0.13 exposes a ZON parser. If not, option (a) — a minimal ZON parser that handles the subset of ZON used by rule configs (structs with primitive fields, enums, slices).

### BLOCKER-2: ZLS 0.13 API compatibility

| Aspect | Details |
|--------|---------|
| Impact | HIGH — Core analyser, document store, and type resolution APIs differ |
| Current dep | `zls 0.14.0` (`git+https://github.com/zigtools/zls?ref=0.14.0`) |
| Target dep | `zls 0.13.0` (`git+https://github.com/zigtools/zls?ref=0.13.0`) |
| Affected files | `src/lib/session.zig`, `src/lib/ast.zig`, `build.zig` (zls version switch) |

Key ZLS API differences to investigate:
- `zls.DocumentStore` config structure (0.14 uses `.fromMainConfig(config)`, 0.13 may differ)
- `zls.Analyser.init()` signature (0.14: `(gpa, &document_store, &intern_pool, null)`, 0.13 may differ)
- `zls.Analyser.resolveTypeOfNode()` signature
- `zls.Analyser.Type` methods (`instanceTypeVal`, `resolveDeclLiteralResultType`, etc.)
- `zls.ast.iterateChildren()` — may not exist in ZLS 0.13
- `zls.DiagnosticsCollection` — may differ
- `zls.analyser.InternPool` — may differ
- `zls.Config` fields (`zig_exe_path`, `zig_lib_path`, `global_cache_path`)
- `zls.URI.fromPath()` — may differ

---

## Task List

### Phase 1: Foundation (blocking everything else)

- [ ] **TASK-1.1:** Add `.@"0.13"` to `src/lib/version.zig` enum and detection logic
  - File: `src/lib/version.zig`
  - Change: Add `.@"0.13"` to the enum, add `else if (major == 0 and minor == 13) .@"0.13"` branch
  - Verify: `zig build` compiles past the version check

- [ ] **TASK-1.2:** Update `build.zig.zon` minimum version and ZLS dependency
  - File: `build.zig.zon`
  - Change: `.minimum_zig_version = "0.13.0"`, update ZLS to `0.13.0` ref
  - Command: `zig fetch --save git+https://github.com/zigtools/zls#0.13.0`
  - Verify: `zig fetch` succeeds, hash updates

- [ ] **TASK-1.3:** Add `.@"0.13"` case to `shims.ArrayList()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:188-189`
  - Change: `.@"0.13" => std.ArrayList(T)` (0.13 has managed ArrayList by default)
  - Note: In 0.13, `std.ArrayList(T)` is the managed version

- [ ] **TASK-1.4:** Add `.@"0.13"` case to `NodeIndexShim.toNodeIndex()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:62-66`
  - Change: `.@"0.13" => self.index` (0.13 `Ast.Node.Index` is `u32`, not enum)

- [ ] **TASK-1.5:** Add `.@"0.13"` cases to `unwrapNode()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:91-113`
  - Change: Use same `data.lhs`/`data.rhs` access as 0.14 (0.13 `Node.Data` is `struct { lhs, rhs }`)
  - Map: `.@"0.13"` alongside `.@"0.14"` for all four switch branches

- [ ] **TASK-1.6:** Verify `nodeTag`, `nodeData`, `nodeMainToken`, `tokenTag` shims work for 0.13
  - File: `src/lib/shims.zig:115-145`
  - These use `tree.nodes.items(.tag)[node]` etc. — same pattern in 0.13
  - The `std.meta.hasMethod` checks should fall through to the 0.14-style access
  - Verify: No changes needed, but test compilation

### Phase 2: ZON Parser (BLOCKER-1 resolution)

- [ ] **TASK-2.1:** Research ZLS 0.13 for internal ZON parser availability
  - Check: `zls` package for any `zon` module or parser
  - If found: Use it in `src/lib/zon.zig`
  - If not found: Proceed to TASK-2.2

- [ ] **TASK-2.2:** Implement minimal ZON parser for rule configs
  - File: `src/lib/zon.zig` (rewrite for 0.13)
  - Scope: Parse `.{ .field = value, ... }` syntax with:
    - String values: `.{ .name = "value" }`
    - Integer values: `.{ .len = 10 }`
    - Enum values: `.{ .style = .snake_case }`
    - Boolean values: `.{ .enabled = true }`
    - Slice values: `.{ .names = .{"a", "b"} }`
    - Nested structs: `.{ .field = .{ .sub = 1 } }`
  - Use `std.zon.parse.fromSlice` equivalent API surface
  - Alternative: Use `std.json` and switch config format

- [ ] **TASK-2.3:** Update `zon.Diagnostics` type for 0.13
  - File: `src/lib/zon.zig:1-4`
  - 0.14: `std.zon.parse.Status`
  - 0.13: No `std.zon` — use custom diagnostics type or `void`

- [ ] **TASK-2.4:** Update `parseFileAlloc` file reading for 0.13
  - File: `src/lib/zon.zig:18-48`
  - 0.13: `file.reader().readAllArrayList(&array_list, max_size)` then `toOwnedSliceSentinel(0)`
  - Same as 0.14 pattern — verify it compiles

### Phase 3: Build System Port

- [ ] **TASK-3.1:** Port `build.zig` — `zls_version` switch
  - File: `build.zig:3-7`
  - Change: Add `.@"0.13" => "0.13.0"` to the switch

- [ ] **TASK-3.2:** Port `build.zig` — `b.addModule()` calls
  - File: `build.zig` (multiple locations)
  - 0.14: `b.addModule("zlinter", .{ .root_source_file = b.path("..."), .target = target, .optimize = optimize, .imports = &.{...} })`
  - 0.13: Same signature — `b.addModule(name, options)` exists in both
  - Verify: `Module.CreateOptions` fields match (0.13 has `root_source_file`, `imports`, `target`, `optimize`)

- [ ] **TASK-3.3:** Port `build.zig` — `b.createModule()` calls
  - File: `build.zig` (multiple locations)
  - Both 0.13 and 0.14 have `b.createModule(options)` — should be compatible
  - Verify: `Module.CreateOptions` fields match

- [ ] **TASK-3.4:** Port `build.zig` — `b.addTest()` calls
  - File: `build.zig:135-138` and similar
  - 0.14: `b.addTest(.{ .root_module = zlinter_lib_module, .use_llvm = test_coverage })`
  - 0.13: `b.addTest(.{ .root_source_file = b.path("src/lib/zlinter.zig"), .target = target, .optimize = optimize })`
  - **Major change:** 0.13 `TestOptions` has `root_source_file`, not `root_module`
  - Need to pass module imports differently — 0.13 uses `b.addModule()` and then references it

- [ ] **TASK-3.5:** Port `build.zig` — `b.addExecutable()` calls
  - File: `build.zig` (wasm exe, docs exe, build_rules exe)
  - 0.14: `b.addExecutable(.{ .name = "wasm", .root_module = b.createModule(.{...}) })`
  - 0.13: `b.addExecutable(.{ .name = "wasm", .root_source_file = b.path("..."), .target = ..., .optimize = ... })`
  - **Major change:** 0.13 `ExecutableOptions` has `root_source_file`, not `root_module`

- [ ] **TASK-3.6:** Port `build.zig` — `b.addLibrary()` calls
  - File: `build.zig` (lint step)
  - 0.14: `b.addLibrary(.{ .name = "zlinter", .root_module = zlinter_lib_module })`
  - 0.13: `b.addStaticLibrary(.{ .name = "zlinter", .root_source_file = ..., .target = ..., .optimize = ... })`
  - Note: 0.13 uses `addStaticLibrary`, not `addLibrary`

- [ ] **TASK-3.7:** Port `build.zig` — `addWatchInput` function
  - File: `build.zig:~480-530`
  - 0.14: Uses `step.addDirectoryWatchInput()`, `step.addWatchInput()`, `step.addDirectoryWatchInputFromPath()`
  - 0.13: These methods **do not exist** on `Step`
  - **Major change:** 0.13 doesn't have watch inputs on steps. Need to either:
    - Remove watch input support (breaks `--watch` mode)
    - Use `step.inputs` table directly (hacky)
    - Skip this feature for 0.13

- [ ] **TASK-3.8:** Port `build.zig` — `ZlinterRun.create()` and `make()`
  - File: `build.zig:~600-750`
  - `b.graph.zig_exe` — exists in 0.13 as `[:0]const u8`
  - `b.graph.global_cache_root` — in 0.13 it's `Cache.Directory`, need `.path` or `.handle`
  - `b.graph.zig_lib_directory` — **does not exist in 0.13**; use `b.zig_lib_dir` (`?LazyPath`)
  - `exe.root_module.getGraph()` — may not exist in 0.13
  - `exe.step.inputs` — API may differ
  - `LazyPath.getPath3()` — may not exist in 0.13; use `getPath()` instead

- [ ] **TASK-3.9:** Port `build.zig` — `buildStep()` function
  - File: `build.zig:~380-450`
  - `exe_module.addImport("rules", rules_module)` — 0.13: `module.addImport(name, module)` should work
  - `b.addExecutable(.{ .name = "zlinter", .root_module = exe_module, .use_llvm = true })` — port to 0.13 API

- [ ] **TASK-3.10:** Port `build.zig` — `createRulesModule()` function
  - File: `build.zig:~560-600`
  - `std.ArrayListUnmanaged(std.Build.Module.Import)` — 0.13: use `std.ArrayList`
  - `module.addImport(name, module)` — verify 0.13 signature

- [ ] **TASK-3.11:** Port `build.zig` — `toZonString()` function
  - File: `build.zig:~340-350`
  - Uses `std.zon.stringify.serialize()` — **does not exist in 0.13**
  - **BLOCKER:** Need alternative serialization for rule configs
  - Options: (a) Write minimal ZON serializer, (b) Use comptime struct-to-string

- [ ] **TASK-3.12:** Port `build.zig` — `buildBuiltinRule()` and `buildCustomRule()`
  - File: `build.zig:~420-480`
  - `b.dependencyFromBuildZig(@This(), .{})` — exists in 0.13
  - `b.createModule()` — exists in 0.13
  - `b.path()` — exists in 0.13
  - Should be mostly compatible

- [ ] **TASK-3.13:** Port `build.zig` — `addBuildRulesStep()`
  - File: `build.zig:~490-510`
  - `b.addRunArtifact(b.addExecutable(...))` — port executable creation to 0.13 API

- [ ] **TASK-3.14:** Port `build.zig` — `Step.Run` usage
  - `run.addOutputFileArg()`, `run.addArg()`, `run.addFileArg()` — verify 0.13 API
  - `run.setCwd()`, `run.setEnvironmentVariable()` — verify 0.13 API
  - `run.expectExitCode()`, `run.expectStdOutEqual()` — verify 0.13 API
  - `run.has_side_effects` — verify 0.13 API
  - `run.rename_step_with_output_arg` — verify 0.13 API

- [ ] **TASK-3.15:** Port `build.zig` — coverage and install steps
  - `b.addInstallDirectory()`, `b.addInstallFile()`, `b.addInstallFileWithDir()` — exist in 0.13
  - `b.findProgram()` — exists in 0.13
  - `merge_coverage.addOutputDirectoryArg()` — verify 0.13 API

- [ ] **TASK-3.16:** Port `build.zig` — `BuildCwd` type
  - File: `build.zig` (used in `ZlinterRun.make()`)
  - Verify this type exists or implement for 0.13

- [ ] **TASK-3.17:** Port `build_rules.zig`
  - File: `build_rules.zig`
  - `std.process.cleanExit()` — may not exist in 0.13; use `std.process.exit(0)` instead
  - `std.heap.DebugAllocator(.{})` — verify 0.13 API

- [ ] **TASK-3.18:** Port `build_docs.zig`
  - File: `build_docs.zig`
  - Verify 0.13 compatibility

### Phase 4: Library Source Port

- [ ] **TASK-4.1:** Update `src/lib/ast.zig` — `iterateChildren()` for 0.13
  - File: `src/lib/ast.zig:91-114`
  - 0.14: Uses `zls.ast.iterateChildren()` with workaround for `fn_decl`
  - 0.13: ZLS 0.13 may not have `zls.ast.iterateChildren()`
  - **Need:** Implement manual child iteration using `std.zig.Ast` API
  - Alternative: Check if ZLS 0.13 has equivalent

- [ ] **TASK-4.2:** Update `src/lib/ast.zig` — version switches for `data.lhs`/`data.rhs`
  - File: `src/lib/ast.zig:131-136, 338-339, 419-432, 690-691`
  - 0.13 uses `data.lhs`/`data.rhs` — same as 0.14
  - Change: Add `.@"0.13"` alongside `.@"0.14"` in all switch branches

- [ ] **TASK-4.3:** Update `src/lib/session.zig` — `DocumentStore` config
  - File: `src/lib/session.zig:176-215`
  - 0.14: `.fromMainConfig(config)` 
  - 0.13: ZLS 0.13 `DocumentStore` config structure may differ
  - Need to check ZLS 0.13 `DocumentStore` initialization

- [ ] **TASK-4.4:** Update `src/lib/session.zig` — `Analyser.init()`
  - File: `src/lib/session.zig:217-230`
  - 0.14: `zls.Analyser.init(gpa, &document_store, &intern_pool, null)`
  - 0.13: ZLS 0.13 signature may differ — investigate

- [ ] **TASK-4.5:** Update `src/lib/session.zig` — `resolveTypeOfNode()`
  - File: `src/lib/session.zig:326-330`
  - 0.14: `self.analyser.resolveTypeOfNode(.{ .handle = doc.handle, .node = node })`
  - 0.13: ZLS 0.13 API may differ — investigate

- [ ] **TASK-4.6:** Update `src/lib/session.zig` — `resolveTypeOfTypeNode()`
  - File: `src/lib/session.zig:335-343`
  - `resolved_type.instanceTypeVal(&self.analyser)` — 0.14 returns optional directly
  - 0.13: May return error union — investigate ZLS 0.13

- [ ] **TASK-4.7:** Update `src/lib/session.zig` — container type resolution
  - File: `src/lib/session.zig:539-540`
  - 0.14: `.{ container.toNode(), container.handle.tree }`
  - 0.13: ZLS 0.13 `Type.data.container` may have different structure

- [ ] **TASK-4.8:** Update `src/lib/session.zig` — `dumpType()` debug method
  - File: `src/lib/session.zig:94-140`
  - Uses `zls.Analyser.Type` methods — verify all exist in ZLS 0.13
  - `t.data.ip_index` — verify 0.13 has this
  - `t.data.container` — verify 0.13 structure

- [ ] **TASK-4.9:** Update `src/lib/session.zig` — `zls.Config` fields
  - File: `src/lib/session.zig` (init function)
  - `config.zig_exe_path`, `config.zig_lib_path`, `config.global_cache_path`, `config.build_runner_path`, `config.builtin_path`
  - Verify these fields exist in ZLS 0.13 `Config`

- [ ] **TASK-4.10:** Update `src/lib/session.zig` — `zls.URI.fromPath()`
  - File: `src/lib/session.zig:253`
  - Verify 0.13 API

- [ ] **TASK-4.11:** Update `src/lib/explorer.zig` — `tree.render()` and `renderError()`
  - File: `src/lib/explorer.zig:33-34, 133-140`
  - 0.14: `tree.render(arena)` returns `![]u8`
  - 0.13: `tree.render(gpa)` returns `![]u8` — same API
  - Change: Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-4.12:** Update `src/lib/rendering.zig` — `Printer.initAuto()`
  - File: `src/lib/rendering.zig:248-260`
  - 0.14: `std.io.getStdOut()` with `.writer()`
  - 0.13: Same API — `std.io.getStdOut().writer()` exists
  - Change: Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-4.13:** Update `src/lib/zon.zig` — see Phase 2 (BLOCKER-1)

### Phase 5: Rules Port

- [ ] **TASK-5.1:** Update `src/rules/field_naming.zig`
  - File: `src/rules/field_naming.zig:164-165`
  - Add `.@"0.13"` alongside `.@"0.14"` (uses `data.rhs`)

- [ ] **TASK-5.2:** Update `src/rules/function_naming.zig`
  - File: `src/rules/function_naming.zig:99-100`
  - 0.14: `fn_proto.ast.return_type` (type `Index`)
  - 0.13: `fn_proto.ast.return_type` — same (not optional enum)
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.3:** Update `src/rules/import_ordering.zig`
  - File: `src/rules/import_ordering.zig:241-242`
  - Add `.@"0.13"` alongside `.@"0.14"` (uses `data.lhs`)

- [ ] **TASK-5.4:** Update `src/rules/no_deprecated.zig`
  - File: `src/rules/no_deprecated.zig:70-71, 89, 265-270, 406`
  - Add `.@"0.13"` alongside `.@"0.14"` for data access
  - Line 89: `if (zlinter.version.zig == .@"0.14")` — investigate what this guards
  - Line 406: `if (zlinter.version.zig != .@"0.14") return error.SkipZigTest` — test skip logic
  - `lookupSymbolFieldInit` — verify ZLS 0.13 API

- [ ] **TASK-5.5:** Update `src/rules/no_empty_block.zig`
  - File: `src/rules/no_empty_block.zig:199-200`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.6:** Update `src/rules/no_hidden_allocations.zig`
  - File: `src/rules/no_hidden_allocations.zig:84-85, 102-103`
  - Add `.@"0.13"` alongside `.@"0.14"`
  - Line 102-103: `resolveVarDeclAlias` call — verify ZLS 0.13 API

- [ ] **TASK-5.7:** Update `src/rules/no_literal_only_bool_expression.zig`
  - File: `src/rules/no_literal_only_bool_expression.zig:76-77`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.8:** Update `src/rules/no_orelse_unreachable.zig`
  - File: `src/rules/no_orelse_unreachable.zig:52-53`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.9:** Update `src/rules/no_swallow_error.zig`
  - File: `src/rules/no_swallow_error.zig:64-65, 151-155`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.10:** Update `src/rules/no_undefined.zig`
  - File: `src/rules/no_undefined.zig:125-126`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.11:** Update `src/rules/no_unused.zig`
  - File: `src/rules/no_unused.zig:54-55, 144-145, 165-166, 180-181`
  - Add `.@"0.13"` alongside `.@"0.14"`
  - Line 180-181: `container.toNode() == 0` — verify 0.13 `Node.Index` comparison

- [ ] **TASK-5.12:** Update `src/rules/require_errdefer_dealloc.zig`
  - File: `src/rules/require_errdefer_dealloc.zig:246-247`
  - Add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-5.13:** Audit all remaining rule files for version-specific code
  - Files: `declaration_naming.zig`, `field_ordering.zig`, `file_naming.zig`, `max_positional_args.zig`, `no_comment_out_code.zig`, `no_inferred_error_unions.zig`, `no_literal_args.zig`, `no_panic.zig`, `no_todo.zig`, `require_braces.zig`, `require_doc_comment.zig`, `switch_case_ordering.zig`
  - These may not have explicit version switches but use ZLS APIs that differ

### Phase 6: Executable & Integration Tests

- [ ] **TASK-6.1:** Update `src/exe/run_linter.zig` — stdin reader
  - File: `src/exe/run_linter.zig:60-61`
  - 0.14: `std.io.getStdIn().reader()`
  - 0.13: Same API — add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-6.2:** Update `src/exe/run_linter.zig` — diagnostics formatting
  - File: `src/exe/run_linter.zig:309-310`
  - 0.14: `"{}"` format for `std.zon.parse.Status`
  - 0.13: Depends on ZON parser solution (see Phase 2)

- [ ] **TASK-6.3:** Update `src/exe/run_linter.zig` — file reading
  - File: `src/exe/run_linter.zig:522-540`
  - 0.14: `file.reader().readAllAlloc(gpa, max_size)`
  - 0.13: Same API — add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-6.4:** Update `src/exe/run_linter.zig` — file writing
  - File: `src/exe/run_linter.zig:583-595, 627-640`
  - 0.14: `new_file.writer()` with `writeAll()`
  - 0.13: Same API — add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-6.5:** Update `src/exe/run_linter.zig` — `allocAstErrorMsg()`
  - File: `src/exe/run_linter.zig:648-665`
  - 0.14: `tree.renderError(err, writer)`
  - 0.13: Same API — add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-6.6:** Update `src/exe/wasm.zig`
  - File: `src/exe/wasm.zig`
  - Verify 0.13 compatibility (WASM target)

- [ ] **TASK-6.7:** Port `integration_tests/build.zig`
  - File: `integration_tests/build.zig`
  - Same build API changes as main `build.zig`
  - `b.createModule()` — exists in 0.13
  - `b.addTest()` — port to 0.13 API
  - `b.addRunArtifact()` — exists in 0.13
  - `b.addLibrary()` → `b.addStaticLibrary()`
  - `test_runner` field — verify 0.13 API

- [ ] **TASK-6.8:** Port `integration_tests/build.zig.zon`
  - File: `integration_tests/build.zig.zon`
  - Update `minimum_zig_version` and ZLS dependency

- [ ] **TASK-6.9:** Update `integration_tests/src/test_runner.zig`
  - File: `integration_tests/src/test_runner.zig`
  - `builtin.test_functions` — verify 0.13 API
  - `std.io.getStdOut().writer()` — same in 0.13
  - `std.posix.exit()` — verify 0.13 API

- [ ] **TASK-6.10:** Update `integration_tests/src/integration_test.zig`
  - File: `integration_tests/src/integration_test.zig`
  - `std.process.Child.run()` — verify 0.13 API
  - `std.ArrayListUnmanaged` — 0.13: use `std.ArrayList` or keep unmanaged

- [ ] **TASK-6.11:** Update `integration_tests/src/no_cats.zig`
  - File: `integration_tests/src/no_cats.zig`
  - Verify 0.13 compatibility

- [ ] **TASK-6.12:** Update `integration_tests/src/test_case_references.zig`
  - File: `integration_tests/src/test_case_references.zig`
  - Verify 0.13 compatibility

### Phase 7: Builtin Syntax & Language Changes

- [ ] **TASK-7.1:** Audit all `@intFromEnum` / `@enumFromInt` calls
  - 0.13: `@intFromEnum(x)` — no type parameter
  - 0.14+: Same (type inferred)
  - Search: `grep -r "@intFromEnum\|@enumFromInt" src/`
  - Fix: Any calls with explicit type parameter `@intFromEnum(T, x)` → `@intFromEnum(x)` or `@as(T, @intFromEnum(x))`

- [ ] **TASK-7.2:** Audit all `@intCast` / `@truncate` / `@floatCast` calls
  - 0.13: `@intCast(x)` — type inferred from context
  - Should be compatible, but verify

- [ ] **TASK-7.3:** Audit `std.ArrayList` vs `std.ArrayListUnmanaged` usage
  - 0.13: `std.ArrayList(T)` is managed, `std.ArrayListUnmanaged(T)` exists
  - The shims already handle this via `shims.ArrayList(T)`
  - Direct uses of `std.ArrayListUnmanaged` should be fine

- [ ] **TASK-7.4:** Audit `std.heap.DebugAllocator` usage
  - File: `src/exe/run_linter.zig:1`, `build_rules.zig:5`
  - 0.13: `std.heap.DebugAllocator(.{})` — verify API

- [ ] **TASK-7.5:** Audit `std.testing` API usage
  - `std.testing.expectEqual(expected, actual)` — 0.13 takes 2 args (same as 0.14)
  - `std.testing.tmpDir(.{})` — verify 0.13
  - `std.testing.allocator` — same

- [ ] **TASK-7.6:** Audit `std.json` usage
  - File: `src/lib/explorer.zig`
  - `std.json.stringifyAlloc`, `std.json.Value`, `std.json.ObjectMap`, `std.json.Array`
  - Verify 0.13 API compatibility

- [ ] **TASK-7.7:** Audit `std.process` API usage
  - `std.process.argsAlloc`, `std.process.argsFree` — same in 0.13
  - `std.process.Child.run()` — verify 0.13
  - `std.process.getEnvMap` — verify 0.13
  - `std.process.getCwdAlloc` — verify 0.13
  - `std.process.exit` — same
  - `std.process.cleanExit` — may not exist in 0.13

### Phase 8: Verification & Testing (Local)

The CI pipeline (`.github/workflows/windows.yml`) defines the canonical test sequence.
On Windows, the exact commands are:

```powershell
# 1. Unit tests
zig build unit-test

# 2. Self-lint
zig build lint

# 3. Integration tests
zig build integration-test

# 4. Integration check (compiled source linting)
zig build integration-check --summary all
```

- [ ] **TASK-8.1:** Verify compilation: `zig build --help`
  - Expected: Build script compiles without errors
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build --help`

- [ ] **TASK-8.2:** Verify unit tests: `zig build unit-test`
  - Expected: All unit tests pass
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build unit-test`

- [ ] **TASK-8.3:** Verify self-lint: `zig build lint`
  - Expected: Zlinter lints its own source without errors
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build lint`
  - Note: CI runs this as step 2 (before integration tests)

- [ ] **TASK-8.4:** Verify integration tests: `zig build integration-test`
  - Expected: All integration tests pass
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build integration-test`

- [ ] **TASK-8.5:** Verify integration check: `zig build integration-check --summary all`
  - Expected: Compiled source check passes with expected output
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build integration-check --summary all`
  - Note: CI uses `--summary all` flag

- [ ] **TASK-8.6:** Verify all tests: `zig build test`
  - Expected: All tests pass (unit + integration + check combined)
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build test`

- [ ] **TASK-8.7:** Verify docs generation: `zig build docs`
  - Expected: RULES.md regenerated without diff
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build docs`

- [ ] **TASK-8.8:** Verify website build: `zig build website`
  - Expected: WASM binary and website built
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build website`

- [ ] **TASK-8.9:** Per-rule integration test verification
  - For each rule, verify the integration test passes:
  - Command: `& "C:\Program Files\zig-0.13.0\zig.exe" build integration-test -Dtest_focus_on_rule=<rule_name>`
  - Rules to test: `field_naming`, `field_ordering`, `declaration_naming`, `function_naming`, `file_naming`, `import_ordering`, `no_unused`, `no_deprecated`, `no_empty_block`, `no_inferred_error_unions`, `no_orelse_unreachable`, `no_undefined`, `no_literal_only_bool_expression`, `no_hidden_allocations`, `switch_case_ordering`, `max_positional_args`, `no_comment_out_code`, `no_todo`, `no_literal_args`, `no_swallow_error`, `no_panic`, `require_braces`, `require_doc_comment`, `require_errdefer_dealloc`

### Phase 9: CI Workflow Setup

- [ ] **TASK-9.1:** Create `.github/workflows/windows-0.13.yml`
  - Copy from `.github/workflows/windows.yml`
  - Changes:
    - `name: windows-0.13` / `run-name: Windows 0.13 Tests`
    - Branch trigger: `0.13.x` instead of `0.14.x`
    - Zig version: `0.13.0` instead of `0.14.1`
    - Path filter: add `'.github/workflows/windows-0.13.yml'`
  - Keep same 4 test steps: `unit-test`, `lint`, `integration-test`, `integration-check --summary all`

- [ ] **TASK-9.2:** Create `.github/workflows/linux-0.13.yml`
  - Copy from `.github/workflows/linux.yml`
  - Same changes as TASK-9.1 but for Linux (`ubuntu-latest`)

- [ ] **TASK-9.3:** Update `.github/workflows/deploy.yml` (optional)
  - Only if 0.13 branch also deploys website
  - Change Zig version to `0.13.0`

- [ ] **TASK-9.4:** Verify CI locally (simulate)
  - Run the exact CI sequence on Windows:
    ```powershell
    & "C:\Program Files\zig-0.13.0\zig.exe" build unit-test
    & "C:\Program Files\zig-0.13.0\zig.exe" build lint
    & "C:\Program Files\zig-0.13.0\zig.exe" build integration-test
    & "C:\Program Files\zig-0.13.0\zig.exe" build integration-check --summary all
    ```

---

## File Change Summary

| File | Changes | Priority | Blocker |
|------|---------|----------|---------|
| `src/lib/version.zig` | Add `.@"0.13"` enum value | P0 | No |
| `build.zig.zon` | Update min version + ZLS dep | P0 | No |
| `src/lib/shims.zig` | Add 0.13 cases for ArrayList, NodeIndexShim, unwrapNode | P0 | No |
| `src/lib/zon.zig` | Complete rewrite for 0.13 (no std.zon) | P0 | **BLOCKER-1** |
| `build.zig` | Major port: addTest, addExecutable, addLibrary, watch inputs, ZON serialization | P0 | **BLOCKER-1** |
| `src/lib/session.zig` | ZLS 0.13 API adaptation | P0 | **BLOCKER-2** |
| `src/lib/ast.zig` | Add 0.13 cases, child iteration fallback | P1 | **BLOCKER-2** |
| `src/exe/run_linter.zig` | Add 0.13 cases for I/O, add 0.13 to switches | P1 | No |
| `src/lib/explorer.zig` | Add 0.13 cases | P1 | No |
| `src/lib/rendering.zig` | Add 0.13 cases | P1 | No |
| `build_rules.zig` | Fix `cleanExit` if needed | P1 | No |
| `build_docs.zig` | Verify compatibility | P2 | No |
| `src/rules/field_naming.zig` | Add 0.13 case | P1 | No |
| `src/rules/function_naming.zig` | Add 0.13 case | P1 | No |
| `src/rules/import_ordering.zig` | Add 0.13 case | P1 | No |
| `src/rules/no_deprecated.zig` | Add 0.13 cases, fix ZLS API | P1 | **BLOCKER-2** |
| `src/rules/no_empty_block.zig` | Add 0.13 case | P1 | No |
| `src/rules/no_hidden_allocations.zig` | Add 0.13 cases, fix ZLS API | P1 | **BLOCKER-2** |
| `src/rules/no_literal_only_bool_expression.zig` | Add 0.13 case | P1 | No |
| `src/rules/no_orelse_unreachable.zig` | Add 0.13 case | P1 | No |
| `src/rules/no_swallow_error.zig` | Add 0.13 cases | P1 | No |
| `src/rules/no_undefined.zig` | Add 0.13 case | P1 | No |
| `src/rules/no_unused.zig` | Add 0.13 cases | P1 | No |
| `src/rules/require_errdefer_dealloc.zig` | Add 0.13 case | P1 | No |
| `src/rules/*.zig` (others) | Audit for ZLS API usage | P2 | **BLOCKER-2** |
| `integration_tests/build.zig` | Port build API | P0 | No |
| `integration_tests/build.zig.zon` | Update deps | P0 | No |
| `integration_tests/src/test_runner.zig` | Verify API | P1 | No |
| `integration_tests/src/integration_test.zig` | Verify API | P1 | No |
| `.github/workflows/windows-0.13.yml` | New CI workflow for 0.13 | P1 | No |
| `.github/workflows/linux-0.13.yml` | New CI workflow for 0.13 | P2 | No |

---

## Testing Strategy

### CI Pipeline Reference

The canonical test sequence is defined in `.github/workflows/windows.yml` (and `linux.yml`):

```yaml
# .github/workflows/windows.yml (0.14.x branch, Zig 0.14.1)
steps:
  - run: zig build unit-test                          # Step 1: Unit tests
  - run: zig build lint                               # Step 2: Self-lint
  - run: zig build integration-test                   # Step 3: Integration tests
  - run: zig build integration-check --summary all    # Step 4: Compiled source check
```

For the 0.13 port, the same 4 steps apply but with Zig 0.13.0. The `--summary all` flag on `integration-check` shows all step summaries.

### Local Verification (Windows, Zig 0.13.0)

```powershell
$zig = "C:\Program Files\zig-0.13.0\zig.exe"
cd E:\Develop\Zig\zlinter

# Pre-flight: build script compiles
& $zig build --help

# CI Step 1: Unit tests
& $zig build unit-test

# CI Step 2: Self-lint
& $zig build lint

# CI Step 3: Integration tests
& $zig build integration-test

# CI Step 4: Integration check
& $zig build integration-check --summary all

# Bonus: All-in-one
& $zig build test

# Bonus: Docs & website
& $zig build docs
& $zig build website
```

### Pre-flight Checks
1. **Version gate:** `version.zig` compiles — verifies Zig 0.13 is detected
2. **Dependency resolution:** `zig fetch` resolves ZLS 0.13.0
3. **Build script compilation:** `zig build --help` works

### Incremental Verification (after each phase)
```powershell
# Phase 1: Foundation
cd E:\Develop\Zig\zlinter
& "C:\Program Files\zig-0.13.0\zig.exe" build --help

# Phase 2-3: Build system compiles
& "C:\Program Files\zig-0.13.0\zig.exe" build unit-test 2>&1 | Select-String "error:"

# Phase 4-5: Library compiles and unit tests pass
& "C:\Program Files\zig-0.13.0\zig.exe" build unit-test

# Phase 6: Integration tests
& "C:\Program Files\zig-0.13.0\zig.exe" build integration-test

# Full verification
& "C:\Program Files\zig-0.13.0\zig.exe" build test
```

### Acceptance Criteria (matches CI pipeline)
- [ ] `zig build unit-test` passes (CI step 1)
- [ ] `zig build lint` runs on self without errors (CI step 2)
- [ ] `zig build integration-test` passes (CI step 3)
- [ ] `zig build integration-check --summary all` passes (CI step 4)
- [ ] `zig build test` passes (all combined)
- [ ] `zig build docs` regenerates RULES.md without diff
- [ ] `zig build website` builds WASM binary
- [ ] All 24 built-in rules produce correct results on test cases

### Known Risks
1. **ZON parser:** If ZLS 0.13 doesn't expose a parser, writing one is ~500 lines
2. **ZLS API drift:** ZLS 0.13 analyser API may differ significantly from 0.14
3. **Watch inputs:** 0.13 doesn't support `step.addWatchInput()` — `--watch` mode may not work
4. **AST node tags:** 0.13 has `usingnamespace` tag (removed in 0.15) — rules may need to handle it
5. **FnProto return type:** 0.13 `fn_proto.ast.return_type` is `Index` (not optional) — simpler than 0.15+

---

## Quick Reference: 0.13 vs 0.14 API Differences

| API | Zig 0.13 | Zig 0.14 |
|-----|----------|----------|
| `b.addTest()` | `.root_source_file`, `.target`, `.optimize` | `.root_module`, `.use_llvm` |
| `b.addExecutable()` | `.root_source_file`, `.target`, `.optimize` | `.root_module` |
| `b.addStaticLibrary()` | `.root_source_file`, `.target`, `.optimize` | `.root_module` |
| `b.addModule()` | `(name, .{ .root_source_file, .imports, ... })` | Same |
| `b.createModule()` | `.{ .root_source_file, .imports, ... }` | Same |
| `b.graph.host` | `ResolvedTarget` | Same |
| `b.graph.zig_exe` | `[:0]const u8` | Same |
| `b.graph.global_cache_root` | `Cache.Directory` | Same |
| `b.graph.zig_lib_directory` | **Does not exist** | Exists |
| `b.zig_lib_dir` | `?LazyPath` | May not exist |
| `step.addWatchInput()` | **Does not exist** | Exists |
| `step.addDirectoryWatchInput()` | **Does not exist** | Exists |
| `LazyPath` | `.src_path { .owner, .sub_path }` | `.path { ... }` (different) |
| `std.zon` | **Does not exist** | `std.zon.parse`, `std.zon.stringify` |
| `std.ArrayList(T)` | Managed (has allocator) | Managed (has allocator) |
| `std.ArrayListUnmanaged(T)` | Exists | Exists |
| `std.io.getStdOut().writer()` | Exists (old API) | Exists (old API) |
| `file.reader()` | Exists (old API) | Exists (old API) |
| `Ast.Node.Index` | `u32` | `u32` |
| `Ast.Node.Data` | `struct { lhs, rhs }` | `struct { lhs, rhs }` |
| `Ast.render()` | `![]u8` | `![]u8` |
| `Ast.renderError()` | `(err, writer)` | `(err, writer)` |
| `tree.nodes.items(.tag)` | Exists | Exists |
| `fn_proto.ast.return_type` | `Index` | `Index` |
| `fullContainerDecl()` | Exists | Exists |
| `fullFnProto()` | Exists | Exists |
| `@intFromEnum(x)` | Type inferred | Type inferred |
| `std.process.cleanExit()` | May not exist | Exists |
| `std.heap.DebugAllocator(.{})` | Exists | Exists |
| Node tag `usingnamespace` | **Exists** | Exists (deprecated) |
