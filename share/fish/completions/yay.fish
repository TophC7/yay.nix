######################
# UTILITY FUNCTIONS  #
######################

# Fallback functions for older fish versions
function __fish_seen_subcommand_from_fallback
    set -l cmd (commandline -poc)
    set -e cmd[1] # Remove the main command
    contains -- $argv[1] $cmd
    and return 0
    return 1
end

function __fish_seen_option_fallback
    set -l cmd (commandline -poc)
    for opt in $argv
        if contains -- $opt $cmd
            return 0
        end
    end
    return 1
end

function __fish_is_token_n_fallback
    set -l cmd (commandline -poc)
    test (count $cmd) -eq $argv[1]
    and return 0
    return 1
end

# Use built-in functions if they exist, otherwise use our fallbacks
function __yay_seen_subcommand_from
    if type -q __fish_seen_subcommand_from
        __fish_seen_subcommand_from $argv
    else
        __fish_seen_subcommand_from_fallback $argv
    end
end

function __yay_seen_option
    if type -q __fish_seen_option
        __fish_seen_option $argv
    else
        __fish_seen_option_fallback $argv
    end
end

function __yay_is_token_n
    if type -q __fish_is_token_n
        __fish_is_token_n $argv
    else
        __fish_is_token_n_fallback $argv
    end
end

######################
# HELPER FUNCTIONS   #
######################

# Flake input handling
function __yay_list_flake_inputs
    set -l flake_path (__yay_get_flake_path $argv[1]); or return
    
    if not test -f "$flake_path/flake.lock"
        return 1
    end
    
    # Extract input names from the flake.lock file using jq
    jq -r '.nodes.root.inputs | keys[]' "$flake_path/flake.lock" 2>/dev/null
end

function __yay_get_flake_inputs
    set -l cmd (commandline -poc)
    set -l path ""
    
    # Check for --path or -p option
    for i in (seq 1 (count $cmd))
        if test "$cmd[$i]" = "--path" -o "$cmd[$i]" = "-p"; and test (count $cmd) -ge (math $i + 1)
            set path $cmd[(math $i + 1)]
            break
        end
    end
    
    __yay_list_flake_inputs $path
end

