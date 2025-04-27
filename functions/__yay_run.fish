function __yay_run
    set cmd $argv[1]
    __yay_yellow "→ $cmd"
    eval $cmd
    if test $status -eq 0
        __yay_green "✔ $cmd"
    else
        __yay_red "✘ $cmd (exit $status)"
        return $status
    end
end
