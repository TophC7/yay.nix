function __yay_try
    set -l all_args $argv
    
    # Find -- separator before argparse to avoid argparse consuming it
    set -l sep_index (contains --index -- '--' $all_args)
    set -l args_before_sep $all_args
    set -l cmd_after_sep
    
    if test $status -eq 0  # Found '--' separator
        if test $sep_index -gt 1
            set args_before_sep $all_args[1..(math $sep_index - 1)]
        else
            set args_before_sep # empty if -- is first
        end
        
        if test $sep_index -lt (count $all_args)
            set cmd_after_sep $all_args[(math $sep_index + 1)..-1]
        end
    end

    # Now parse only the arguments before --
    set -l opts h/help e/experimental
    argparse $opts -- $args_before_sep; or return

    if set -q _flag_help; or test (count $args_before_sep) -eq 0 -a (count $cmd_after_sep) -eq 0
        echo "Usage: yay try [OPTIONS] PACKAGE [PACKAGE...] [-- COMMAND [ARGS...]]"
        echo "  -e, --experimental  Enable experimental features (nix-command flakes)"
        echo "  -h, --help         Show this help message"
        return
    end

    # $argv now contains only the packages (after argparse removed flags)
    set -l pkgs $argv
    
    # Build command string from cmd_after_sep
    set -l cmd_str
    if test (count $cmd_after_sep) -gt 0
        set -l escaped_cmd
        for arg in $cmd_after_sep
            set escaped_cmd $escaped_cmd (string escape -- "$arg")
        end
        set cmd_str (string join ' ' -- $escaped_cmd)
    end

    if test (count $pkgs) -eq 0
        echo "Error: no packages specified" >&2
        return 1
    end

    __yay_green "««« CREATING NIX SHELL »»»"
    __yay_yellow "Loading packages: $pkgs"

    # Build the base command
    set -l base_cmd "nix shell"
    
    if set -q _flag_experimental
        set base_cmd "$base_cmd --extra-experimental-features \"nix-command flakes\""
    end

    # Convert package names to nixpkgs# format
    set -l nix_pkgs
    for pkg in $pkgs
        set nix_pkgs $nix_pkgs "nixpkgs#$pkg"
    end
    set -l pkg_str (string join ' ' -- $nix_pkgs)

    if test -n "$cmd_str"
        __yay_yellow "Running: $cmd_str"
        __yay_run "$base_cmd $pkg_str -c fish -c \"$cmd_str\""
    else
        __yay_run "$base_cmd $pkg_str -c fish"
    end
end