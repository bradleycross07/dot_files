{
  description = "nixos config";

  inputs = {
    # stable NixOS release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # unstable packages to select newer version
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # spicetify
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, spicetify-nix, ... }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit nixpkgs-unstable spicetify-nix;

	  pkgs-unstable = import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
	};

        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          spicetify-nix.nixosModules.spicetify
        ];
      };
    };
}
