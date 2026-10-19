# Porting Zlinter to Zig 0.13 â€” Analysis & Task List

> Branch: `0.13.x` | Target: Zig 0.13.0 | Approach: **Multi-version** (add `.@"0.13"` alongside existing versions)
> Created: 2026-10-19 | Updated: 2026-10-19

---

## Executive Summary

Zlinter targets Zig 0.14+ and uses ZLS 0.14.0 as a dependency. Porting to Zig 0.13.0 requires changes across **19 source files**, the **build system**, and the **ZLS dependency**. The single biggest blocker is that **`std.zon` does not exist in Zig 0.13** â€” the ZON parser was introduced in 0.14. This affects rule config file parsing.

The `std.zig.Ast` API is largely compatible between 0.13 and 0.14 (both use `data.lhs`/`data.rhs`), which means the AST shims need minimal changes. The build system API and ZLS API have the most significant differences.

**Decision:** Keep the existing multi-version architecture. Add `.@"0.13"` alongside `.@"0.14"` in all version switches, rather than stripping the version system.

---

## Critical Blockers

### BLOCKER-1: `std.zon` does not exist in Zig 0.13

| Aspect | Details |
|--------|---------|
| Impact | HIGH â€” Rule configs parsed from `.zon` files will not work |
| Affected files | `src/lib/zon.zig`, `src/exe/run_linter.zig`, `build.zig` (rule config serialization) |
| Current usage | `std.zon.parse.fromSlice(T, gpa, slice, diagnostics, options)` and `std.zon.parse.Status` |
| Options | (a) Write a minimal ZON parser (~500 lines), (b) Use ZLS 0.13's internal ZON parser if available, (c) Switch to JSON configs, (d) Embed configs as Zig source instead of ZON |

**Recommendation:** Option (b) first â€” check if ZLS 0.13 exposes a ZON parser. If not, option (a) â€” a minimal ZON parser that handles the subset of ZON used by rule configs (structs with primitive fields, enums, slices).

### BLOCKER-2: ZLS 0.13 API compatibility

| Aspect | Details |
|--------|---------|
| Impact | HIGH â€” Core analyser, document store, and type resolution APIs differ |
| Current dep | `zls 0.14.0` (`git+https://github.com/zigtools/zls?ref=0.14.0`) |
| Target dep | `zls 0.13.0` (`git+https://github.com/zigtools/zls?ref=0.13.0`) â€” **FETCHED** |
| Affected files | `src/lib/session.zig`, `src/lib/ast.zig`, `build.zig` (zls version switch) |

Key ZLS API differences to investigate:
- `zls.DocumentStore` config structure (0.14 uses `.fromMainConfig(config)`, 0.13 may differ)
- `zls.Analyser.init()` signature (0.14: `(gpa, &document_store, &intern_pool, null)`, 0.13 may differ)
- `zls.Analyser.resolveTypeOfNode()` signature
- `zls.Analyser.Type` methods (`instanceTypeVal`, `resolveDeclLiteralResultType`, etc.)
- `zls.ast.iterateChildren()` â€” may not exist in ZLS 0.13
- `zls.DiagnosticsCollection` â€” may differ
- `zls.analyser.InternPool` â€” may differ
- `zls.Config` fields (`zig_exe_path`, `zig_lib_path`, `global_cache_path`)
- `zls.URI.fromPath()` â€” may differ

---

## Task List

### Phase 1: Foundation (blocking everything else) â€” **COMPLETED**

- [x] **TASK-1.1:** Add `.@"0.13"` to `src/lib/version.zig` enum and detection logic
  - File: `src/lib/version.zig`
  - Change: Added `.@"0.13"` to enum, added `else if (major == 0 and minor == 13) .@"0.13"` branch
  - Status: DONE

- [x] **TASK-1.2:** Update `build.zig.zon` for 0.13 syntax and ZLS dependency
  - File: `build.zig.zon`
  - Changes:
    - `.name = .zlinter` â†’ `.name = "zlinter"` (0.13 requires string literal)
    - Removed `.fingerprint` (not supported in 0.13)
    - Removed `.minimum_zig_version` (not supported in 0.13)
    - ZLS dependency: `0.14.0` â†’ `0.13.0` (fetched, hash: `122073c0...`)
  - Status: DONE

- [x] **TASK-1.3:** Add `.@"0.13"` case to `shims.ArrayList()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:188-189`
  - Change: `.@"0.13", .@"0.15", .@"0.16" => std.ArrayList(T)` (0.13 has managed ArrayList)
  - Status: DONE

