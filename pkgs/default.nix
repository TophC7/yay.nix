{ pkgs, lib }:

let
  # Create a derivation with all the fish functions
  fishFunctions = pkgs.runCommand "yay-fish-functions" { } ''
    mkdir -p $out/share/fish/functions
    cp ${../functions}/*.fish $out/share/fish/functions/
    chmod +x $out/share/fish/functions/yay.fish
  '';

  # Copy completions
  fishCompletions = pkgs.runCommand "yay-fish-completions" { } ''
    mkdir -p $out/share/fish/vendor_completions.d
    cp ${../share/fish/completions}/yay.fish $out/share/fish/vendor_completions.d/
  '';

  # Build the Go file server
  yay-serve = pkgs.buildGoModule {
    pname = "yay-serve";
    version = "1.0.0";
    src = ../share/serve;
    vendorHash = null;
  };

  # Create main yay binary that correctly passes args to fish
  yayBin = pkgs.writeShellScriptBin "yay" ''
    FUNCTIONS_DIR=$(dirname $(dirname $0))/share/fish/functions

    # Create a temporary script to handle command execution
    TEMP_SCRIPT=$(mktemp -t yay-command.XXXXXX)

    # Write the fish commands to the script
    cat > $TEMP_SCRIPT << EOF
    #!/usr/bin/env fish
    set fish_function_path \$fish_function_path $FUNCTIONS_DIR
    source $FUNCTIONS_DIR/yay.fish
    yay_function $@
    EOF

    # Execute the script
    ${lib.getExe pkgs.fish} $TEMP_SCRIPT "$@"

    # Clean up
    rm $TEMP_SCRIPT
  '';
in
pkgs.symlinkJoin {
  name = "yay";
  paths = [
    yayBin
    fishFunctions
    fishCompletions
    yay-serve
  ];
  buildInputs = [ pkgs.makeWrapper ];

  # Make sure dependencies are in PATH
  postBuild = ''
    wrapProgram $out/bin/yay \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.fish
          pkgs.nh
          pkgs.jq
          pkgs.gzip
          pkgs.p7zip
          pkgs.unrar-free
          pkgs.bzip2
          pkgs.bzip3
          pkgs.zstd
          yay-serve
        ]
      }
  '';

  meta = with lib; {
    description = "A convenient wrapper around Nix commands with fish completions";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ "Tophc7" ];
  };
}
