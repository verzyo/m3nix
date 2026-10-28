{
  inputs = {
    # pinned to the tag nixpkgs builds pkgs.noctalia from, so built-in templates match the renderer
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.3.0";
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
      m3nix = import ./nix/home.nix {inherit (inputs) noctalia community-templates;};
      default = m3nix;
    };

    formatter.${system} =
      (treefmt.lib.evalModule pkgs {
        imports = [./nix/formatter.nix];
      }).config.build.wrapper;
  };
}
