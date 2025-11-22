{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    nixDir.url = "github:roman/nixDir/v3";

    systems.url = "github:nix-systems/default";
    systems.flake = false;
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
	inputs.devenv.flakeModule
	inputs.nixDir.flakeModule
      ];

      nixDir = {
	enable = true;
	root = ./.;
      };
    };
}
