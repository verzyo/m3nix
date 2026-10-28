{
  inputs = {
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      flake = false;
    };

    themes = {
      url = "github:InioX/matugen-themes";
      flake = false;
    };

    community-templates = {
      url = "github:noctalia-dev/community-templates";
      flake = false;
    };

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    treefmt,
    nixpkgs,
    self,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    homeModules = rec {
      m3nix = import ./nix/home.nix {inherit (inputs) dms themes community-templates;};
      default = m3nix;
    };

    formatter.${system} =
      (treefmt.lib.evalModule pkgs {
        imports = [./nix/formatter.nix];
      }).config.build.wrapper;
  };
}
