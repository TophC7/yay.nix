#!/usr/bin/env fish

function yay_function
    # Main dispatch
    if test (count $argv) -eq 0
        echo "yay! :D"
        echo "Usage: yay <command> [args]"
        echo "Commands: rebuild, update, garbage, try, tar, untar, inspect, find, build"
        exit 1
    end

    switch $argv[1]
        case rebuild
            __yay_rebuild $argv[2..-1]; or exit $status
        case update
            __yay_update $argv[2..-1]; or exit $status
        case garbage
            __yay_garbage; or exit $status
        case try
            __yay_try $argv[2..-1]; or exit $status
        case tar
            __yay_tar $argv[2..-1]; or exit $status
        case untar
            __yay_untar $argv[2..-1]; or exit $status
        case serve
            __yay_serve $argv[2..-1]; or exit $status
        case inspect
            __yay_inspect $argv[2..-1]; or exit $status
        case find
            __yay_find $argv[2..-1]; or exit $status
        case build
            __yay_build $argv[2..-1]; or exit $status
        case '*'
            __yay_red "Unknown subcommand: $argv[1]"
            exit 1
    end
end

# For direct fish shell usage
function yay
    yay_function $argv
end
