function __yay_clean_hm_backups
    __yay_yellow "««« CLEARING HOME-MANAGER BACKUPS »»»"
    set files (find ~/.config -type f -name "*.homeManagerBackupFileExtension")
    if test (count $files) -eq 0
        __yay_green "No home manager backup files found"
        return
    end
    for f in $files
        __yay_run "rm $f"
    end
    __yay_green "Removed (count $files) home-manager backup files"
end