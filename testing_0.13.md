# Testing Task List - Zig 0.13 Branch

Goal: improve unit test coverage on low-coverage files. Integration tests exist but do not count toward kcov coverage. All tests use `zlinter.testing.testRunRule` with `LintProblemExpectation` assertions.

Pattern reference: `src/rules/no_panic.zig`, `src/rules/no_undefined.zig`, `src/rules/no_orelse_unreachable.zig`

Run tests: `zig build unit-test`
Run coverage: `zig build unit-test -Dcoverage=true`

---

## Priority 1: `src/rules/field_ordering.zig` - 2.06% (95/97 lines missed)

Has only `refAllDecls` - zero actual unit tests. Largest coverage gap.

### TASK-1.1: Struct ascending with fix

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "struct ascending with fix"`
- **Source:** `const S = struct { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem, `slice = "b: u32, a: u32"`, message = `"Struct fields should be in alphabetical order"`, with a `fix` field (verify `.fix` is non-null)
- **Covers:** struct path, PriorityQueue sorting, problem creation, fix generation, `nodeSpanIncludingComments`
- **How:** copy pattern from `no_orelse_unreachable.zig` test block. Use `testRunRule` with `LintProblemExpectation` array. Include `.fix` assertion - copy the `fix` structure from `no_unused.zig` test (`.fix = .{ .start = N, .end = M, .text = "..." }`). Run the test once, read the debug output to get exact byte offsets and fix text, then fill in the expectation.

### TASK-1.2: Struct descending order

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "struct descending"`
- **Source:** `const S = struct { a: u32, b: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_descending, .severity = .@"error" } }`
- **Expected:** 1 problem, severity = `.@"error"`, message = `"Struct fields should be in reverse alphabetical order"`
- **Covers:** `Field.cmp` with `alphabetical_descending` (different sort order path)

### TASK-1.3: Enum field ordering

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "enum ordering"`
- **Source:** `const E = enum { b, a };`
- **Config:** `Config{ .enum_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }` (struct/union off by default)
- **Expected:** 1 problem, message = `"Enum fields should be in alphabetical order"`
- **Covers:** `keyword_enum` branch in the container kind switch

