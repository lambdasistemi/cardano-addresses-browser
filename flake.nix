{
  description = "cardano-address-browser — Browser-based Cardano address toolkit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, purescript-overlay }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ purescript-overlay.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.purs
              pkgs.spago
              pkgs.purs-tidy
              pkgs.purs-backend-es
              pkgs.purescript-language-server
              pkgs.esbuild
              pkgs.nodejs_22
              pkgs.just
            ];
          };
        });
    };
}