- [x] **TASK-1.4:** Add `.@"0.13"` case to `NodeIndexShim.toNodeIndex()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:62-66`
  - Change: Updated comment to `// == 0.13.x and 0.14.x` (0.13 `Ast.Node.Index` is `u32`, not enum)
  - Status: DONE

- [x] **TASK-1.5:** Add `.@"0.13"` cases to `unwrapNode()` in `src/lib/shims.zig`
  - File: `src/lib/shims.zig:91-113`
  - Change: Added `.@"0.13"` alongside `.@"0.14"` in all four switch branches (same `data.lhs`/`data.rhs` access)
  - Status: DONE

- [x] **TASK-1.6:** Verify `nodeTag`, `nodeData`, `nodeMainToken`, `tokenTag` shims work for 0.13
  - File: `src/lib/shims.zig:115-145`
  - The `std.meta.hasMethod` checks fall through to `tree.nodes.items(.tag)[node]` pattern â€” same in 0.13
  - Updated comments from `// 0.14.x` to `// 0.13.x and 0.14.x`
  - Status: DONE

- [x] **TASK-1.7:** Update `integration_tests/build.zig.zon` for 0.13 syntax
  - File: `integration_tests/build.zig.zon`
  - Changes: `.name = .tests` â†’ `.name = "tests"`, removed `.fingerprint`
  - Status: DONE

### Phase 2: ZON Parser (BLOCKER-1 resolution) â€” **COMPLETED**

- [x] **TASK-2.1:** Research ZLS 0.13 for internal ZON parser availability
  - Check: ZLS 0.13.0 package at `C:\Users\pkofler\AppData\Local\zig\p\122073c0...` for any `zon` module or parser
  - **Result: NOT FOUND.** ZLS 0.13 exports no `zon` module. Zero `std.zon` usage in ZLS 0.13 source. `std/zon.zig` does not exist in Zig 0.13 stdlib.
  - Proceeding to TASK-2.2 (write minimal ZON parser)

- [x] **TASK-2.2:** Implement minimal ZON parser for rule configs
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
  - Status: DONE â€” Custom recursive descent parser (~350 lines) handling structs, enums (incl. `.@"quoted"`), bools, ints, floats, strings, slices, optionals, and nested structs. 9/9 standalone tests pass.

- [x] **TASK-2.3:** Update `zon.Diagnostics` type for 0.13
  - File: `src/lib/zon.zig:1-4`
  - 0.14: `std.zon.parse.Status`
  - 0.13: No `std.zon` â€” use custom diagnostics type or `void`

- [x] **TASK-2.4:** Update `parseFileAlloc` file reading for 0.13
  - File: `src/lib/zon.zig:64`
  - Fixed: `.init(gpa)` shorthand not valid in 0.13 â€” changed to `std.ArrayList(u8).init(gpa)`
  - Verified: file reading APIs work in Zig 0.13.0 â€” Status: DONE

### Phase 3: Build System Port â€” **IN PROGRESS (8/18)**

- [x] **TASK-3.1:** Port `build.zig` â€” `zls_version` switch
  - File: `build.zig:3-7`
  - Change: Add `.@"0.13" => "0.13.0"` to the switch
  - Status: DONE

- [x] **TASK-3.2:** Port `build.zig` â€” `b.addModule()` calls
  - File: `build.zig:227`
  - 0.13: `b.addModule(name, .{ .root_source_file = ..., .target = ..., .optimize = ..., .imports = ... })`
  - Verify: `Module.CreateOptions` fields match â€” VERIFIED. Single `addModule` call at line 227 already uses 0.13-compatible API (`.root_source_file`, `.target`, `.optimize`, `.imports`). `Module.Import` struct fields (`name`, `module`) match. No changes needed.
  - Status: DONE

- [x] **TASK-3.3:** Port `build.zig` â€” `b.createModule()` calls
  - File: `build.zig` (multiple locations)
  - Both 0.13 and 0.14 have `b.createModule(options)` â€” should be compatible
  - Verified: All 9 `b.createModule()` calls use `.root_source_file`, `.target`, `.optimize`, `.imports` â€” all valid 0.13 `Module.CreateOptions` fields. No changes needed.
  - Status: DONE

