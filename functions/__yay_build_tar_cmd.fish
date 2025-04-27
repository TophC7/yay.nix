function __yay_tar
    set -l options h/help 'o/output=' 'c/compression=' 'l/level=' 't/threads=' v/verbose
    argparse $options -- $argv
    or return 1

    if set -ql _flag_help || test (count $argv) -eq 0
        echo "Usage: yay tar [OPTIONS] INPUT_PATH [OUTPUT_PATH]"
        echo "Compress files or directories with tar and various compression methods"
        echo ""
        echo "Options:"
        echo "  -c, --compression TYPE  Compression type (default: zstd)"
        echo "  -l, --level N       Compression level where applicable (default: algorithm specific)"
        echo "  -o, --output PATH     Output file path (alternative to specifying as second argument)"
        echo "  -t, --threads N     Number of threads to use where supported (default: 1)"
        echo "  -v, --verbose       Enable verbose output"
        echo "  -h, --help        Show this help message"
        echo ""
        echo "Supported compression types:"
        echo "  7zip   - .7z or .tar.7z (levels: 0-9, default 5, threads: yes)"
        echo "  bzip2  - .tar.bz2 (levels: 1-9, default 9)"
        echo "  bzip3  - .tar.bz3 (block size in MiB: 1-511, default 16, threads: yes)"
        echo "  gzip   - .tar.gz/.tgz (levels: 1-9, default 6)"
        echo "  tar  - .tar (no compression)"
        echo "  zstd   - .tar.zst (levels: 1-19, default 3, threads: yes)"
        return 0
    end

    # Validate input path
    set -l input_path $argv[1]
    if not test -e $input_path
        __yay_red "Input path does not exist: $input_path"
        return 1
    end

    # Get base name for the archive
    set -l base_name (basename $input_path)

    # Set compression type and associated parameters
    set -l compression_type zstd # Default is zstd
    if set -ql _flag_compression
        set compression_type $_flag_compression
    end

    # Set the default levels and extensions
    set -l file_ext
    set -l level

    switch $compression_type
        case gzip
            set file_ext ".tar.gz"
            set level 6
        case zstd
            set file_ext ".tar.zst"
            set level 3
        case bzip2
            set file_ext ".tar.bz2"
            set level 9
        case bzip3
            set file_ext ".tar.bz3"
            set level 16 # This is block size in MiB for bzip3
        case 7zip 7z
            set file_ext ".7z"
            set level 5
        case tar
            set file_ext ".tar"
        case '*'
            __yay_red "Unsupported compression type: $compression_type"
            __yay_red "Supported types: zstd, 7zip, gzip, bzip2, bzip3, tar"
            return 1
    end

    # Override default level if specified
    if set -ql _flag_level
        set level $_flag_level
        # Validate level for the selected compression type
        __yay_validate_compression_level $compression_type $level; or return 1
    end

    # Set the output file name
    set -l output_file
    if test (count $argv) -ge 2
        set output_file $argv[2]
    else if set -ql _flag_output
        set output_file $_flag_output
    else
        set output_file "$base_name$file_ext"
    end

    # Set verbose flag for commands
    set -l verbose false
    if set -ql _flag_verbose
        set verbose true
    end

    switch $compression_type
        case tar
            set -l cmd
            if test "$verbose" = true
                set cmd "tar -cvf \"$output_file\" \"$input_path\""
            else
                set cmd "tar -cf \"$output_file\" \"$input_path\""
            end

            __yay_run "$cmd"
            return $status

        case gzip bzip2 zstd bzip3
            # Create tar command with proper flags
            set -l tar_flags -c
            if test "$verbose" = true
                set tar_flags -cv
            end

            # Set up compression command
            set -l threads ""
            if set -ql _flag_threads
                set threads $_flag_threads
            end

            # Build the full command
            set -l full_cmd "tar $tar_flags \"$input_path\" | "

            switch $compression_type
                case gzip
                    set full_cmd "$full_cmd gzip -$level"
                case zstd
                    set full_cmd "$full_cmd zstd -$level"
                    if test -n "$threads"
                        set full_cmd "$full_cmd -T$threads"
                    end
                case bzip2
                    set full_cmd "$full_cmd bzip2 -$level"
                case bzip3
                    set full_cmd "$full_cmd bzip3 -b $level"
                    if test -n "$threads"
                        set full_cmd "$full_cmd -j $threads"
                    end
            end

            set full_cmd "$full_cmd > \"$output_file\""

            __yay_run "$full_cmd"
            return $status

        case 7zip 7z
            # Build command string for 7z
            set -l cmd "7z a -mx=$level -t7z"

            # Add threads if specified
            if set -ql _flag_threads
                set cmd "$cmd -mmt=$_flag_threads"
            end

            # Add quiet mode if not verbose
            if test "$verbose" = false
                set cmd "$cmd -bd"
            end

            # Finalize command with paths
            set cmd "$cmd \"$output_file\" \"$input_path\""

            __yay_run "$cmd"
            return $status
    end
end
