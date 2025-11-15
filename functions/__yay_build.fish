function __yay_build
    set -l opts h/help p/path e/experimental
    argparse $opts -- $argv; or return

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: yay build [OPTIONS] PACKAGE [PACKAGE...]"
        echo ""
        echo "Build packages into the Nix store (for binary cache serving)"
        echo ""
        echo "Options:"
        echo "  -p, --path          Show full store paths of built packages"
        echo "  -e, --experimental  Enable experimental features (nix-command flakes)"
        echo "  -h, --help          Show this help message"
        echo ""
        echo "Examples:"
        echo "  yay build firefox                # Auto-prefixes to nixpkgs#firefox"
        echo "  yay build nixpkgs#chromium       # Explicit flake reference"
        echo "  yay build .#mypackage            # Build from local flake"
        echo "  yay build firefox chromium       # Build multiple packages"
        echo "  yay build --path firefox         # Show resulting store paths"
        echo ""
        echo "Note: Packages are built into /nix/store but NOT installed to your profile."
        echo "      Perfect for populating a binary cache!"
        return
    end

    set -l packages $argv

    __yay_green "««« BUILDING PACKAGES »»»"

    # Build base nix command
    set -l nix_cmd "nix build"
    if set -q _flag_experimental
        set nix_cmd "$nix_cmd --extra-experimental-features \"nix-command flakes\""
    end

    # Add --print-out-paths if --path flag is set
    set -l show_paths 0
    if set -q _flag_path
        set show_paths 1
        set nix_cmd "$nix_cmd --print-out-paths"
    end

    # Process each package
    set -l failed_builds
    set -l successful_builds

    for pkg in $packages
        __yay_yellow "Building: $pkg"

        # First try the package as-is
        set -l build_cmd "$nix_cmd --no-link $pkg"
        set -l result (fish -c "$build_cmd" 2>&1)
        set -l exit_code $status

        # If it failed and doesn't contain #, try prefixing with nixpkgs#
        if test $exit_code -ne 0; and not string match -q '*#*' "$pkg"
            __yay_yellow "Retrying with nixpkgs# prefix..."
            set build_cmd "$nix_cmd --no-link nixpkgs#$pkg"
            set result (fish -c "$build_cmd" 2>&1)
            set exit_code $status
            if test $exit_code -eq 0
                set pkg "nixpkgs#$pkg"
            end
        end

        # Report result
        if test $exit_code -eq 0
            set -a successful_builds "$pkg"

            if test $show_paths -eq 1
                # Result contains the store path(s)
                echo "$result" | while read -l path
                    if test -n "$path"
                        __yay_green "  ✔ $path"
                    end
                end
            else
                # Extract package name and version from store path
                set -l store_info (echo "$result" | string match -r '/nix/store/[^-]+-(.+)' | tail -1)
                if test -n "$store_info"
                    __yay_green "  ✔ Built: $store_info"
                else
                    __yay_green "  ✔ Built successfully"
                end
            end
        else
            set -a failed_builds "$pkg"
            __yay_red "  ✘ Failed to build $pkg"

            # Show error details
            echo "$result" | grep -i "error" | head -3 | while read -l err_line
                echo "    $err_line"
            end
        end

        echo ""
    end

    # Summary
    echo ""
    if test (count $successful_builds) -gt 0
        __yay_green "Successfully built (count $successful_builds) package(s):"
        for pkg in $successful_builds
            echo "  • $pkg"
        end
    end

    if test (count $failed_builds) -gt 0
        echo ""
        __yay_red "Failed to build (count $failed_builds) package(s):"
        for pkg in $failed_builds
            echo "  • $pkg"
        end
        return 1
    end

    __yay_green "✔ Build complete"
end
