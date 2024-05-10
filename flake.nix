{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (final: prev: {
            yubioath-flutter = prev.yubioath-flutter.overrideAttrs (old: {
              version = "6.4.0-dev";
              src = pkgs.lib.fileset.toSource {
                root = ./.;
                fileset = ./.;
              };
            });
          })
        ];
      };

    in
    {
      devShell.x86_64-linux =
        pkgs.mkShell {
          shellHook = ''
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.pcsclite ]}:$LD_LIBRARY_PATH
          '';

          buildInputs = with pkgs; [
            yubioath-flutter
            pcsclite
          ];
        };
    };
}
