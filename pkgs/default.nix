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
    mkdir -p $out/share/fish/completions
    cp ${../share/fish/completions}/yay.fish $out/share/fish/completions/
  '';

  # Create main yay binary that uses fish's function path
  yayBin = pkgs.writeShellScriptBin "yay" ''
    FUNCTIONS_DIR=$(dirname $(dirname $0))/share/fish/functions
    exec ${lib.getExe pkgs.fish} -c "set fish_function_path \$fish_function_path $FUNCTIONS_DIR; source $FUNCTIONS_DIR/yay.fish; yay_function $@"
  '';
in
pkgs.symlinkJoin {
  name = "yay";
  paths = [
    yayBin
    fishFunctions
    fishCompletions
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