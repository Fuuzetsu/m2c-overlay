{
  description = "m2c";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "22.11";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
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
    , poetry2nix
    }:
    let
      outputs = flake-utils.lib.eachDefaultSystem
        (system:
          let

            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                inputs.poetry2nix.outputs.overlay
              ];
            };

            # Update script for this repo.
            update-m2c = pkgs.writeShellScriptBin "update-m2c" ''
              ${pkgs.nix}/bin/nix flake lock --update-input m2c \
                  --extra-experimental-features nix-command \
                  --extra-experimental-features flakes
            '';
            m2c =
              let
                m2c = pkgs.poetry2nix.mkPoetryApplication {
                  projectDir = inputs.m2c;
                  python = pkgs.python3;
                  preferWheels = true;
                };
              in
              pkgs.writeShellScriptBin "m2c.py" ''
                ${m2c.dependencyEnv}/bin/python ${inputs.m2c}/m2c.py "$@"
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
              m2c-builds = packages.m2c;
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
