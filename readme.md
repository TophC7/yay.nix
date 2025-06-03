# Yay.nix

Yay.nix (Yet another Yay) is a simple wrapper around useful commands I use all the time and can't be bothered to keep typing. I also just miss writing yay in terminal.

## Overview

Yay.nix provides simple, user-friendly commands for common Nix operations like rebuilding your flake config, updating flakes, garbage collection, and more. It includes fish shell completions for all commands and options, making it faster and easier to work with Nix.

## Installation

### As a Flake

Add to your flake.nix:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    yay-nix = {
      url = "github:Tophc7/yay.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, yay-nix, ... }: {
    # For NixOS system configuration
    nixosConfigurations.<yourhostname> = nixpkgs.lib.nixosSystem {
      # ...
      modules = [
        yay-nix.nixosModules.default
        # ...
      ];
    };
  };
}
```

### With Home Manager

```nix
{
  imports = [
    inputs.yay-nix.homeManagerModules.default
  ];
}
```

### Try in shell

```bash
# Create shell with yay
nix shell github:Tophc7/yay.nix --extra-experimental-features flakes --extra-experimental-features nix-command --no-write-lock-file

# Run any yay command
yay try fastfetch -- fastfetch --config examples/24
yay garbage
```

## Commands

### rebuild

Rebuild your NixOS configuration.
It will look for a flake in this pattern: `-p <PATH> > $FLAKE > ./`

```bash
yay rebuild [OPTIONS]
```

Options:
- `-p, --path PATH`: Path to the Nix configuration (overrides FLAKE env var)
- `-H, --host HOST`: Hostname to build for (default: current hostname)
- `-t, --trace`: Enable trace output
- `-e, --experimental`: Enable experimental features (flakes and nix-command)
- `-h, --help`: Show help message

### update

Update flake inputs. You can update all inputs or specify a single input to update.

```bash
yay update [OPTIONS] [INPUT]
```

Options:
- `-p, --path PATH`: Path to the Nix configuration (overrides FLAKE)
- `-i, --input INPUT`: Name of the specific input to update (alternative to positional argument)
- `-h, --help`: Show help message

Examples:
```bash
# Update all inputs
yay update

# Update only the 'nixpkgs' input
yay update nixpkgs

# Update 'nixpkgs' using the flag
yay update -i nixpkgs
```

### garbage

Clean up the Nix store and home-manager backups.
Super overkill don't come for me if something goes wrong. Regardless I use it all the time.

```bash
yay garbage
```

This command:
1. Cleans using `nh clean all` (with and without sudo)
2. Runs `nix-collect-garbage --delete-old` (with and without sudo)
3. Executes `nix-store --gc` (with and without sudo)
4. Removes home-manager backup files

### try

Create a temporary shell with specified packages. You can either drop into an interactive shell or run a command directly within the environment using `--`.

```bash
yay try PACKAGE [PACKAGE...] [-- COMMAND [ARGS...]]
```

Examples:
```bash
# Enter an interactive shell with fastfetch and cowsay available
yay try fastfetch cowsay

# Run 'fastfetch' directly using the packages in the temporary shell
yay try fastfetch -- fastfetch

# Run 'cowsay moo' directly using the cowsay package
yay try cowsay -- cowsay moo
```

### tar

Create compressed archives with various compression methods.

```bash
yay tar [OPTIONS] INPUT_PATH [OUTPUT_PATH]
```

Options:
- `-c, --compression TYPE`: Compression type (default: zstd)
- `-l, --level N`: Compression level where applicable
- `-o, --output PATH`: Output file path
- `-t, --threads N`: Number of threads to use where supported
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

Supported compression types:
- `7zip`:   .7z (levels: 0-9, default 5, threads: yes)
- `bzip2`:  .tar.bz2 (levels: 1-9, default 9)
- `bzip3`:  .tar.bz3 (block size in MiB: 1-511, default 16, threads: yes)
- `gzip`:   .tar.gz (levels: 1-9, default 6)
- `tar`:    .tar (no compression)
- `zstd`:   .tar.zst (levels: 1-19, default 3, threads: yes)

### untar

Extract various archive formats.

```bash
yay untar [OPTIONS] ARCHIVE [OUTPUT_DIR]
```

Options:
- `-o, --output DIR`: Output directory
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

Supported archive formats (auto-detected from extension):
- `.7z`, `.tar.7z` (7-Zip)
- `.tar.bz2`, `.tb2`, `.tbz`, `.tbz2`, `.tz2` (bzip2)
- `.tar.bz3` (bzip3)
- `.tar.gz`, `.tgz` (gzip)
- `.rar` (RAR)
- `.tar` (uncompressed tar)
- `.tar.zst`, `.tzst` (zstd)

### serve

Start a file server to serve files from a directory.

```bash
yay serve [OPTIONS]
```

Options:
- `-p, --port PORT`: Port to serve on (default: 8080)
- `-d, --directory DIR`: Directory to serve (default: current directory)
- `-h, --help`: Show help message

Examples:
```bash
# Serve current directory on port 8080
yay serve

# Serve a specific directory on custom port
yay serve -d /path/to/files -p 3000
```

### more?

If there's a command you think would be useful to add let me know, I might agree.

## Technical Details

Yay.nix is implemented as a collection of fish functions that are installed into your system's fish function path. The main `yay` command is a bash script that:

1. Creates a temporary fish script
2. Sets up the fish function path to include the installed functions
3. Sources the main yay.fish file
4. Passes all command-line arguments to the appropriate fish function
5. Cleans up after execution

All commands and options have completions making the tool easy to use interactively.

## License

MIT