function __yay_find
    set -l opts h/help a/all o/owner= e/experimental
    argparse $opts -- $argv; or return

    if set -q _flag_help
        echo "Usage: yay find [OPTIONS] PATTERN"
        echo ""
        echo "Search for packages and files in the Nix store"
        echo ""
        echo "Options:"
        echo "  -o, --owner PATH    Find which package owns a file path"
        echo "  -a, --all           Search entire store (default: current generation only)"
        echo "  -e, --experimental  Enable experimental features (nix-command flakes)"
        echo "  -h, --help          Show this help message"
        echo ""
        echo "Examples:"
        echo "  yay find firefox                # Find anything matching 'firefox'"
        echo "  yay find '*.service'            # Find systemd service files (quote wildcards!)"
        echo "  yay find env                    # Find anything with 'env' in the name"
        echo "  yay find --all tmux             # Search entire store for tmux"
        echo "  yay find --owner /usr/bin/fish  # Find which package owns fish binary"
        return
    end

    # Get search pattern
    set -l pattern
    if set -q _flag_owner
        set pattern $_flag_owner
    else if test (count $argv) -eq 0
        __yay_red "Error: no search pattern provided"
        return 1
    else
        set pattern $argv[1]
    end

    __yay_green "««« SEARCHING NIX STORE »»»"

    # Owner mode: find which package owns a file
    if set -q _flag_owner
        __yay_yellow "Finding owner of: $pattern"

        # Resolve symlinks to get actual store path
        set -l real_path (realpath "$pattern" 2>/dev/null)
        if test $status -ne 0
            __yay_red "✘ Path not found: $pattern"
            return 1
        end

        # Extract store path
        if string match -q '/nix/store/*' "$real_path"
            set -l store_path (string replace -r '^(/nix/store/[^/]+).*' '$1' "$real_path")
            __yay_green "Store path: $store_path"

            # Try to get package info
            set -l pkg_info (nix-store -q --deriver "$store_path" 2>/dev/null)
            if test $status -eq 0
                echo ""
                __yay_yellow "Derivation:"
                echo "  $pkg_info"
            end

            # Show what references this
            echo ""
            __yay_yellow "Referenced by:"
            nix-store -q --referrers "$store_path" 2>/dev/null | while read -l ref
                echo "  $ref"
            end
        else
            __yay_red "✘ Path is not in Nix store: $real_path"
            return 1
        end
        return 0
    end

    # Default search mode: search in store paths
    __yay_yellow "Searching for: $pattern"

    if set -q _flag_all
        __yay_yellow "Scope: entire store (this may take a while...)"
        echo ""
        __yay_yellow "Store paths:"

        # Search all store directory names
        ls -1 /nix/store/ 2>/dev/null | grep -i "$pattern" | while read -l entry
            echo "  /nix/store/$entry"
        end

        echo ""
        __yay_yellow "Files in store:"

        # Also search for files if pattern contains wildcards or special chars
        if string match -q -r '[*?]' "$pattern"
            if command -v fd >/dev/null 2>&1
                fd --color=always -H "$pattern" /nix/store 2>/dev/null | head -100
            else
                find /nix/store -name "$pattern" 2>/dev/null | head -100
            end
        end
    else
        __yay_yellow "Scope: current generation"
        echo ""

        # Get store paths from current generation
        set -l gen_paths

        # System profile
        if test -e /run/current-system
            set -a gen_paths (nix-store -q --requisites /run/current-system 2>/dev/null)
        end

        # User profile
        if test -e $HOME/.nix-profile
            set -a gen_paths (nix-store -q --requisites $HOME/.nix-profile 2>/dev/null)
        end

        if test (count $gen_paths) -eq 0
            __yay_red "✘ Could not query current generation"
            return 1
        end

        __yay_yellow "Store paths:"
        # Filter and display matching store paths
        printf "%s\n" $gen_paths | grep -i "$pattern" | sort -u | while read -l path
            echo "  $path"
        end

        # If pattern has wildcards, also search files within those paths
        if string match -q -r '[*?]' "$pattern"
            echo ""
            __yay_yellow "Files:"

            # Search files in the matched paths
            for gen_path in $gen_paths
                if command -v fd >/dev/null 2>&1
                    fd --color=always -H "$pattern" "$gen_path" 2>/dev/null
                else
                    find "$gen_path" -name "$pattern" 2>/dev/null
                end
            end | sort -u | head -100
        end
    end

    __yay_green "✔ Search complete"
end