- [x] **TASK-3.4:** Port `build.zig` â€” `b.addTest()` calls
  - File: `build.zig:135-138` and similar
  - 0.14: `b.addTest(.{ .root_module = zlinter_lib_module, .use_llvm = test_coverage })`
  - 0.13: `b.addTest(.{ .root_source_file = b.path("src/lib/zlinter.zig"), .target = target, .optimize = optimize })`
  - **Major change:** 0.13 `TestOptions` has `root_source_file`, not `root_module` (no imports field)
  - Extracted `zls_module` to a variable; after `addTest`, added imports via `root_module.addImport()` for both test executables
  - Status: DONE

- [x] **TASK-3.5:** Port `build.zig` â€” `b.addExecutable()` calls
  - File: `build.zig` (wasm exe, docs exe, build_rules exe)
  - 0.14: `b.addExecutable(.{ .name = "wasm", .root_module = b.createModule(.{...}) })`
  - 0.13: `b.addExecutable(.{ .name = "wasm", .root_source_file = b.path("..."), .target = ..., .optimize = ... })`
  - **Major change:** 0.13 `ExecutableOptions` has `root_source_file`, not `root_module`
  - Ported all 4 `addExecutable` calls: wasm_exe, build_docs, zlinter_exe, build_rules
  - Imports added via `exe.root_module.addImport()` after creation
  - `linkSystemLibrary` moved to `zlinter_exe.root_module.linkSystemLibrary()`
  - Status: DONE

- [x] **TASK-3.6:** Port `build.zig` â€” `b.addLibrary()` calls
  - File: `build.zig` (lint step)
  - 0.14: `b.addLibrary(.{ .name = "zlinter", .root_module = zlinter_lib_module })`
  - 0.13: `b.addStaticLibrary(.{ .name = "zlinter", .root_source_file = ..., .target = ..., .optimize = ... })`
  - Note: 0.13 uses `addStaticLibrary`, not `addLibrary`
  - Change: Replaced `b.addLibrary` with `b.addStaticLibrary`, extracted to variable, added `zls` import via `root_module.addImport()`, appended `.compiled(zlinter_lib)` to include list
  - Status: DONE

- [x] **TASK-3.7:** Port `build.zig` — `addWatchInput` function
  - File: `build.zig` (addWatchInput at ~625, docs section at ~528)
  - 0.14: Uses `step.addDirectoryWatchInput()`, `step.addWatchInput()`, `step.addDirectoryWatchInputFromPath()`
  - 0.13: These methods **do not exist** on `Step`
  - **Change:** Added early return `if (version.zig == .@"0.13") return;` in addWatchInput (watch mode unsupported in 0.13)
  - Added `.@"0.13" => unreachable` to inner version switch
  - Guarded `step.addDirectoryWatchInput()` in docs section with version check
  - Replaced `getPath3()` with `getPath2()` + `std.fs.cwd().openDir()` in docs section for 0.13
  - Status: DONE

- [x] **TASK-3.8:** Port `build.zig` â€” `ZlinterRun.create()` and `make()`
  - File: `build.zig:~600-750`
  - `b.graph.zig_exe` â€” exists in 0.13 as `[:0]const u8`
  - `b.graph.global_cache_root` â€” in 0.13 it's `Cache.Directory`
  - `b.graph.zig_lib_directory` â€” **does not exist in 0.13**; use `b.zig_lib_dir` (`?LazyPath`)
  - `exe.root_module.getGraph()` â€” may not exist in 0.13
  - `exe.step.inputs` â€” API may differ
  - `LazyPath.getPath3()` â€” may not exist in 0.13; use `getPath()` instead

- [ ] **TASK-3.9:** Port `build.zig` â€” `buildStep()` function
  - File: `build.zig:~380-450`
  - `exe_module.addImport("rules", rules_module)` â€” 0.13: `module.addImport(name, module)` should work
  - `b.addExecutable(.{ .name = "zlinter", .root_module = exe_module, .use_llvm = true })` â€” port to 0.13 API

- [ ] **TASK-3.10:** Port `build.zig` â€” `createRulesModule()` function
  - File: `build.zig:~560-600`
  - `std.ArrayListUnmanaged(std.Build.Module.Import)` â€” 0.13: use `std.ArrayList`
  - `module.addImport(name, module)` â€” verify 0.13 signature

- [ ] **TASK-3.11:** Port `build.zig` â€” `toZonString()` function
  - File: `build.zig:~340-350`
  - Uses `std.zon.stringify.serialize()` â€” **does not exist in 0.13**
  - **BLOCKER:** Need alternative serialization for rule configs