# Package listing with caching
function __yay_list_packages
    # Use persistent cache file in /tmp (lasts until reboot)
    set -l cache_file /tmp/yay_packages_cache

    # Load from cache if it exists
    if test -f "$cache_file"
        cat "$cache_file"
        return 0
    end

    # Otherwise, fetch packages and store in cache
    echo -n "Loading packages..." >&2
    # Run nix-env but redirect warnings to /dev/null
    set -l packages (nix-env -qa --json 2>/dev/null | jq -r 'keys[]' 2>/dev/null)

    # Process packages to remove namespace prefix (like "nixos.", "nixpkgs.", etc.)
    set -l cleaned_packages
    for pkg in $packages
        set -l cleaned_pkg (string replace -r '^[^.]+\.' ''\'''\' $pkg)
        set -a cleaned_packages $cleaned_pkg
    end

    # Save to cache file for future shell sessions
    printf "%s\n" $cleaned_packages >"$cache_file"
    echo " done!" >&2

    # Output the packages
    printf "%s\n" $cleaned_packages
end

######################
# MAIN COMMAND       #
######################

# Complete the main command
complete -c yay -f

# Complete the top-level subcommands
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a rebuild -d "Rebuild the NixOS configuration"
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a update -d "Update flake inputs"
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a garbage -d "Clean up the Nix store"
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a try -d "Create a shell with the specified package(s)"
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a tar -d "Create compressed tar archives"
complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar" -a untar -d "Extract tar archives"

######################
# REBUILD SUBCOMMAND #
######################

# Options for 'rebuild'
complete -c yay -n "__yay_seen_subcommand_from rebuild" -s p -l path -r -d "Path to the Nix configuration"
complete -c yay -n "__yay_seen_subcommand_from rebuild" -s H -l host -r -d "Hostname to build for"
complete -c yay -n "__yay_seen_subcommand_from rebuild" -s t -l trace -d "Enable trace output"
complete -c yay -n "__yay_seen_subcommand_from rebuild" -s h -l help -d "Show help message"

######################
# UPDATE SUBCOMMAND  #
######################

# Options for 'update'
complete -c yay -n "__yay_seen_subcommand_from update" -s p -l path -r -d "Path to the Nix configuration"
complete -c yay -n "__yay_seen_subcommand_from update" -s i -l input -r -a "(__yay_get_flake_inputs)" -d "Specific input to update"
complete -c yay -n "__yay_seen_subcommand_from update" -s h -l help -d "Show help message"

# Positional argument for update (input name)
complete -c yay -n "__yay_seen_subcommand_from update; and not __yay_seen_option -i --input -h --help; and test (count (commandline -poc)) -eq 2" -a "(__yay_get_flake_inputs)" -d "Input to update"

######################
# GARBAGE SUBCOMMAND #
######################

# Options for 'garbage'
complete -c yay -n "__yay_seen_subcommand_from garbage" -s h -l help -d "Show help message"

######################
# TRY SUBCOMMAND     #
######################

# Options for 'try'
complete -c yay -n "__yay_seen_subcommand_from try" -s h -l help -d "Show help message"

# Package completion for try (before --)
function __yay_try_no_dash_dash_yet
    __yay_seen_subcommand_from try
    and not contains -- -- (commandline -poc)
    and not string match -r -- '^-' (commandline -ct)
end
complete -c yay -n "__yay_try_no_dash_dash_yet" -a "(__yay_list_packages)" -d "Nix package"

# Double dash separator completion for try
function __yay_try_can_add_dash_dash
    __yay_seen_subcommand_from try
    and not contains -- -- (commandline -poc)
    and test (count (commandline -poc)) -gt 2
end
complete -c yay -n "__yay_try_can_add_dash_dash" -a "--" -d "Separator for command to run"

# Command completion after --
function __yay_try_after_dash_dash
    set -l tokens (commandline -poc)
    contains -- -- $tokens
    and __yay_seen_subcommand_from try
end
complete -c yay -n "__yay_try_after_dash_dash" -a "(__fish_complete_command)" -d "Command to run"

######################
# TAR SUBCOMMAND     #
######################

# Options for 'tar'
complete -c yay -n "__yay_seen_subcommand_from tar" -s o -l output -r -d "Output file path"
complete -c yay -n "__yay_seen_subcommand_from tar" -s c -l compression -r -a "zstd gzip bzip2 bzip3 7zip tar" -d "Compression type"
complete -c yay -n "__yay_seen_subcommand_from tar" -s l -l level -r -d "Compression level"
complete -c yay -n "__yay_seen_subcommand_from tar" -s t -l threads -r -d "Thread count"
complete -c yay -n "__yay_seen_subcommand_from tar" -s v -l verbose -d "Enable verbose output"
complete -c yay -n "__yay_seen_subcommand_from tar" -s h -l help -d "Show help message"

# File path completion for tar input
function __yay_tar_needs_input
    __yay_seen_subcommand_from tar
    and count (commandline -poc) = 2
    and not __yay_seen_option -o --output -c --compression -l --level -t --threads -v --verbose -h --help
end
complete -c yay -n __yay_tar_needs_input -r -d "Input path"

# File path completion for tar output
function __yay_tar_needs_output
    __yay_seen_subcommand_from tar
    and count (commandline -poc) = 3
    and not __yay_seen_option -o --output
end
complete -c yay -n __yay_tar_needs_output -r -d "Output file"

######################
# UNTAR SUBCOMMAND   #
######################

# Options for 'untar'
complete -c yay -n "__yay_seen_subcommand_from untar" -s o -l output -r -d "Output directory"
complete -c yay -n "__yay_seen_subcommand_from untar" -s v -l verbose -d "Enable verbose output"
complete -c yay -n "__yay_seen_subcommand_from untar" -s h -l help -d "Show help message"

# File path completion for untar input with archive extensions
function __yay_untar_needs_input
    __yay_seen_subcommand_from untar
    and count (commandline -poc) = 2
    and not __yay_seen_option -o --output -v --verbose -h --help
end
complete -c yay -n __yay_untar_needs_input -r -a "*.tar *.tar.gz *.tgz *.tar.zst *.tzst *.tar.bz2 *.tbz *.tbz2 *.tb2 *.tz2 *.tar.bz3 *.7z *.tar.7z *.rar" -d "Archive file"

# Directory completion for untar output directory
function __yay_untar_needs_output
    __yay_seen_subcommand_from untar
    and count (commandline -poc) = 3
    and not __yay_seen_option -o --output
end
complete -c yay -n __yay_untar_needs_output -r -a "(__fish_complete_directories)" -d "Output directory"
