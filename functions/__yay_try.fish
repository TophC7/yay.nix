function __yay_try
    set -l all_args $argv

    set -l opts h/help
    argparse $opts -- $all_args; or return

    if set -q _flag_help; or test (count $all_args) -eq 0
        echo "Usage: yay try PACKAGE [PACKAGE...] [-- COMMAND [ARGS...]]"
        echo "  -h, --help  Show this help message"
        return
    end

    # Initialize variables in function scope
    set -l pkgs
    set -l cmd_str
    set -l sep_index (contains --index -- '--' $all_args)

    if test $status -eq 0  # Found '--' separator
        # Extract packages before '--'
        if test $sep_index -gt 1
            set pkgs $all_args[1..(math $sep_index - 1)]
        end

        # Extract and escape command after '--'
        if test $sep_index -lt (count $all_args)
            set -l raw_cmd $all_args[(math $sep_index + 1)..-1]
            set -l escaped_cmd
            for arg in $raw_cmd
                set escaped_cmd $escaped_cmd (string escape -- "$arg")
            end
            set cmd_str (string join ' ' -- $escaped_cmd)
        else
            echo "Error: no command specified after --" >&2
            return 1
        end
    else  # No '--' found
        set pkgs $all_args
    end

    if test (count $pkgs) -eq 0
        echo "Error: no packages specified" >&2
        return 1
    end

    __yay_green "««« CREATING NIX SHELL »»»"
    __yay_yellow "Loading packages: $pkgs"

    set -l pkg_str (string join ' ' -- $pkgs)
    if test -n "$cmd_str"
        __yay_yellow "Running: $cmd_str"
        __yay_run "nix-shell -p $pkg_str --run \"$cmd_str\""
    else
        __yay_run "nix-shell -p $pkg_str --command fish"
    end
end