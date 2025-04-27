function __yay_garbage
    __yay_yellow "Requesting sudo credentials…"
    sudo -v
    __yay_green "««« CLEANING NIX GARBAGE »»»"
    for cmd in \
        "sudo nh clean all" \
        "nh clean all" \
        "sudo nix-collect-garbage --delete-old" \
        "nix-collect-garbage --delete-old" \
        "sudo nix-store --gc" \
        "nix-store --gc"
        __yay_run "$cmd"
    end
    __yay_clean_hm_backups
end