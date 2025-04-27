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

  # Create main yay binary that ensures fish is available
  yayBin = pkgs.writeShellScriptBin "yay" ''
    exec ${pkgs.fish}/bin/fish -c "yay $*"
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
