function __yay_rebuild
    set -l opts h/help 'p/path=' 'H/host=' t/trace e/experimental
    argparse $opts -- $argv; or return
    if set -q _flag_help
        echo "Usage: yay rebuild [OPTIONS]"
        echo "  -h, --help          Show this help message"
        echo "  -e, --experimental  Enable experimental features (flakes and nix-commands)"
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

    # Base command
    set -l cmd "nh os switch . -H $host -- --impure"

    # Add trace if requested
    if set -q _flag_trace
        set cmd "$cmd --show-trace"
    end

    # Add experimental features if requested
    if set -q _flag_experimental
        set cmd "$cmd --extra-experimental-features flakes --extra-experimental-features nix-commands"
    end

    # Run the command
    __yay_run $cmd

    cd $orig
end
