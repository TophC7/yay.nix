function __yay_build
    set -l opts h/help s/show-paths e/experimental 'B/build-host=' l/local 'c/copy='
    argparse $opts -- $argv; or return

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: yay build [OPTIONS] PACKAGE [PACKAGE...]"
        echo ""
        echo "Build packages into the Nix store (for binary cache serving)"
        echo ""
        echo "Options:"
        echo "  -h, --help                Show this help message"
        echo "  -s, --show-paths          Show full store paths of built packages"
        echo "  -B, --build-host HOST     Build on this host instead of locally"
        echo "  -l, --local               Force local build (bypass default build host)"
        echo "  -c, --copy CACHE_URL      Copy built packages to binary cache"
        echo "  -e, --experimental        Enable experimental features (nix-command flakes)"
        echo ""
        echo "Build Host Priority:"
        echo "  1. --local flag           Force local build"
        echo "  2. --build-host HOST      Use specified host"
        echo "  3. \$YAY_BUILD_HOST        Runtime override"
        echo "  4. \$YAY_DEFAULT_BUILD_HOST  Baked-in default (from Nix module)"
        echo "  5. (empty)                Build locally"
        echo ""
        echo "Examples:"
        echo "  yay build firefox                          # Build locally (or on default host)"
        echo "  yay build nixpkgs#chromium                 # Explicit flake reference"
        echo "  yay build .#mypackage                      # Build from local flake"
        echo "  yay build firefox -B zebes                 # Build on zebes"
        echo "  yay build firefox --local                  # Force local (bypass defaults)"
        echo "  yay build --show-paths firefox             # Show resulting store paths"
        echo "  yay build --copy ssh://nimbus firefox      # Build and copy to cache"
        echo ""
        echo "Cache URL formats:"
        echo "  ssh://[user@]host[:port]  - SSH binary cache"
        echo "  s3://bucket-name          - S3-compatible cache"
        echo "  file:///path/to/cache     - Local directory cache"
        echo ""
        return
    end

    set -l packages $argv

    # Resolve build host: flag > env > config > local
    set build_host ""
    if set -q _flag_local
        # Explicit local build - don't use any build host
        set build_host ""
    else if test -n "$_flag_build_host"
        set build_host $_flag_build_host
    else if test -n "$YAY_BUILD_HOST"
        set build_host $YAY_BUILD_HOST
    else if test -n "$YAY_DEFAULT_BUILD_HOST"
        set build_host $YAY_DEFAULT_BUILD_HOST
    end

    # If we ARE the build host, build locally
    if test "$build_host" = (hostname)
        set build_host ""
    end

    __yay_green "<<< BUILDING PACKAGES >>>"

    # Show build location
    if test -n "$build_host"
        __yay_yellow "Building on: $build_host"
    else
        __yay_yellow "Building locally"
    end

    # Determine if we need paths output
    set -l show_paths 0
    set -l copy_to_cache 0
    set -l cache_url ""

    if set -q _flag_show_paths
        set show_paths 1
    end

    if set -q _flag_copy
        set copy_to_cache 1
        set cache_url $_flag_copy
        __yay_yellow "Will copy to cache: $cache_url"
    end

    echo ""

    # Process each package
    set -l failed_builds
    set -l successful_builds
    set -l built_paths

    for pkg in $packages
        __yay_yellow "Building: $pkg"

        # Build the nix command
        set -l nix_cmd "nix build"

        # Add experimental features if requested
        if set -q _flag_experimental
            set nix_cmd "$nix_cmd --extra-experimental-features \"nix-command flakes\""
        end

        # Add remote build if build_host is set
        if test -n "$build_host"
            set nix_cmd "$nix_cmd --store ssh-ng://$build_host --eval-store auto"
        end

        # Always use --print-out-paths if showing paths or copying
        if test $show_paths -eq 1; or test $copy_to_cache -eq 1
            set nix_cmd "$nix_cmd --print-out-paths"
        end

        set nix_cmd "$nix_cmd --no-link"

        # First try the package as-is
        set -l build_cmd "$nix_cmd $pkg"
        set -l result (fish -c "$build_cmd" 2>&1)
        set -l exit_code $status

        # If it failed and doesn't contain #, try prefixing with nixpkgs#
        if test $exit_code -ne 0; and not string match -q '*#*' "$pkg"
            __yay_yellow "Retrying with nixpkgs# prefix..."
            set build_cmd "$nix_cmd nixpkgs#$pkg"
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
                        __yay_green "  + $path"
                    end
                end
            else
                # Extract package name and version from store path
                set -l store_info (echo "$result" | string match -r '/nix/store/[^-]+-(.+)' | tail -1)
                if test -n "$store_info"
                    __yay_green "  + Built: $store_info"
                else
                    __yay_green "  + Built successfully"
                end
            end
        else
            set -a failed_builds "$pkg"
            __yay_red "  x Failed to build $pkg"

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
            echo "  - $pkg"
        end
    end

    if test (count $failed_builds) -gt 0
        echo ""
        __yay_red "Failed to build (count $failed_builds) package(s):"
        for pkg in $failed_builds
            echo "  - $pkg"
        end
        return 1
    end

    # Copy to cache if requested
    if test $copy_to_cache -eq 1; and test (count $built_paths) -gt 0
        echo ""
        __yay_green "<<< COPYING TO CACHE >>>"
        __yay_yellow "Destination: $cache_url"

        # Build nix copy command
        set -l copy_cmd "nix copy --to $cache_url"
        if set -q _flag_experimental
            set copy_cmd "$copy_cmd --extra-experimental-features \"nix-command flakes\""
        end

        # For remote builds, we need to copy FROM the remote store
        if test -n "$build_host"
            set copy_cmd "$copy_cmd --from ssh-ng://$build_host"
        end

        # Add all built paths
        for path in $built_paths
            set copy_cmd "$copy_cmd $path"
        end

        __yay_yellow "Copying (count $built_paths) store path(s)..."

        # Show the paths being copied
        for path in $built_paths
            echo "  -> $path"
        end
        echo ""

        # Run nix copy with output visible
        __yay_yellow "Running: nix copy..."
        fish -c "$copy_cmd"
        set -l copy_exit $status

        if test $copy_exit -eq 0
            echo ""
            __yay_green "+ Successfully copied to cache"
        else
            echo ""
            __yay_red "x Failed to copy to cache"
            return 1
        end
    end

    __yay_green "+ Build complete"
end
