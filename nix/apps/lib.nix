{pkgs, playwrightBrowsers, repoRoot}:

let
  commonInputs = [
    pkgs.bash
    pkgs.cabal-install
    pkgs.diffutils
    pkgs.esbuild
    pkgs.fourmolu
    pkgs.hlint
    pkgs.just
    pkgs.nix
    pkgs.nodejs_22
    pkgs.playwright-test
    pkgs.purs
    pkgs.purescript-language-server
    pkgs.purs-backend-es
    pkgs.purs-tidy
    pkgs.spago
  ];

  mkCiApp =
    {
      name,
      command,
      runtimeInputs ? commonInputs,
      withPlaywright ? false,
    }:
    let
      script = pkgs.writeShellApplication {
        inherit name runtimeInputs;
        text = ''
          export NIX_CONFIG="experimental-features = nix-command flakes"
          ${if withPlaywright then ''
            export PLAYWRIGHT_BROWSERS_PATH="${playwrightBrowsers}"
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
          '' else ""}
          ${command}
        '';
      };
    in
    {
      type = "app";
      program = "${script}/bin/${name}";
      meta.description = name;
    };
in
{
  inherit commonInputs mkCiApp;
}
