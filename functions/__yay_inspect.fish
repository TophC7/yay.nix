function __yay_inspect
    set -l opts h/help e/experimental p/packages o/options s/system=
    argparse $opts -- $argv; or return

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: yay inspect [OPTIONS] FLAKE"
        echo ""
        echo "Introspect a Nix flake to list its packages, options, and outputs"
        echo ""
        echo "Options:"
        echo "  -e, --experimental  Enable experimental features (nix-command flakes)"
        echo "  -p, --packages      Show only packages"
        echo "  -o, --options       Show only NixOS/Home Manager options"
        echo "  -s, --system SYS    Specify system (default: current system)"
        echo "  -h, --help          Show this help message"
        echo ""
        echo "Examples:"
        echo "  yay inspect github:NixOS/nixpkgs"
        echo "  yay inspect . --packages"
        echo "  yay inspect ~/my-flake --options"
        return
    end

    set -l flake_ref $argv[1]

    # Determine system
    set -l system
    if set -q _flag_system
        set system $_flag_system
    else
        set system (nix eval --impure --raw --expr 'builtins.currentSystem' 2>/dev/null)
        if test $status -ne 0
            set system "x86_64-linux"  # fallback
        end
    end

    __yay_green "««« INSPECTING FLAKE »»»"
    __yay_yellow "Flake: $flake_ref"
    __yay_yellow "System: $system"
    echo ""

    # Build base nix command
    set -l nix_cmd "nix"
    if set -q _flag_experimental
        set nix_cmd "$nix_cmd --extra-experimental-features \"nix-command flakes\""
    end

    # Show flake structure
    if not set -q _flag_packages; and not set -q _flag_options
        __yay_yellow "→ Flake structure:"
        set -l show_cmd "$nix_cmd flake show $flake_ref"

        fish -c "$show_cmd" 2>/dev/null
        if test $status -ne 0
            __yay_red "✘ Failed to show flake structure"
            return 1
        end
        echo ""
    end

    # List packages if requested or by default
    if set -q _flag_packages; or not set -q _flag_options
        __yay_yellow "→ Packages for $system:"

        # Try to list packages for the current system
        set -l packages_path "$flake_ref#packages.$system"
        set -l eval_cmd "$nix_cmd eval --apply 'pkgs: builtins.attrNames pkgs' $packages_path"

        set -l result (fish -c "$eval_cmd" 2>/dev/null)
        if test $status -eq 0
            # Parse Nix list format and display nicely
            echo $result | string replace -r '^\[ *' '' | string replace -r ' *\]$' '' | string split '" "' | string replace -a '"' '' | string trim | while read -l pkg
                if test -n "$pkg"
                    echo "  • $pkg"
                end
            end
        else
            echo "  (no packages found for $system)"
        end
        echo ""
    end

    # List NixOS module options if requested
    if set -q _flag_options
        __yay_yellow "→ NixOS Module Options:"

        # Try different common paths for options
        set -l option_paths \
            "$flake_ref#nixosModules.default.options" \
            "$flake_ref#nixosModules.default" \
            "$flake_ref#homeManagerModules.default.options" \
            "$flake_ref#homeManagerModules.default"

        set -l found_options 0
        for opt_path in $option_paths
            set -l eval_cmd "$nix_cmd eval --apply 'mod: if builtins.isAttrs mod then builtins.attrNames mod else []' $opt_path"

            set -l result (fish -c "$eval_cmd" 2>/dev/null)
            if test $status -eq 0; and test -n "$result"
                set found_options 1
                echo "  Path: $opt_path"

                echo $result | string replace -r '^\[ *' '' | string replace -r ' *\]$' '' | string split '" "' | string replace -a '"' '' | string trim | while read -l opt
                    if test -n "$opt"
                        echo "    • $opt"
                    end
                end
                echo ""
            end
        end

        if test $found_options -eq 0
            echo "  (no options found - flake may not export NixOS/Home Manager modules with options)"
            echo ""
        end
    end

    __yay_green "✔ Inspection complete"
end
