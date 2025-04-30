function __yay_run
    set -l cmd_string $argv[1]
    __yay_yellow "→ $cmd_string"
    # Use fish -c for slightly safer execution than raw eval
    fish -c "$cmd_string"
    set -l run_status $status
    if test $run_status -eq 0
        __yay_green "✔ $cmd_string"
    else
        __yay_red "✘ $cmd_string (exit $run_status)"
        return $run_status
    end
end