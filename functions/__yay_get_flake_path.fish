function __yay_get_flake_path
    set path_arg $argv[1]
    if test -n "$path_arg"
        __yay_yellow "Using flake path from argument: $path_arg" >&2
        set flake_path $path_arg
    else if set -q FLAKE
        __yay_yellow "Using flake path from FLAKE env var: $FLAKE" >&2
        set flake_path $FLAKE
    else
        set flake_path (pwd)
        __yay_yellow "Using current directory as flake path: $flake_path" >&2
    end
    if not test -f "$flake_path/flake.nix"
        __yay_red "No flake.nix found in $flake_path" >&2
        return 1
    end
    echo $flake_path
end
