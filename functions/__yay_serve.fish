function __yay_serve
    set -l opts h/help 'p/port=' 'd/directory='
    argparse $opts -- $argv; or return

    if set -q _flag_help
        echo "Usage: yay serve [OPTIONS]"
        echo "Start a file server to serve files from a directory"
        echo ""
        echo "Options:"
        echo "  -p, --port PORT       Port to serve on (default: 8080)"
        echo "  -d, --directory DIR   Directory to serve (default: current directory)"
        echo "  -h, --help           Show this help message"
        return
    end

    set -l port 8080
    if test -n "$_flag_port"
        set port $_flag_port
    end

    set -l directory "."
    if test -n "$_flag_directory"
        set directory $_flag_directory
    end

    __yay_green "««« STARTING FILE SERVER »»»"
    __yay_yellow "Port: $port"
    __yay_yellow "Directory: $directory"

    # Run the Go file server
    yay-serve -p $port -d "$directory"
end