- [ ] **TASK-3.12:** Port `build.zig` â€” `buildBuiltinRule()` and `buildCustomRule()`
  - File: `build.zig:~420-480`
  - `b.dependencyFromBuildZig(@This(), .{})` â€” exists in 0.13
  - `b.createModule()` â€” exists in 0.13
  - Should be mostly compatible

- [ ] **TASK-3.13:** Port `build.zig` â€” `addBuildRulesStep()`
  - File: `build.zig:~490-510`
  - `b.addRunArtifact(b.addExecutable(...))` â€” port executable creation to 0.13 API

- [ ] **TASK-3.14:** Port `build.zig` â€” `Step.Run` usage
  - `run.addOutputFileArg()`, `run.addArg()`, `run.addFileArg()` â€” verify 0.13 API
  - `run.setCwd()`, `run.setEnvironmentVariable()` â€” verify 0.13 API
  - `run.expectExitCode()`, `run.expectStdOutEqual()` â€” verify 0.13 API
  - `run.has_side_effects` â€” verify 0.13 API

- [ ] **TASK-3.15:** Port `build.zig` â€” coverage and install steps
  - `b.addInstallDirectory()`, `b.addInstallFile()`, `b.addInstallFileWithDir()` â€” exist in 0.13
  - `b.findProgram()` â€” exists in 0.13
  - `merge_coverage.addOutputDirectoryArg()` â€” verify 0.13 API

- [ ] **TASK-3.16:** Port `build.zig` â€” `BuildCwd` type
  - File: `build.zig` (used in `ZlinterRun.make()`)
  - Verify this type exists or implement for 0.13

- [ ] **TASK-3.17:** Port `build_rules.zig`
  - File: `build_rules.zig`
  - `std.process.cleanExit()` â€” may not exist in 0.13; use `std.process.exit(0)` instead
  - `std.heap.DebugAllocator(.{})` â€” verify 0.13 API

- [ ] **TASK-3.18:** Port `build_docs.zig`
  - File: `build_docs.zig`
  - Verify 0.13 compatibility

### Phase 4: Library Source Port â€” **PENDING**

- [ ] **TASK-4.1:** Update `src/lib/ast.zig` â€” `iterateChildren()` for 0.13
  - File: `src/lib/ast.zig:91-114`
  - 0.13: ZLS 0.13 may not have `zls.ast.iterateChildren()`
  - **Need:** Implement manual child iteration using `std.zig.Ast` API

- [ ] **TASK-4.2:** Update `src/lib/ast.zig` â€” version switches for `data.lhs`/`data.rhs`
  - File: `src/lib/ast.zig:131-136, 338-339, 419-432, 690-691`
  - Add `.@"0.13"` alongside `.@"0.14"` in all switch branches

- [ ] **TASK-4.3:** Update `src/lib/session.zig` â€” `DocumentStore` config
  - File: `src/lib/session.zig:176-215`
  - 0.14: `.fromMainConfig(config)`
  - 0.13: ZLS 0.13 `DocumentStore` config structure may differ

- [ ] **TASK-4.4:** Update `src/lib/session.zig` â€” `Analyser.init()`
  - File: `src/lib/session.zig:217-230`
  - 0.14: `zls.Analyser.init(gpa, &document_store, &intern_pool, null)`
  - 0.13: ZLS 0.13 signature may differ

- [ ] **TASK-4.5:** Update `src/lib/session.zig` â€” `resolveTypeOfNode()`
  - File: `src/lib/session.zig:326-330`
  - 0.14: `self.analyser.resolveTypeOfNode(.{ .handle = doc.handle, .node = node })`
  - 0.13: ZLS 0.13 API may differ

- [ ] **TASK-4.6:** Update `src/lib/session.zig` â€” `resolveTypeOfTypeNode()`
  - File: `src/lib/session.zig:335-343`
  - `resolved_type.instanceTypeVal(&self.analyser)` â€” 0.14 returns optional directly
  - 0.13: May return error union

- [ ] **TASK-4.7:** Update `src/lib/session.zig` â€” container type resolution
  - File: `src/lib/session.zig:539-540`
  - 0.14: `.{ container.toNode(), container.handle.tree }`
  - 0.13: ZLS 0.13 `Type.data.container` may have different structure

- [ ] **TASK-4.8:** Update `src/lib/session.zig` â€” `dumpType()` debug method
  - File: `src/lib/session.zig:94-140`
  - Uses `zls.Analyser.Type` methods â€” verify all exist in ZLS 0.13

