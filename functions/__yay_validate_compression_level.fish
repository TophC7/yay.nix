function __yay_validate_compression_level
    set -l type $argv[1]
    set -l level $argv[2]

    switch $type
        case gzip bzip2
            if test $level -lt 1 -o $level -gt 9
                __yay_red "Invalid compression level for $type: $level (should be 1-9)"
                return 1
            end
        case zstd
            if test $level -lt 1 -o $level -gt 19
                __yay_red "Invalid compression level for $type: $level (should be 1-19)"
                return 1
            end
        case bzip3
            if test $level -lt 1 -o $level -gt 511
                __yay_red "Invalid block size for $type: $level (should be 1-511 MiB)"
                return 1
            end
        case 7zip 7z
            if test $level -lt 0 -o $level -gt 9
                __yay_red "Invalid compression level for $type: $level (should be 0-9)"
                return 1
            end
    end
    return 0
end