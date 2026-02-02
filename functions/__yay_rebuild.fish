function __yay_rebuild
    set -l opts h/help 'p/path=' 'H/host=' t/trace 'B/build-host=' l/local 's/substituter=' 'k/key='
    argparse $opts -- $argv; or return

    if set -q _flag_help
        echo "Usage: yay rebuild [OPTIONS]"
        echo ""
        echo "Rebuild the NixOS configuration"
        echo ""
        echo "Options:"
        echo "  -h, --help                Show this help message"
        echo "  -H, --host HOST           Target host to build for (default: current hostname)"
        echo "  -p, --path PATH           Path to the Nix configuration (overrides FLAKE)"
        echo "  -B, --build-host HOST     Build on this host instead of locally"
        echo "  -l, --local               Force local build (bypass default build host)"
        echo "  -t, --trace               Enable trace output"
        echo "  -s, --substituter URL     Extra binary cache URL to use"
        echo "  -k, --key KEY             Trusted public key for the cache"
        echo ""
        echo "Environment Variables:"
        echo "  YAY_BUILD_HOST            Override the default build host"
        echo "  YAY_DEFAULT_BUILD_HOST    Baked-in default build host (from Nix module)"
        echo "  YAY_DEFAULT_FLAKE_PATH    Baked-in default flake path (from Nix module)"
        echo ""
        echo "Examples:"
        echo "  yay rebuild                        # Build on default host, switch current"
        echo "  yay rebuild -H norion              # Build on default host, switch norion"
        echo "  yay rebuild --local                # Build locally (bypass remote)"
        echo "  yay rebuild -B zebes               # Build on zebes instead"
        echo "  yay rebuild -s https://cache.ryot.foo/ -k 'cache.ryot.foo:+A...'"
        return
    end

    set flake_path (__yay_get_flake_path $_flag_path); or return

    # Determine target host
    set target_host (hostname)
    if test -n "$_flag_host"
        set target_host $_flag_host
    end

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

    __yay_green "««« REBUILDING NIXOS ($target_host) »»»"

    # Show build location
    if test -n "$build_host"
        __yay_yellow "Building on: $build_host"
    else
        __yay_yellow "Building locally"
    end

    set orig (pwd)
    cd $flake_path

    # Build the nh command as a string
    set -l nh_cmd "nh os switch . -H $target_host"

    # Add build host if remote build
    if test -n "$build_host"
        set nh_cmd "$nh_cmd --build-host $build_host"
    end

    # Add target host if different from current (for remote deployment)
    if test "$target_host" != (hostname)
        set nh_cmd "$nh_cmd --target-host $target_host"
    end

    # Add nix options after --
    set nh_cmd "$nh_cmd -- --impure"

    # Add trace if requested
    if set -q _flag_trace
        set nh_cmd "$nh_cmd --show-trace"
    end

    # Add extra substituter if requested
    if set -q _flag_substituter
        __yay_yellow "Using extra cache: $_flag_substituter"
        set nh_cmd "$nh_cmd --option extra-substituters '$_flag_substituter'"
    end

    # Add trusted public key if requested
    if set -q _flag_key
        __yay_yellow "Using trusted key: $_flag_key"
        set nh_cmd "$nh_cmd --option extra-trusted-public-keys '$_flag_key'"
    end

    __yay_run "$nh_cmd"

    cd $orig
end
