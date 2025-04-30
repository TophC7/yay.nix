function __yay_rebuild
    set -l opts h/help 'p/path=' 'H/host=' t/trace
    argparse $opts -- $argv; or return
    if set -q _flag_help
        echo "Usage: yay rebuild [OPTIONS]"
        echo "  -p, --path PATH   Path to the Nix configuration (overrides FLAKE)"
        echo "  -H, --host HOST   Hostname to build for (default: current hostname)"
        echo "  -t, --trace     Enable trace output"
        echo "  -h, --help      Show this help message"
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
    if set -q _flag_trace
        __yay_run "nh os switch . -H $host -- --impure --show-trace"
    else
        __yay_run "nh os switch . -H $host -- --impure"
    end
    cd $orig
end