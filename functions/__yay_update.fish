function __yay_update
    set -l opts h/help 'p/path=' 'i/input='
    argparse $opts -- $argv; or return
    if set -q _flag_help
        echo "Usage: yay update [OPTIONS] [INPUT]"
        echo "  -p, --path PATH   Path to the Nix configuration (overrides FLAKE)"
        echo "  -i, --input INPUT Name of the specific input to update"
        echo "  -h, --help        Show this help message"
        return
    end
    
    set flake_path (__yay_get_flake_path $_flag_path); or return
    
    # Check if a specific input was provided either as flag or positional arg
    set -l input_name ""
    if test -n "$_flag_input"
        set input_name $_flag_input
    else if test (count $argv) -gt 0
        set input_name $argv[1]
    end
    
    if test -n "$input_name"
        __yay_green "««« UPDATING FLAKE INPUT: $input_name »»»"
        set orig (pwd)
        cd $flake_path
        __yay_run "nix flake lock --update-input $input_name"
        cd $orig
    else
        __yay_green "««« UPDATING FLAKE INPUTS »»»"
        set orig (pwd)
        cd $flake_path
        __yay_run "nix flake update"
        cd $orig
    end
end