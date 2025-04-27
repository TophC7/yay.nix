function __yay_try
    set -l opts h/help
    argparse $opts -- $argv; or return
    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: yay try PACKAGE [PACKAGE...]"
        echo "  -h, --help  Show this help message"
        return
    end
    __yay_green "««« CREATING NIX SHELL »»»"
    __yay_yellow "Loading packages: $argv"
    __yay_run "nix-shell -p $argv --command fish"
end