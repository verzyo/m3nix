{
  inputs = {
    # source of both the built-in templates and the noctalia-theme renderer, so they always match
    noctalia = {
      url = "github:noctalia-dev/noctalia";
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

    # only used by the checks
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    treefmt,
    nixpkgs,
    home-manager,
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

    packages.${system}.noctalia-theme = pkgs.callPackage ./nix/noctalia-theme/package.nix {
      src = inputs.noctalia;
    };

    checks.${system} = {
      inherit (self.packages.${system}) noctalia-theme;
      render-all = import ./nix/check.nix {
        inherit pkgs home-manager;
        homeModule = self.homeModules.default;
      };
    };

    formatter.${system} =
      (treefmt.lib.evalModule pkgs {
        imports = [./nix/formatter.nix];
      }).config.build.wrapper;
  };
}
