{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, ... }@inputs:
    let
      system = "x86_64-linux";
      inherit (inputs.nixpkgs.legacyPackages.${system}) lib;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          # TODO warn
          allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "android-sdk-build-tools"
              "android-sdk-cmdline-tools"
              "android-sdk-platform-tools"
              "android-sdk-platforms"
              "android-sdk-tools"
              "build-tools"
              "cmake"
              "cmdline-tools"
              "platform-tools"
              "platforms"
              "tools"
            ];
          android_sdk.accept_license = true;
        };
      };
    in
    {
      packages.${system}.default = pkgs.callPackage ./package.nix { };
    };
}
