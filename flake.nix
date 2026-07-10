{
  description = "m2c";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-26.05";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    m2c = {
      url = "github:matt-kempster/m2c";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-utils
    , flake-compat
    , m2c
    , pyproject-nix
    }:
    let
      outputs = flake-utils.lib.eachDefaultSystem
        (system:
          let

            pkgs = import nixpkgs {
              inherit system;
            };

            # Update script for this repo.
            update-m2c = pkgs.writeShellScriptBin "update-m2c" ''
              ${pkgs.nix}/bin/nix flake update m2c \
                  --extra-experimental-features nix-command \
                  --extra-experimental-features flakes
            '';
            # pyproject.nix parses m2c's PEP 621 [project] metadata at eval
            # time and resolves its dependencies from nixpkgs, so dependency
            # changes upstream are picked up automatically on update.
            # (poetry2nix used to fill this role but is unmaintained and does
            # not understand [project] metadata, which m2c switched to.)
            m2c =
              let
                project = pyproject-nix.lib.project.loadPyproject {
                  projectRoot = inputs.m2c;
                };
                python = pkgs.python3.withPackages
                  (project.renderers.withPackages { python = pkgs.python3; });
              in
              pkgs.writeShellScriptBin "m2c.py" ''
                exec ${python}/bin/python ${inputs.m2c}/m2c.py "$@"
              '';
          in
          rec
          {
            legacyPackages = { };

            packages = flake-utils.lib.flattenTree
              {
                inherit m2c update-m2c;
              };
            checks = {
              # Actually run m2c so updates that break it (new dependencies,
              # syntax requiring a newer python, ...) fail the check.
              m2c-runs = pkgs.runCommand "m2c-runs" { } ''
                ${packages.m2c}/bin/m2c.py --help > $out
              '';
            };
          });
    in
    outputs //
    {
      overlays.default = final: _prev: {
        m2c = outputs.packages.${final.system}.m2c;
      };
    };




}
