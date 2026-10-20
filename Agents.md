# Zlinter - Linter for Zig

The goal of this project is in `README.md`.

## Version Control

* Git

## Zig Programming Language Version

Zig version `zig version` = "0.13.0"

Zig compiler installation `where zig` = "C:\Program Files\zig-0.13.0\zig.exe"

### Full Zig environment paths (lib_dir, std_dir) (`zig env --path`)

> {
>  "zig_exe": "C:\\PROGRA~1\\zig-0.13.0\\zig.exe",
>  "lib_dir": "C:\\PROGRA~1\\zig-0.13.0\\lib",
>  "std_dir": "C:\\PROGRA~1\\zig-0.13.0\\lib\\std",
>  "global_cache_dir": "C:\\Users\\pkofler\\AppData\\Local\\zig",
>  "version": "0.13.0",
>  "target": "x86_64-windows.win10_fe...win10_fe-gnu",
>  "env": {
>   "HOME": "C:\\Users\\pkofler"
>  }
> }

## Ctags

Use ctags to find Zig code elements.

Ctags, version="6.2.1", file `tags` with line numbers is in the root folder

Query tags with `readtags`, e.g.

```
readtags -t tags -e -n -i - <name>
readtags -t tags -e -n -i -l -Q "(prefix? $name \"<name>\")"
```

using `prefix?`, `eq?`, `substr?`, etc. and query against `$name`, `$kind`, etc.

### Full Zig Std Library ctags

Ctags file `tags` with line numbers in Zig installation.

Query with `readtags -t C:\PROGRA~1\zig-0.13.0\tags ...`
