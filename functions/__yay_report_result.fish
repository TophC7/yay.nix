function __yay_report_result
    set -l action $argv[1]
    set -l result $argv[2]
    set -l output $argv[3]

    if test $result -eq 0
        __yay_green "Successfully $action: $output"
    else
        __yay_red "Failed to $action with exit code $result"
    end

    return $result
end