- [ ] **TASK-4.9:** Update `src/lib/session.zig` â€” `zls.Config` fields
  - File: `src/lib/session.zig` (init function)
  - Verify fields exist in ZLS 0.13 `Config`

- [ ] **TASK-4.10:** Update `src/lib/session.zig` â€” `zls.URI.fromPath()`
  - File: `src/lib/session.zig:253`
  - Verify 0.13 API

- [ ] **TASK-4.11:** Update `src/lib/explorer.zig` â€” `tree.render()` and `renderError()`
  - File: `src/lib/explorer.zig:33-34, 133-140`
  - 0.13: Same API as 0.14 â€” add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-4.12:** Update `src/lib/rendering.zig` â€” `Printer.initAuto()`
  - File: `src/lib/rendering.zig:248-260`
  - 0.13: Same API as 0.14 â€” add `.@"0.13"` alongside `.@"0.14"`

- [ ] **TASK-4.13:** Update `src/lib/zon.zig` â€” see Phase 2 (BLOCKER-1)

### Phase 5: Rules Port â€” **PENDING**

- [ ] **TASK-5.1:** Update `src/rules/field_naming.zig` â€” add `.@"0.13"` alongside `.@"0.14"` (line 164-165)
- [ ] **TASK-5.2:** Update `src/rules/function_naming.zig` â€” add `.@"0.13"` alongside `.@"0.14"` (line 99-100)
- [ ] **TASK-5.3:** Update `src/rules/import_ordering.zig` â€” add `.@"0.13"` alongside `.@"0.14"` (line 241-242)
- [ ] **TASK-5.4:** Update `src/rules/no_deprecated.zig` â€” add `.@"0.13"` cases, fix ZLS API (lines 70-71, 89, 265-270, 406)
- [ ] **TASK-5.5:** Update `src/rules/no_empty_block.zig` â€” add `.@"0.13"` alongside `.@"0.14"` (line 199-200)
- [ ] **TASK-5.6:** Update `src/rules/no_hidden_allocations.zig` â€” add `.@"0.13"` cases, fix ZLS API (lines 84-85, 102-103)
- [ ] **TASK-5.7:** Update `src/rules/no_literal_only_bool_expression.zig` â€” add `.@"0.13"` (line 76-77)
- [ ] **TASK-5.8:** Update `src/rules/no_orelse_unreachable.zig` â€” add `.@"0.13"` (line 52-53)
- [ ] **TASK-5.9:** Update `src/rules/no_swallow_error.zig` â€” add `.@"0.13"` cases (lines 64-65, 151-155)
- [ ] **TASK-5.10:** Update `src/rules/no_undefined.zig` â€” add `.@"0.13"` (line 125-126)
- [ ] **TASK-5.11:** Update `src/rules/no_unused.zig` â€” add `.@"0.13"` cases (lines 54-55, 144-145, 165-166, 180-181)
- [ ] **TASK-5.12:** Update `src/rules/require_errdefer_dealloc.zig` â€” add `.@"0.13"` (line 246-247)
- [ ] **TASK-5.13:** Audit remaining rule files for ZLS API usage

### Phase 6: Executable & Integration Tests â€” **PENDING**

- [ ] **TASK-6.1:** Update `src/exe/run_linter.zig` â€” stdin reader (line 60-61)
- [ ] **TASK-6.2:** Update `src/exe/run_linter.zig` â€” diagnostics formatting (line 309-310)
- [ ] **TASK-6.3:** Update `src/exe/run_linter.zig` â€” file reading (line 522-540)
- [ ] **TASK-6.4:** Update `src/exe/run_linter.zig` â€” file writing (line 583-595, 627-640)
- [ ] **TASK-6.5:** Update `src/exe/run_linter.zig` â€” `allocAstErrorMsg()` (line 648-665)
- [ ] **TASK-6.6:** Update `src/exe/wasm.zig` â€” verify 0.13 compatibility
- [ ] **TASK-6.7:** Port `integration_tests/build.zig` â€” build API changes
- [ ] **TASK-6.8:** Port `integration_tests/build.zig.zon` â€” **DONE** (TASK-1.7)
- [ ] **TASK-6.9:** Update `integration_tests/src/test_runner.zig` â€” verify API
- [ ] **TASK-6.10:** Update `integration_tests/src/integration_test.zig` â€” verify API
- [ ] **TASK-6.11:** Update `integration_tests/src/no_cats.zig` â€” verify 0.13
- [ ] **TASK-6.12:** Update `integration_tests/src/test_case_references.zig` â€” verify 0.13

