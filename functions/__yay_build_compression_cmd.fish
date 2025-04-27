function __yay_build_compression_cmd
    set -l type $argv[1]
    set -l level $argv[2]
    set -l threads $argv[3]

    switch $type
        case gzip
            echo "gzip -$level"
        case zstd
            set -l cmd "zstd -$level"
            if test -n "$threads"
                set cmd "$cmd -T$threads"
            end
            echo $cmd
        case bzip2
            echo "bzip2 -$level"
        case bzip3
            set -l cmd "bzip3 -b $level"
            if test -n "$threads"
                set cmd "$cmd -j $threads"
            end
            echo $cmd
    end
end
