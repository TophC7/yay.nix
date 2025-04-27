function __yay_update
    set -l opts h/help 'p/path='
    argparse $opts -- $argv; or return
    if set -q _flag_help
        echo "Usage: yay update [OPTIONS]"
        echo "  -p, --path PATH   Path to the Nix configuration (overrides FLAKE)"
        echo "  -h, --help    Show this help message"
        return
    end
    set flake_path (__yay_get_flake_path $_flag_path); or return
    __yay_green "««« UPDATING FLAKE INPUTS »»»"
    set orig (pwd)
    cd $flake_path
    __yay_run "nix flake update"
    cd $orig
end