### Phase 7: Builtin Syntax & Language Changes â€” **PENDING**

- [ ] **TASK-7.1:** Audit all `@intFromEnum` / `@enumFromInt` calls
- [ ] **TASK-7.2:** Audit all `@intCast` / `@truncate` / `@floatCast` calls
- [ ] **TASK-7.3:** Audit `std.ArrayList` vs `std.ArrayListUnmanaged` usage
- [ ] **TASK-7.4:** Audit `std.heap.DebugAllocator` usage
- [ ] **TASK-7.5:** Audit `std.testing` API usage
- [ ] **TASK-7.6:** Audit `std.json` usage
- [ ] **TASK-7.7:** Audit `std.process` API usage

### Phase 8: Verification & Testing (Local) â€” **PENDING**

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
- [ ] **TASK-8.2:** Verify unit tests: `zig build unit-test`
- [ ] **TASK-8.3:** Verify self-lint: `zig build lint`
- [ ] **TASK-8.4:** Verify integration tests: `zig build integration-test`
- [ ] **TASK-8.5:** Verify integration check: `zig build integration-check --summary all`
- [ ] **TASK-8.6:** Verify all tests: `zig build test`
- [ ] **TASK-8.7:** Verify docs generation: `zig build docs`
- [ ] **TASK-8.8:** Verify website build: `zig build website`
- [ ] **TASK-8.9:** Per-rule integration test verification

### Phase 9: CI Workflow Setup â€” **PENDING**

- [ ] **TASK-9.1:** Create `.github/workflows/windows-0.13.yml`
  - Copy from `.github/workflows/windows.yml`
  - Changes: branch `0.13.x`, Zig `0.13.0`, name `windows-0.13`
  - Same 4 test steps: `unit-test`, `lint`, `integration-test`, `integration-check --summary all`
- [ ] **TASK-9.2:** Create `.github/workflows/linux-0.13.yml`
- [ ] **TASK-9.3:** Update `.github/workflows/deploy.yml` (optional)
- [ ] **TASK-9.4:** Verify CI locally (simulate)

---

## Progress Summary

| Phase | Status | Tasks Done | Tasks Total |
|-------|--------|-----------|-------------|
| Phase 1: Foundation | **DONE** | 7/7 | 7 |
| Phase 2: ZON Parser | **DONE** | 4/4 | 4 |
| Phase 3: Build System | IN PROGRESS | 8/18 | 18 |
| Phase 4: Library Source | PENDING | 0/13 | 13 |
| Phase 5: Rules | PENDING | 0/13 | 13 |
| Phase 6: Executable & Integration | PENDING | 0/12 | 12 |
| Phase 7: Language Audit | PENDING | 0/7 | 7 |
| Phase 8: Verification | PENDING | 0/9 | 9 |
| Phase 9: CI Workflows | PENDING | 0/4 | 4 |
| **Total** | | **20/97** | **97** |

### Files Changed So Far

```
build.zig                       â€” added .@"0.13" => "0.13.0" to zls_version switch
build.zig.zon                   â€” 0.13 ZON syntax, ZLS 0.13.0 dep
integration_tests/build.zig.zon â€” 0.13 ZON syntax
src/lib/version.zig             â€” added .@"0.13" enum value
src/lib/shims.zig               â€” added .@"0.13" to unwrapNode, toNodeIndex, ArrayList
src/lib/zon.zig                 â€” minimal ZON parser for 0.13 (structs, enums, bools, ints, strings, slices)
PORTING_0.13.md                 â€” this document
```

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
3. **Watch inputs:** 0.13 doesn't support `step.addWatchInput()` â€” `--watch` mode may not work
4. **AST node tags:** 0.13 has `usingnamespace` tag (removed in 0.15) â€” rules may need to handle it
5. **FnProto return type:** 0.13 `fn_proto.ast.return_type` is `Index` (not optional) â€” simpler than 0.15+

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
| `build.zig.zon` `.name` | String literal `"name"` | Enum literal `.name` |
| `build.zig.zon` `.fingerprint` | **Not supported** | Supported |
| `build.zig.zon` `.minimum_zig_version` | **Not supported** | Supported |
| `build.zig.zon` dep `.hash` format | Plain hex string | Prefixed format (`pkg-version-...`) |
