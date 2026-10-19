---
name: zig-review
description: >
  Use this skill when reviewing Zig code for correctness, style, performance, or best practices. Analyzes code structure, identifies potential bugs, suggests improvements, and verifies adherence to Zig idioms and conventions
---

# Zig Code Review Skill

Strict code review for the given file or set of files.

## Prepare for work in this repo

- First run script `./context.bat`
- ALWAYS invoke skill /zig-coding

## Review Checklist

### Correctness

- Check for memory safety issues (use-after-free, double-free, memory leaks)
- Verify proper error handling with `error` unions
- Ensure all allocator usage is correct and matched
- Check for integer overflows and underflows
- Verify proper handling of null pointers and optional types
- Ensure thread safety in concurrent code

### Style & Idioms

- Verify consistent naming conventions (snake_case for variables/functions, PascalCase for types)
- Check for proper use of `const`, `comptime`, and `test` blocks
- Ensure proper formatting (4-space indentation, no trailing whitespace)
- Verify meaningful variable and function names
- Check for appropriate use of `defer` and `errdefer`
- Ensure proper documentation comments (`///` for public API)

### Performance

- Identify unnecessary allocations and copies
- Check for inefficient algorithms or data structures
- Verify proper use of stack vs heap allocation
- Identify hot loops that could be optimized
- Check for unnecessary type conversions
- Verify proper use of `std.mem` functions vs manual loops

### Error Handling

- Ensure all errors are properly propagated or handled
- Check that `catch` blocks handle specific errors appropriately
- Verify error messages are clear and actionable
- Ensure no errors are silently ignored
- Check for proper cleanup in error paths

### Common Zig Pitfalls

- Forgetting to use allocators consistently
- Not handling `error` unions properly
- Misusing `undefined` vs proper initialization
- Incorrect use of `extern` functions
- Memory leaks from unmatched `alloc`/`free`
- Race conditions in async code
- Not using `defer` for cleanup
- Overusing heap allocation when stack would suffice

## Review Process

1. **Read the code first** - Understand the structure and intent before commenting
2. **Check for critical issues** - Memory safety, correctness bugs
3. **Review style and idioms** - Ensure code follows Zig conventions
4. **Analyze performance** - Look for obvious inefficiencies
5. **Verify testing** - Ensure adequate test coverage

## Output Format

- Markdown document `docs/<review target>_Smells.md` 
- Format as task lisk with markers `[ ]` in front.

When providing review feedback:

- Be specific and reference exact lines
- Explain the issue and why it matters
- Suggest concrete improvements
- Prioritize issues (critical, major, minor, style)
- Group related comments together
