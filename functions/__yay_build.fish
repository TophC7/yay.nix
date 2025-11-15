function __yay_build
    set -l opts h/help p/path e/experimental c/copy=
    argparse $opts -- $argv; or return

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: yay build [OPTIONS] PACKAGE [PACKAGE...]"
        echo ""
        echo "Build packages into the Nix store (for binary cache serving)"
        echo ""
        echo "Options:"
        echo "  -p, --path              Show full store paths of built packages"
        echo "  -c, --copy CACHE_URL    Copy built packages to binary cache"
        echo "  -e, --experimental      Enable experimental features (nix-command flakes)"
        echo "  -h, --help              Show this help message"
        echo ""
        echo "Examples:"
        echo "  yay build firefox                          # Auto-prefixes to nixpkgs#firefox"
        echo "  yay build nixpkgs#chromium                 # Explicit flake reference"
        echo "  yay build .#mypackage                      # Build from local flake"
        echo "  yay build firefox chromium                 # Build multiple packages"
        echo "  yay build --path firefox                   # Show resulting store paths"
        echo "  yay build --copy ssh://nimbus firefox      # Build and copy to cache"
        echo "  yay build --copy s3://my-bucket .#myapp    # Copy to S3 cache"
        echo ""
        echo "Cache URL formats:"
        echo "  ssh://[user@]host[:port]  - SSH binary cache"
        echo "  s3://bucket-name          - S3-compatible cache"
        echo "  file:///path/to/cache     - Local directory cache"
        echo ""
        return
    end

    set -l packages $argv

    __yay_green "««« BUILDING PACKAGES »»»"

    # Build base nix command
    set -l nix_cmd "nix build"
    if set -q _flag_experimental
        set nix_cmd "$nix_cmd --extra-experimental-features \"nix-command flakes\""
    end

    # Add --print-out-paths if --path flag is set OR if we need to copy
    set -l show_paths 0
    set -l copy_to_cache 0
    set -l cache_url ""

    if set -q _flag_path
        set show_paths 1
        set nix_cmd "$nix_cmd --print-out-paths"
    end

    if set -q _flag_copy
        set copy_to_cache 1
        set cache_url $_flag_copy
        # Always need paths for copying
        set nix_cmd "$nix_cmd --print-out-paths"
        __yay_yellow "Will copy to cache: $cache_url"
        echo ""
    end

    # Process each package
    set -l failed_builds
    set -l successful_builds
    set -l built_paths

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

            # Collect store paths for copying
            echo "$result" | while read -l path
                if test -n "$path"; and string match -q '/nix/store/*' "$path"
                    set -a built_paths "$path"
                end
            end

            if test $show_paths -eq 1; or test $copy_to_cache -eq 1
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
            echo "$result" | grep -i error | head -3 | while read -l err_line
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

    # Copy to cache if requested
    if test $copy_to_cache -eq 1; and test (count $built_paths) -gt 0
        echo ""
        __yay_green "««« COPYING TO CACHE »»»"
        __yay_yellow "Destination: $cache_url"

        # Build nix copy command
        set -l copy_cmd "nix copy --to $cache_url"
        if set -q _flag_experimental
            set copy_cmd "$copy_cmd --extra-experimental-features \"nix-command flakes\""
        end

        # Add all built paths
        for path in $built_paths
            set copy_cmd "$copy_cmd $path"
        end

        __yay_yellow "Copying (count $built_paths) store path(s)..."

        # Show the paths being copied
        for path in $built_paths
            echo "  → $path"
        end
        echo ""

        # Run nix copy with output visible
        __yay_yellow "Running: nix copy..."
        fish -c "$copy_cmd"
        set -l copy_exit $status

        if test $copy_exit -eq 0
            echo ""
            __yay_green "✔ Successfully copied to cache"
        else
            echo ""
            __yay_red "✘ Failed to copy to cache"
            return 1
        end
    end

    __yay_green "✔ Build complete"
end
