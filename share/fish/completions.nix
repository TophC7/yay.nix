{
  pkgs,
  lib,
  ...
}:
  pkgs.writeScript "yay.fish" ''
  function __ensure_yay_functions
    # Only try to load if the function doesn't already exist
    if not type -q __yay_get_flake_path
      # Try to find and source the function files
      set -l possible_paths \
        (dirname (status -f))/../functions \
        (dirname (dirname (status -f)))/functions \
        /run/current-system/sw/share/yay.nix/functions \
        $__fish_config_dir/functions

      for dir in $possible_paths
        if test -f "$dir/__yay_get_flake_path.fish"
          source "$dir/__yay_get_flake_path.fish"
          # Also load color functions if needed
          test -f "$dir/__yay_yellow.fish" && source "$dir/__yay_yellow.fish"
          test -f "$dir/__yay_red.fish" && source "$dir/__yay_red.fish"
          break
        end
      end
    end
  end

  __ensure_yay_functions

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
    ${lib.getExe pkgs.jq} -r '.nodes.root.inputs | keys[]' "$flake_path/flake.lock" 2>/dev/null
  end

  function __yay_get_flake_inputs
    # Ensure required functions are available
    __ensure_yay_functions

    # Skip if the required function isn't available
    if not type -q __yay_get_flake_path
      return 1
    end

    set -l cmd (commandline -poc)
    set -l path ""

    # Check for --path or -p option
    for i in (seq 1 (count $cmd))
      if test "$cmd[$i]" = --path -o "$cmd[$i]" = -p; and test (count $cmd) -ge (math $i + 1)
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
    set -l packages (nix-env -qa --json 2>/dev/null | ${lib.getExe pkgs.jq} -r 'keys[]' 2>/dev/null)

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

  # Helper functions for try completion
  function __yay_try_no_dash_dash_yet
    __yay_seen_subcommand_from try
    and not contains -- -- (commandline -poc)
    and not string match -r -- '^-' (commandline -ct)
  end

  function __yay_try_can_add_dash_dash
    __yay_seen_subcommand_from try
    and not contains -- -- (commandline -poc)
    and test (count (commandline -poc)) -gt 2
  end

  function __yay_try_after_dash_dash
    set -l tokens (commandline -poc)
    contains -- -- $tokens
    and __yay_seen_subcommand_from try
  end

  # Helper functions for tar completion
  function __yay_tar_needs_input
    __yay_seen_subcommand_from tar
    and count (commandline -poc) = 2
    and not __yay_seen_option -o --output -c --compression -l --level -t --threads -v --verbose -h --help
  end

  function __yay_tar_needs_output
    __yay_seen_subcommand_from tar
    and count (commandline -poc) = 3
    and not __yay_seen_option -o --output
  end

  # Helper functions for untar completion
  function __yay_untar_needs_input
    __yay_seen_subcommand_from untar
    and count (commandline -poc) = 2
    and not __yay_seen_option -o --output -v --verbose -h --help
  end

  function __yay_untar_needs_output
    __yay_seen_subcommand_from untar
    and count (commandline -poc) = 3
    and not __yay_seen_option -o --output
  end

  ######################
  # MAIN COMMAND     #
  ######################

  # Complete the main command
  complete -c yay -f

  # Complete the top-level subcommands
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a build -d "Build packages into the Nix store"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a find -d "Find packages and files in the Nix store"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a garbage -d "Clean up the Nix store"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a inspect -d "Introspect a flake's packages and options"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a rebuild -d "Rebuild the NixOS configuration"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a serve -d "Start a file server"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a tar -d "Create compressed tar archives"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a try -d "Create a shell with the specified package(s)"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a untar -d "Extract tar archives"
  complete -c yay -n "not __yay_seen_subcommand_from rebuild update garbage try tar untar serve inspect find build" -a update -d "Update flake inputs"

  ######################
  # REBUILD SUBCOMMAND #
  ######################

  # Options for 'rebuild'
  complete -c yay -n "__yay_seen_subcommand_from rebuild" -s p -l path -r -d "Path to the Nix configuration"
  complete -c yay -n "__yay_seen_subcommand_from rebuild" -s H -l host -r -d "Hostname to build for"
  complete -c yay -n "__yay_seen_subcommand_from rebuild" -s t -l trace -d "Enable trace output"
  complete -c yay -n "__yay_seen_subcommand_from rebuild" -s e -l experimental -d "Enable experimental features (nix-command flakes)"
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
  # SERVE SUBCOMMAND   #
  ######################

  # Options for 'serve'
  complete -c yay -n "__yay_seen_subcommand_from serve" -s p -l port -r -d "Port to serve on (default: 8080)"
  complete -c yay -n "__yay_seen_subcommand_from serve" -s d -l directory -r -a "(__fish_complete_directories)" -d "Directory to serve (default: current directory)"
  complete -c yay -n "__yay_seen_subcommand_from serve" -s h -l help -d "Show help message"

  ######################
  # TRY SUBCOMMAND   #
  ######################

  # Options for 'try'
  complete -c yay -n "__yay_seen_subcommand_from try" -s e -l experimental -d "Enable experimental features (nix-command flakes)"
  complete -c yay -n "__yay_seen_subcommand_from try" -s u -l unfree -d "Allow unfree packages"
  complete -c yay -n "__yay_seen_subcommand_from try" -s h -l help -d "Show help message"

  # Package completion for try (before --)
  complete -c yay -n __yay_try_no_dash_dash_yet -a "(__yay_list_packages)" -d "Nix package"

  # Double dash separator completion for try
  complete -c yay -n __yay_try_can_add_dash_dash -a -- -d "Separator for command to run"

  # Command completion after --
  complete -c yay -n __yay_try_after_dash_dash -a "(__fish_complete_command)" -d "Command to run"

  ######################
  # TAR SUBCOMMAND   #
  ######################

  # Options for 'tar'
  complete -c yay -n "__yay_seen_subcommand_from tar" -s o -l output -r -d "Output file path"
  complete -c yay -n "__yay_seen_subcommand_from tar" -s c -l compression -r -a "zstd gzip bzip2 bzip3 7zip tar" -d "Compression type"
  complete -c yay -n "__yay_seen_subcommand_from tar" -s l -l level -r -d "Compression level"
  complete -c yay -n "__yay_seen_subcommand_from tar" -s t -l threads -r -d "Thread count"
  complete -c yay -n "__yay_seen_subcommand_from tar" -s v -l verbose -d "Enable verbose output"
  complete -c yay -n "__yay_seen_subcommand_from tar" -s h -l help -d "Show help message"

  # File path completion for tar input
  complete -c yay -n __yay_tar_needs_input -r -d "Input path"

  # File path completion for tar output
  complete -c yay -n __yay_tar_needs_output -r -d "Output file"

  ######################
  # UNTAR SUBCOMMAND   #
  ######################

  # Options for 'untar'
  complete -c yay -n "__yay_seen_subcommand_from untar" -s o -l output -r -d "Output directory"
  complete -c yay -n "__yay_seen_subcommand_from untar" -s v -l verbose -d "Enable verbose output"
  complete -c yay -n "__yay_seen_subcommand_from untar" -s h -l help -d "Show help message"

  # File path completion for untar input with archive extensions
  complete -c yay -n __yay_untar_needs_input -r -a "*.tar *.tar.gz *.tgz *.tar.zst *.tzst *.tar.bz2 *.tbz *.tbz2 *.tb2 *.tz2 *.tar.bz3 *.7z *.tar.7z *.rar" -d "Archive file"

  # Directory completion for untar output directory
  complete -c yay -n __yay_untar_needs_output -r -a "(__fish_complete_directories)" -d "Output directory"

  ######################
  # INSPECT SUBCOMMAND #
  ######################

  # Options for 'inspect'
  complete -c yay -n "__yay_seen_subcommand_from inspect" -s e -l experimental -d "Enable experimental features (nix-command flakes)"
  complete -c yay -n "__yay_seen_subcommand_from inspect" -s p -l packages -d "Show only packages"
  complete -c yay -n "__yay_seen_subcommand_from inspect" -s o -l options -d "Show only NixOS/Home Manager options"
  complete -c yay -n "__yay_seen_subcommand_from inspect" -s s -l system -r -a "x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin" -d "Specify system"
  complete -c yay -n "__yay_seen_subcommand_from inspect" -s h -l help -d "Show help message"

  # Flake reference completion for inspect (accepts github:, paths, etc.)
  complete -c yay -n "__yay_seen_subcommand_from inspect; and not __yay_seen_option -h --help; and test (count (commandline -poc)) -eq 2" -r -d "Flake reference (e.g., github:user/repo, ., ./path)"

  ######################
  # FIND SUBCOMMAND    #
  ######################

  # Options for 'find'
  complete -c yay -n "__yay_seen_subcommand_from find" -s o -l owner -r -d "Find which package owns a file path"
  complete -c yay -n "__yay_seen_subcommand_from find" -s a -l all -d "Search entire store (default: current generation only)"
  complete -c yay -n "__yay_seen_subcommand_from find" -s e -l experimental -d "Enable experimental features (nix-command flakes)"
  complete -c yay -n "__yay_seen_subcommand_from find" -s h -l help -d "Show help message"

  # Pattern/file path completion for find
  complete -c yay -n "__yay_seen_subcommand_from find; and __yay_seen_option -o --owner" -r -d "File path"
  complete -c yay -n "__yay_seen_subcommand_from find; and not __yay_seen_option -h --help -o --owner; and test (count (commandline -poc)) -eq 2" -d "Search pattern"

  ######################
  # BUILD SUBCOMMAND   #
  ######################

  # Options for 'build'
  complete -c yay -n "__yay_seen_subcommand_from build" -s p -l path -d "Show full store paths of built packages"
  complete -c yay -n "__yay_seen_subcommand_from build" -s e -l experimental -d "Enable experimental features (nix-command flakes)"
  complete -c yay -n "__yay_seen_subcommand_from build" -s h -l help -d "Show help message"

  # Package completion for build (can add multiple packages)
  complete -c yay -n "__yay_seen_subcommand_from build; and not __yay_seen_option -h --help" -a "(__yay_list_packages)" -d "Package to build"
''