function __yay_rebuild
    set -l opts h/help 'p/path=' 'H/host=' t/trace e/experimental
    argparse $opts -- $argv; or return
    if set -q _flag_help
        echo "Usage: yay rebuild [OPTIONS]"
        echo "  -h, --help          Show this help message"
        echo "  -e, --experimental  Enable experimental features (flakes and nix-command)"
        echo "  -H, --host HOST     Hostname to build for (default: current hostname)"
        echo "  -p, --path PATH     Path to the Nix configuration (overrides FLAKE)"
        echo "  -t, --trace         Enable trace output"
        return
    end
    set flake_path (__yay_get_flake_path $_flag_path); or return

    set host (hostname) # Default value
    if test -n "$_flag_host"
        set host $_flag_host # Override if flag is provided
    end

    __yay_green "««« REBUILDING NIXOS ($host) »»»"
    set orig (pwd)
    cd $flake_path

    # Build the nh command
    set -l nh_cmd "nh os switch . -H $host -- --impure"
    
    # Add trace if requested
    if set -q _flag_trace
        set nh_cmd "$nh_cmd --show-trace"
    end

    # Choose execution method based on experimental flag
    if set -q _flag_experimental
        # Run nh inside a shell with experimental features
        set -l shell_cmd "nix shell nixpkgs#nh --extra-experimental-features \"nix-command flakes\" -c fish -c \"$nh_cmd\""
        __yay_run $shell_cmd
    else
        # Run nh directly
        __yay_run $nh_cmd
    end

    cd $orig
end