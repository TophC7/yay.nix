package main

import (
    "bufio"
    "context"
    "flag"
    "fmt"
    "net/http"
    "os"
    "strconv"
    "strings"
    "time"
)

func main() {
    var port int
    var directory string

    // Define command-line flags
    flag.IntVar(&port, "port", 8080, "Port to serve on")
    flag.IntVar(&port, "p", 8080, "Port to serve on (shorthand)")
    flag.StringVar(&directory, "directory", ".", "Directory to serve")
    flag.StringVar(&directory, "d", ".", "Directory to serve (shorthand)")
    
    flag.Parse()

    // Check if the directory exists
    _, err := os.Stat(directory)
    if os.IsNotExist(err) {
        fmt.Printf("Directory '%s' not found.\n", directory)
        os.Exit(1)
    }

    // Create a file server handler to serve the directory's contents
    fileServer := http.FileServer(http.Dir(directory))

    // Create a new HTTP server and handle requests
    mux := http.NewServeMux()
    mux.Handle("/", fileServer)
    
    server := &http.Server{
        Addr:    ":" + strconv.Itoa(port),
        Handler: mux,
    }

    // Start the server in a goroutine
    go func() {
        fmt.Printf("Server started at http://localhost:%d\n", port)
        fmt.Printf("Serving directory: %s\n", directory)
        fmt.Printf("\nTo exit, enter 'x' and press Enter\n")
        
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            fmt.Printf("Error starting server: %s\n", err)
            os.Exit(1)
        }
    }()

    // Wait for user input to exit
    scanner := bufio.NewScanner(os.Stdin)
    for {
        if scanner.Scan() {
            input := strings.TrimSpace(scanner.Text())
            if strings.ToLower(input) == "x" {
                fmt.Println("Shutting down server...")
                
                // Create a context with timeout for graceful shutdown
                ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
                defer cancel()
                
                if err := server.Shutdown(ctx); err != nil {
                    fmt.Printf("Server shutdown error: %s\n", err)
                } else {
                    fmt.Println("Server stopped gracefully")
                }
                break
            }
        }
    }
}