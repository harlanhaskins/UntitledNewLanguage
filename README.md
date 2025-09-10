# Untitled New Language  
[![CI][ci-badge]][ci-workflow]

NewLang is an experimental programming language that compiles to C.
It is a small, statically typed language with a Swift-like surface syntax,
boolean and integer arithmetic, structs with methods, and C interop. It uses
an SSA-based intermediate representation and invokes `clang` to produce executables.

Note: This is a spiritual successor project to Trill — see https://github.com/trill-lang/trill.


## Quick Start

- Prerequisites:
  - Swift toolchain (swift-tools-version 6.2+)
  - macOS with a recent `clang` in PATH
- Build:
  - Debug: `swift build`
  - Release: `swift build -c release`
- Run the compiler:
  - Via SwiftPM: `swift run newlang <file.nl> [options]`
  - From build output: `.build/debug/NewLang <file.nl> [options]` (or `.build/release/NewLang`)

Common options:
- `-o <path>`: Output executable filename
- `-v, --verbose`: Verbose pipeline logging
- `--emit <stage>`: Print an intermediate stage and exit. Stages: `parse`, `typecheck`, `ssa`, `c`
- `--skip-analysis`: Skip SSA analysis passes
- `--analyze-only`: Run analysis passes only (no codegen)
- `-O`: Enable optimizations (runs DCE pass and compiles C with `-O2 -DNDEBUG`)

Examples:
- Compile and run:
  - `swift run newlang hello.nl -o hello && ./hello`
- Inspect C output:
  - `swift run newlang hello.nl --emit c`
- Inspect SSA IR:
  - `swift run newlang hello.nl --emit ssa`
- Parse or type-check only:
  - `swift run newlang hello.nl --emit parse`
  - `swift run newlang hello.nl --emit typecheck`


## “Hello, world”

NewLang interoperates with C for I/O:

```newlang
@extern(c)
func puts(_ s: *Int8) -> Int32

func main() -> Int32 {
    puts("Hello, NewLang!")
    return Int32(0)
}
```

Compile and run:

```
swift run newlang hello.nl -o hello
./hello
```


## Language Overview

Types:
- Integers: `Int` (64-bit), `Int32`, `Int8`
- Booleans: `Bool`
- Pointers: `*T` (primarily for C interop; string literals are C strings)
- `Void`

Functions:
- Declaration with return types and parameters:
  - `func add(_ x: Int, _ y: Int) -> Int { return x + y }`
- Argument labels and checking:
  - Labels supported and validated for both free functions and methods
  - Errors for unexpected, incorrect, or out-of-order labels
- Recursion supported
- Casting via type construction: `Int32(x)`

Variables:
- `var` declarations with optional type annotation and assignment:
  - `var x: Int = 0`, `var y = x + 1`
- Assignment and mutation supported

Control Flow:
- `if` / `else if` / `else`
- Multiple early `return`s in a function

Operators and Precedence:
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Boolean: `&&`, `||`, `!` with short-circuit semantics
- Unary: `-` (integers), `!` (booleans)
- Standard precedence:
  - `*`/`/` bind tighter than `+`/`-`
  - Arithmetic binds tighter than comparisons
  - Comparisons bind tighter than boolean ops
  - `&&` binds tighter than `||`
  - Parentheses override precedence

Structs and Methods:
- Structs with fields and methods:
  - ```newlang
    struct Counter {
        var value: Int
        func inc(_ d: Int) { value = value + d }
        func get() -> Int { return value }
    }
    ```
- Member access and mutation: `c.value = 0`; method calls: `c.inc(5)`

C Interop:
- `@extern(c)` for declaring C functions (including varargs):
  - `@extern(c) func printf(_ format: *Int8, ...)`
- Call from NewLang using standard C formats; string literals are `*Int8`

Comments:
- Single-line `// ...`


## Diagnostics and Analysis

- Type checking errors include unknown types/variables, invalid operations, non-boolean conditions, member lookups, and argument label validation.
- SSA analysis pass detects unused variables and reports:
  - Uninitialized variables
  - Write-only variables (stores without loads)
  - A summary per function
- Dead code elimination (DCE) runs to clean up IR
- Example non-verbose compile output includes:
  - `=== NEWLANG COMPILER ===`
  - `Warning: unused variable ...`
  - `Note: Function 'main': ...`
  - `Compiling to executable...`
  - `✅ Compilation successful! Output: <path>`


## Inspecting Intermediate Representations

- Parse tree: `--emit parse` prints the AST without types
- Typed AST: `--emit typecheck` prints AST annotated with types
- SSA IR: `--emit ssa` prints per-function SSA
- C: `--emit c` prints generated C (with headers, externs, typedefs, and definitions)


## Running the Test Suite

A lightweight test runner is included:

- Build and run: `swift run lite`
- The runner discovers `.nl` files in `Tests/lite`, substitutes the local compiler binary, and executes RUN lines (optionally with FileCheck if present)


## Status

This is an active, early-stage, untitled language prototype. Expect rough edges: no loops
yet, limited standard library, and interop-oriented strings. Feedback and experiments are
welcome.

[ci-badge]: https://github.com/harlanhaskins/UntitledNewLanguage/actions/workflows/lite.yml/badge.svg
[ci-workflow]: https://github.com/harlanhaskins/UntitledNewLanguage/actions/workflows/lite.yml
