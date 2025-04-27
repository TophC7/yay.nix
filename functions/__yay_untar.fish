function __yay_untar
    set -l options h/help 'o/output=' v/verbose
    argparse $options -- $argv
    or return 1

    if set -ql _flag_help || test (count $argv) -eq 0
        echo "Usage: yay untar [OPTIONS] ARCHIVE [OUTPUT_DIR]"
        echo "Extract files from various archive formats"
        echo ""
        echo "Options:"
        echo "  -o, --output DIR  Output directory (alternative to specifying as second argument)"
        echo "  -v, --verbose   Enable verbose output"
        echo "  -h, --help    Show this help message"
        echo ""
        echo "Supported archive types (auto-detected from extension):"
        echo "  7zip  - .7z, .tar.7z"
        echo "  bzip2   - .tar.bz2, .tb2, .tbz, .tbz2, .tz2"
        echo "  bzip3   - .tar.bz3"
        echo "  gzip  - .tar.gz, .tgz"
        echo "  rar   - .rar"
        echo "  tar   - .tar"
        echo "  zstd  - .tar.zst, .tzst"
        return 0
    end

    # Validate input file
    set -l archive_path $argv[1]
    if not test -f $archive_path
        __yay_red "Archive file does not exist: $archive_path"
        return 1
    end

    # Set verbose flag for commands
    set -l verbose false
    if set -ql _flag_verbose
        set verbose true
    end

    # Detect compression type from extension
    set -l compression_type unknown
    switch $archive_path
        case "*.tar.gz" "*.tgz"
            set compression_type gzip
        case "*.tar.zst" "*.tzst"
            set compression_type zstd
        case "*.tar.bz2" "*.tb2" "*.tbz" "*.tbz2" "*.tz2"
            set compression_type bzip2
        case "*.tar.bz3"
            set compression_type bzip3
        case "*.7z" "*.tar.7z"
            set compression_type 7zip
        case "*.rar"
            set compression_type rar
        case "*.tar"
            set compression_type tar
        case '*'
            __yay_red "Unsupported archive type: $archive_path"
            __yay_red "Supported extensions: .7z, .rar, .tar, .tar.7z, .tar.bz2, .tar.bz3, .tar.gz, .tar.zst, .tb2, .tbz, .tbz2, .tgz, .tz2, .tzst"
            return 1
    end

    # Determine output directory
    set -l output_dir
    if test (count $argv) -ge 2
        # Use second positional argument as output directory
        set output_dir $argv[2]
    else if set -ql _flag_output
        # Fall back to -o/--output flag if provided
        set output_dir $_flag_output
    else
        # Extract base name from archive for default output directory
        set -l base_name (basename $archive_path | sed -E 's/\.(tar\.[^.]+|t[gb]z2?|tz2|7z|rar)$//')
        set output_dir "./$base_name"
    end

    # Create output directory if it doesn't exist
    if not test -d $output_dir
        mkdir -p $output_dir
        if test $status -ne 0
            __yay_red "Failed to create output directory: $output_dir"
            return 1
        end
    else
        # If directory exists and we're using auto-generated name (not explicitly specified),
        # show an error to prevent accidental overwrites
        if test (count $argv) -eq 1 && not set -ql _flag_output
            __yay_red "Output directory already exists: $output_dir"
            __yay_red "Please specify a different output directory with -o/--output or second argument, or remove the existing one"
            return 1
        end
    end

    # Handle extraction based on compression type
    switch $compression_type
        case tar
            # Build tar command as string
            set -l cmd "tar -x"
            if test "$verbose" = true
                set cmd "$cmd"v
            end
            set cmd "$cmd"f" \"$archive_path\" -C \"$output_dir\""

            __yay_run "$cmd"
            return $status

        case gzip bzip2 zstd
            # Create full command string
            set -l cmd "$compression_type -dc \"$archive_path\" | tar -x"
            if test "$verbose" = true
                set cmd "$cmd"v
            end
            set cmd "$cmd -C \"$output_dir\""

            __yay_run "$cmd"
            return $status

        case bzip3
            # Create full command string
            set -l cmd "bzip3 -d < \"$archive_path\" | tar -x"
            if test "$verbose" = true
                set cmd "$cmd"v
            end
            set cmd "$cmd -C \"$output_dir\""

            __yay_run "$cmd"
            return $status

        case 7zip
            # Build full command string
            set -l cmd "7z x -o\"$output_dir\" -y"

            # Add quiet mode if not verbose
            if test "$verbose" = false
                set cmd "$cmd -bd"
            end

            # Add archive path
            set cmd "$cmd \"$archive_path\""

            __yay_run "$cmd"
            return $status

        case rar
            # Build full command string
            set -l cmd "unrar x -y"

            # Add archive and output paths
            set cmd "$cmd \"$archive_path\" \"$output_dir/\""

            # Add verbose/quiet option
            if test "$verbose" = true
                set cmd "$cmd -v"
            else
                set cmd "$cmd -idq"
            end

            __yay_run "$cmd"
            return $status
    end
end