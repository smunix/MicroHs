{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    nix-filter.url = "github:numtide/nix-filter";
    nix-utils.url = "github:smunix/nix-utils";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys =
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... }@inputs:
    with inputs.nix-filter.lib;
    with inputs.nix-utils.lib;
    let forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hpkgs = fast pkgs.haskell.packages.ghc98 [{
            modifiers = with pkgs.haskell.lib; [
              doCheck
              doHaddock
              disableLibraryProfiling
            ];
            extension = hf: hp:
              with hf; {
                hpack = hp.hpack_0_36_0;
                MicroHs =
                  callCabal2nix "MicroHs" (filter { root = inputs.self; }) { };
              };
          }];
        in {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [{
              packages = with hpkgs;
                with pkgs; [
                  cracklib
                  git
                  # hpack
                  fourmolu
                  (ghcWithPackages (p:
                    with p; [
                      haskell-language-server
                      hpack
                      implicit-hie
                      MicroHs
                    ]))
                ];

              enterShell = with pkgs; ''
                ${hello}/bin/hello
                gen-hie --cabal &> hie.yaml
                ${fortune}/bin/fortune | ${ponysay}/bin/ponysay
                git --version
                hpack --version
              '';

              processes.run.exec = "hello";

              pre-commit.hooks = {
                # fourmolu.enable = true;
                nixfmt.enable = true;
                stylish-haskell.enable = true;
              };
            }];
          };
        });
    };
}