### TASK-1.4: Union field ordering

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "union ordering"`
- **Source:** `const U = union { b: u32, a: u32 };`
- **Config:** `Config{ .union_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem, message = `"Union fields should be in alphabetical order"`
- **Covers:** `keyword_union` branch in the container kind switch

### TASK-1.5: Packed struct excluded (default config)

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "packed struct excluded by default"`
- **Source:** `const P = packed struct(u32) { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }` (exclude_packed_structs defaults to `true`)
- **Expected:** 0 problems (`&.{}`)
- **Covers:** `exclude_packed_structs = true` - `break :kind null` branch

### TASK-1.6: Packed struct included

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "packed struct included"`
- **Source:** `const P = packed struct(u32) { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning }, .exclude_packed_structs = false }`
- **Expected:** 1 problem
- **Covers:** `exclude_packed_structs = false` - falls through to struct check, `layout_token` = `keyword_packed` branch

### TASK-1.7: Extern struct excluded (default config)

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "extern struct excluded by default"`
- **Source:** `const E = extern struct { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }` (exclude_extern_structs defaults to `true`)
- **Expected:** 0 problems
- **Covers:** `exclude_extern_structs = true` - `break :kind null` branch

### TASK-1.8: Extern struct included

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "extern struct included"`
- **Source:** `const E = extern struct { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning }, .exclude_extern_structs = false }`
- **Expected:** 1 problem
- **Covers:** `exclude_extern_structs = false` - falls through to struct check, `layout_token` = `keyword_extern` branch

### TASK-1.9: All orders off

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "all orders off"`
- **Source:** `const S = struct { b: u32, a: u32 };`
- **Config:** `Config{}` (all defaults: struct_field_order = `.off`, enum/union = ascending+warning - but no enum/union in source)
- **Expected:** 0 problems
- **Covers:** `order_with_severity.order == .off or order_with_severity.severity == .off` - `continue :nodes`

### TASK-1.10: Already sorted fields

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "already sorted"`
- **Source:** `const S = struct { a: u32, b: u32 }; const E = enum { a, b }; const U = union { a: u32, b: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }` (enum/union defaults are ascending+warning)
- **Expected:** 0 problems
- **Covers:** `maybe_first_problem_index` stays `null` - no problem appended

### TASK-1.11: Fields with doc comments - fix preserves comments

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "doc comments preserved in fix"`
- **Source:**

  ```zig
  const S = struct {
      /// doc for b
      b: u32,
      /// doc for a
      a: u32,
  };
  ```

- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem, verify `.fix` is non-null. The fix text should include the doc comments in the correct order.
- **Covers:** `firstTokenIncludingComments` (doc_comment token walk-back), `nodeSpanIncludingComments` with comments in span

### TASK-1.12: Single-line container with fix

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "single line container"`
- **Source:** `const S = struct { b: u32, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem with fix. Fix text should be `a: u32, b: u32` (no trailing comma, single-line).
- **Covers:** `is_multiline = false` path in fix generation, `consume_trailing_comma = true` in `nodeSpanIncludingComments`

### TASK-1.13: Nested struct - only inner has problem

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "nested struct"`
- **Source:**

  ```zig
  const Outer = struct {
      a: u32,
      inner: struct { y: u32, x: u32 },
  };
  ```

- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem on the inner struct only (`slice` should be `y: u32, x: u32`)
- **Covers:** Node lineage iterator visiting nested containers independently

### TASK-1.14: Fields with default values

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "fields with default values"`
- **Source:** `const S = struct { b: u32 = 0, a: u32 };`
- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem, `slice` should include `b: u32 = 0, a: u32`
- **Covers:** `container_field_init` tag in the children loop (fields with `= value`)

### TASK-1.15: Declarations mixed between fields

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "declarations between fields"`
- **Source:**

  ```zig
  const S = struct {
      const decl = 1;
      b: u32,
      fn helper() void {}
      a: u32,
  };
  ```

- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem on `b: u32, a: u32` (declarations should be skipped, not treated as fields)
- **Covers:** `seen_field` logic - non-field children before first field are skipped, non-field children after fields end the field chunk

### TASK-1.16: Verify fix text for multi-line struct

- **File:** `src/rules/field_ordering.zig`
- **Test name:** `test "fix text multi-line struct"`
- **Source:**

  ```zig
  const S = struct {
      c: u32,
      a: u32,
      b: u32,
  };
  ```

- **Config:** `Config{ .struct_field_order = .{ .order = .alphabetical_ascending, .severity = .warning } }`
- **Expected:** 1 problem. Verify `.fix.text` equals the reordered source exactly: `"a: u32,\n    b: u32,\n    c: u32,"` (or similar - get exact text from first test run debug output)
- **Covers:** `expected_source` building loop, `is_multiline = true` path, comma insertion between fields

---

## Priority 2: `src/rules/switch_case_ordering.zig` - 6.45% (29/31 lines missed)

Has only `refAllDecls`. On Zig 0.13, only the `.@"0.13"` branch is compiled.

### TASK-2.1: else not last in switch

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "else not last"`
- **Source:**

  ```zig
  const a: enum { x, y } = .x;
  const s = switch (a) {
      .x => {},
      else => {},
      .y => {},
  };
  ```

- **Config:** `Config{}` (else_is_last = .warning by default)
- **Expected:** 1 problem, `slice = "else => {}"`, message = `"\`else\` should be last in switch statements"`
- **Covers:** 0.13 branch: `switch` tag, case iteration, `values.len == 0` detection, `i != case_count - 1` check

### TASK-2.2: else last - no problem

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "else last"`
- **Source:**

  ```zig
  const a: enum { x, y } = .x;
  const s = switch (a) {
      .x => {},
      .y => {},
      else => {},
  };
  ```

- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `i == case_count - 1` - no problem appended

### TASK-2.3: else only case - no problem

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "else only"`
- **Source:**

  ```zig
  const a: u32 = 1;
  const s = switch (a) {
      else => {},
  };
  ```

- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `case_count == 1`, `i == 0 == case_count - 1` - no problem

### TASK-2.4: switch with no else - no problem

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "no else"`
- **Source:**

  ```zig
  const a: u32 = 1;
  const s = switch (a) {
      1 => {},
      2 => {},
  };
  ```

- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `values.len > 0` for all cases - no else found

### TASK-2.5: else_is_last off

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "else_is_last off"`
- **Source:** same as TASK-2.1
- **Config:** `Config{ .else_is_last = .off }`
- **Expected:** 0 problems
- **Covers:** `config.else_is_last != .off` guard

### TASK-2.6: else_is_last error severity

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "else_is_last error"`
- **Source:** same as TASK-2.1
- **Config:** `Config{ .else_is_last = .@"error" }`
- **Expected:** 1 problem with `severity = .@"error"`
- **Covers:** Severity propagation from config to problem

### TASK-2.7: switch_comma (trailing comma)

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "switch_comma"`
- **Source:**

  ```zig
  const a: enum { x, y } = .x;
  const s = switch (a) {
      .x => {},
      else => {},
      .y => {},
  };
  ```

  (Note: in Zig, a trailing comma after the last case creates a `switch_comma` node instead of `switch`)
- **Config:** `Config{}`
- **Expected:** 1 problem
- **Covers:** `switch_comma` tag branch in the 0.13 switch

### TASK-2.8: Multiple switches with problems

- **File:** `src/rules/switch_case_ordering.zig`
- **Test name:** `test "multiple switches"`
- **Source:**

  ```zig
  const a: enum { x, y } = .x;
  const s1 = switch (a) {
      else => {},
      .x => {},
  };
  const s2 = switch (a) {
      .x => {},
      else => {},
      .y => {},
  };
  ```

- **Config:** `Config{}`
- **Expected:** 2 problems (one per switch)
- **Covers:** Node iteration continues past first switch to find second

---

## Priority 3: `src/rules/no_comment_out_code.zig` - 37.21% (54/86 lines missed)

Has unit tests for `looksLikeCode` helper only. The `run` function is untested.

### TASK-3.1: Commented-out var declaration

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run detects commented var"`
- **Source:** `// var a = 1;`
- **Config:** `Config{}` (severity = .warning)
- **Expected:** 1 problem, `slice = "// var a = 1;"`, message = `"Avoid code in comments"`
- **Covers:** `run` basic path - comment iteration, content accumulation, `looksLikeCode` returns true, problem creation

### TASK-3.2: Commented-out function call

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run detects commented call"`
- **Source:** `// std.debug.print("hi", .{});`
- **Config:** `Config{}`
- **Expected:** 1 problem
- **Covers:** `run` statement detection path (content parses as statement inside `fn wrap()`)

### TASK-3.3: Commented-out function declaration (multi-line)

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run detects commented fn decl"`
- **Source:**

  ```zig
  // pub fn foo() u32 {
  //     return 10;
  // }
  ```

- **Config:** `Config{}`
- **Expected:** 1 problem spanning all 3 comment lines
- **Covers:** Multi-line accumulation, `first_comment`/`last_comment` tracking, `looksLikeCode` declaration path

### TASK-3.4: Plain text comment - no problem

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run ignores plain comment"`
- **Source:** `// this is a regular comment`
- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `looksLikeCode` returns false, no problem appended

### TASK-3.5: Comment with backticks - no problem

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run ignores backtick code"`
- **Source:** ``// `var a = 1;``
- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `looksLikeCode` backtick exclusion (`indexOfScalar(u8, content, '\`')`)

### TASK-3.6: Multi-line comment block - one problem

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run multi-line block"`
- **Source:**

  ```zig
  // var a = 1;
  // var b = 2;
  // var c = 3;
  ```

- **Config:** `Config{}`
- **Expected:** 1 problem spanning all 3 lines (start = first comment, end = last comment)
- **Covers:** `prev_line == line - 1` - accumulate into same block, `first_comment`/`last_comment` tracking

### TASK-3.7: Separate comment blocks - two problems

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run separate blocks"`
- **Source:**

  ```zig
  // var a = 1;

  // var b = 2;
  ```

- **Config:** `Config{}`
- **Expected:** 2 problems (blank line separates blocks)
- **Covers:** `prev_line != line - 1` - flush current block, start new one

### TASK-3.8: severity off - no problems

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run off"`
- **Source:** `// var a = 1;`
- **Config:** `Config{ .severity = .off }`
- **Expected:** 0 problems
- **Covers:** `config.severity == .off` - early return null

### TASK-3.9: End-of-file flush

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "run end of file flush"`
- **Source:** `// var a = 1;` (no trailing newline, no other content)
- **Config:** `Config{}`
- **Expected:** 1 problem
- **Covers:** Post-loop flush (`content_accumulator.items.len > 0` after the for loop)

### TASK-3.10: looksLikeCode empty string

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "looksLikeCode empty"`
- **How:** Direct call: `try std.testing.expect(!try looksLikeCode("", std.testing.allocator));`
- **Covers:** `content.len == 0` - return false

### TASK-3.11: looksLikeCode test declaration

- **File:** `src/rules/no_comment_out_code.zig`
- **Test name:** `test "looksLikeCode test decl"`
- **How:** Direct call: `try std.testing.expect(try looksLikeCode("test \"foo\" {}", std.testing.allocator));`
- **Covers:** `test_decl` node tag in the declaration detection switch

---

## Priority 4: `src/rules/no_todo.zig` - 39.13% (42/69 lines missed)

Has unit tests for `looksLikeIssueId` and `looksLikeUrl` helpers only. The `run` and `isExcluded` functions are untested.

### TASK-4.1: TODO without link - warning

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run detects todo"`
- **Source:** `// TODO`
- **Config:** `Config{}`
- **Expected:** 1 problem, `slice = "// TODO"`, message = `"Avoid todo comments that don't link to a tracked issue"`
- **Covers:** `run` basic TODO detection, `comment.kind == .todo`, no exclusion match

### TASK-4.2: TODO with issue number in parens - excluded

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run excludes todo with issue number"`
- **Source:** `// TODO(#10)`
- **Config:** `Config{}` (exclude_if_contains_issue_number = true by default)
- **Expected:** 0 problems
- **Covers:** `todo.inner_content` non-null - `isExcluded` with issue number - `looksLikeIssueId("#10")` - true

### TASK-4.3: TODO with URL in parens - excluded

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run excludes todo with url"`
- **Source:** `// TODO(http://example.com/10)`
- **Config:** `Config{}` (exclude_if_contains_url = true by default)
- **Expected:** 0 problems
- **Covers:** `todo.inner_content` non-null - `isExcluded` with URL - `looksLikeUrl` - true

### TASK-4.4: TODO with issue number in content - excluded

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run excludes todo with issue in content"`
- **Source:** `// TODO: fix in #10`
- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `todo.content` non-null - `isExcluded` on content range - `looksLikeIssueId("#10")` - true

### TASK-4.5: TODO with URL in content - excluded

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run excludes todo with url in content"`
- **Source:** `// TODO: fix in https://example.com/10`
- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `todo.content` non-null - `isExcluded` on content range - `looksLikeUrl` - true

### TASK-4.6: TODO(10) without hash - warning

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run detects todo with bare number"`
- **Source:** `// TODO(10)`
- **Config:** `Config{}`
- **Expected:** 1 problem
- **Covers:** `isExcluded` - `looksLikeIssueId("10")` - false (no `#` prefix), `looksLikeUrl("10")` - false

### TASK-4.7: exclude_if_contains_issue_number = false

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run issue exclusion disabled"`
- **Source:** `// TODO(#10)`
- **Config:** `Config{ .exclude_if_contains_issue_number = false }`
- **Expected:** 1 problem
- **Covers:** `config.exclude_if_contains_issue_number` false - `isExcluded` not called for issue check

### TASK-4.8: exclude_if_contains_url = false

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run url exclusion disabled"`
- **Source:** `// TODO(http://example.com/10)`
- **Config:** `Config{ .exclude_if_contains_url = false }`
- **Expected:** 1 problem
- **Covers:** `config.exclude_if_contains_url` false - `isExcluded` not called for URL check

### TASK-4.9: Both exclusions off - different message

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run message when exclusions off"`
- **Source:** `// TODO`
- **Config:** `Config{ .exclude_if_contains_issue_number = false, .exclude_if_contains_url = false }`
- **Expected:** 1 problem, message = `"Avoid todo comments"` (NOT "Avoid todo comments that don't link to a tracked issue")
- **Covers:** Message branching: `if (config.exclude_if_contains_issue_number or !config.exclude_if_contains_url)` - wait, this condition is `exclude_if_contains_issue_number or !exclude_if_contains_url`. When both are false: `false or !false` = `false or true` = `true`. So message = "Avoid todo comments that don't link to a tracked issue". Need to re-read the code...

  Actually re-reading: `if (config.exclude_if_contains_issue_number or !config.exclude_if_contains_url)` - when `exclude_if_contains_issue_number=false` and `exclude_if_contains_url=true` (default): `false or !true` = `false or false` = `false` - message = "Avoid todo comments". So the test should be: `exclude_if_contains_issue_number = false` (url still true) - message = "Avoid todo comments".

  **Revised Config:** `Config{ .exclude_if_contains_issue_number = false }` (exclude_if_contains_url stays true)
  **Revised Expected:** message = `"Avoid todo comments"`

### TASK-4.10: severity off - no problems

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run off"`
- **Source:** `// TODO`
- **Config:** `Config{ .severity = .off }`
- **Expected:** 0 problems
- **Covers:** `config.severity == .off` - early return null

### TASK-4.11: TODO() empty parens - warning

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run todo empty parens"`
- **Source:** `// TODO()`
- **Config:** `Config{}`
- **Expected:** 1 problem
- **Covers:** `todo.inner_content` is non-null (empty range) - `isExcluded("", config)` - no words - returns false

### TASK-4.12: Non-TODO comment - no problem

- **File:** `src/rules/no_todo.zig`
- **Test name:** `test "run ignores non-todo comment"`
- **Source:** `// regular comment`
- **Config:** `Config{}`
- **Expected:** 0 problems
- **Covers:** `comment.kind != .todo` - `continue :nodes`

---

## Priority 5: `src/lib/BuildInfo.zig` - 65.22% (8/23 lines missed)

Has no test block at all.

### TASK-5.1: deinit with null paths

- **File:** `src/lib/BuildInfo.zig`
- **Test name:** `test "deinit default"`
- **How:**

  ```zig
  test "deinit default" {
      var info = BuildInfo.default;
      info.deinit(std.testing.allocator); // should not crash
  }
  ```

- **Covers:** `self.exclude_paths` is null - skip, `self.include_paths` is null - skip

### TASK-5.2: deinit with allocated paths

- **File:** `src/lib/BuildInfo.zig`
- **Test name:** `test "deinit with paths"`
- **How:**

  ```zig
  test "deinit with paths" {
      const gpa = std.testing.allocator;
      var include_paths = try gpa.alloc([]const u8, 1);
      include_paths[0] = try gpa.dupe(u8, "src");
      var exclude_paths = try gpa.alloc([]const u8, 1);
      exclude_paths[0] = try gpa.dupe(u8, "vendor");
      var info = BuildInfo{
          .include_paths = include_paths,
          .exclude_paths = exclude_paths,
      };
      info.deinit(gpa); // should free without leak (testing.allocator detects leaks)
  }
  ```

- **Covers:** `self.exclude_paths` non-null - free loop + free slice, `self.include_paths` non-null - free loop + free slice

### TASK-5.3: default value

- **File:** `src/lib/BuildInfo.zig`
- **Test name:** `test "default"`
- **How:**

  ```zig
  test "default" {
      try std.testing.expect(BuildInfo.default.include_paths == null);
      try std.testing.expect(BuildInfo.default.exclude_paths == null);
  }
  ```

- **Covers:** `BuildInfo.default` constant

### TASK-5.4: consumeStdinAlloc - EndOfStream returns null

- **File:** `src/lib/BuildInfo.zig`
- **Test name:** `test "consumeStdinAlloc empty stdin"`
- **How:** Create a `std.io.Reader` that immediately returns `error.EndOfStream` on `readInt`. Also needs a `rendering.Printer` - use `rendering.Printer` with a null/no-op writer if possible, or mock it. Check `src/lib/rendering.zig` for how to construct one for tests.
- **Expected:** returns `null`
- **Covers:** `readInt` - `error.EndOfStream` - `return null`

### TASK-5.5: consumeStdinAlloc - invalid ZON returns error

- **File:** `src/lib/BuildInfo.zig`
- **Test name:** `test "consumeStdinAlloc invalid zon"`
- **How:** Create a `std.io.Reader` that returns a valid `usize` length followed by invalid ZON bytes (e.g., `"not zon"`).
- **Expected:** returns `error.InvalidArgs`
- **Covers:** `zon.parseFromSlice` - `error.ParseZon` - print error - `return error.InvalidArgs`

---

## Verification

After completing all tasks:

```bash
zig build unit-test
zig build unit-test -Dcoverage=true
```

Check `coverage.txt` - target coverage improvements:

| File | Before | Target After |
| ------ | -------- | ------------- |
| `rules/field_ordering.zig` | 2.06% | >90% |
| `rules/switch_case_ordering.zig` | 6.45% | >95% |
| `rules/no_comment_out_code.zig` | 37.21% | >85% |
| `rules/no_todo.zig` | 39.13% | >85% |
| `lib/BuildInfo.zig` | 65.22% | >90% |

## Task Checklist

- [x] TASK-1.1: field_ordering - struct ascending with fix
- [x] TASK-1.2: field_ordering - struct descending
- [x] TASK-1.3: field_ordering - enum ordering
- [x] TASK-1.4: field_ordering - union ordering
- [x] TASK-1.5: field_ordering - packed struct excluded by default
- [x] TASK-1.6: field_ordering - packed struct included
- [x] TASK-1.7: field_ordering - extern struct excluded by default
- [x] TASK-1.8: field_ordering - extern struct included
- [x] TASK-1.9: field_ordering - all orders off
- [x] TASK-1.10: field_ordering - already sorted
- [x] TASK-1.11: field_ordering - doc comments preserved in fix
- [x] TASK-1.12: field_ordering - single line container
- [x] TASK-1.13: field_ordering - nested struct
- [x] TASK-1.14: field_ordering - fields with default values
- [x] TASK-1.15: field_ordering - declarations between fields
- [x] TASK-1.16: field_ordering - fix text multi-line struct
- [x] TASK-2.1: switch_case_ordering - else not last
- [x] TASK-2.2: switch_case_ordering - else last
- [x] TASK-2.3: switch_case_ordering - else only
- [x] TASK-2.4: switch_case_ordering - no else
- [x] TASK-2.5: switch_case_ordering - else_is_last off
- [x] TASK-2.6: switch_case_ordering - else_is_last error
- [x] TASK-2.7: switch_case_ordering - switch_comma
- [x] TASK-2.8: switch_case_ordering - multiple switches
- [x] TASK-3.1: no_comment_out_code - run detects commented var
- [ ] TASK-3.2: no_comment_out_code - run detects commented call
- [ ] TASK-3.3: no_comment_out_code - run detects commented fn decl
- [ ] TASK-3.4: no_comment_out_code - run ignores plain comment
- [ ] TASK-3.5: no_comment_out_code - run ignores backtick code
- [ ] TASK-3.6: no_comment_out_code - run multi-line block
- [ ] TASK-3.7: no_comment_out_code - run separate blocks
- [ ] TASK-3.8: no_comment_out_code - run off
- [ ] TASK-3.9: no_comment_out_code - run end of file flush
- [ ] TASK-3.10: no_comment_out_code - looksLikeCode empty
- [ ] TASK-3.11: no_comment_out_code - looksLikeCode test decl
- [ ] TASK-4.1: no_todo - run detects todo
- [ ] TASK-4.2: no_todo - run excludes todo with issue number
- [ ] TASK-4.3: no_todo - run excludes todo with url
- [ ] TASK-4.4: no_todo - run excludes todo with issue in content
- [ ] TASK-4.5: no_todo - run excludes todo with url in content
- [ ] TASK-4.6: no_todo - run detects todo with bare number
- [ ] TASK-4.7: no_todo - run issue exclusion disabled
- [ ] TASK-4.8: no_todo - run url exclusion disabled
- [ ] TASK-4.9: no_todo - run message when exclusions off
- [ ] TASK-4.10: no_todo - run off
- [ ] TASK-4.11: no_todo - run todo empty parens
- [ ] TASK-4.12: no_todo - run ignores non-todo comment
- [ ] TASK-5.1: BuildInfo - deinit default
- [ ] TASK-5.2: BuildInfo - deinit with paths
- [ ] TASK-5.3: BuildInfo - default
- [ ] TASK-5.4: BuildInfo - consumeStdinAlloc empty stdin
- [ ] TASK-5.5: BuildInfo - consumeStdinAlloc invalid zon
