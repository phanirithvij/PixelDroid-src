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
      signScript = pkgs.writeShellScriptBin "sign-apk" ''
        mkdir -p build
        pushd build
        if [ ! -f release.keystore ]; then
          echo "Generating new release.keystore..."
          ${pkgs.jre}/bin/keytool -genkey -v -keystore release.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" -storepass android -keypass android
        fi

        APK_PATHS=$(find -L ../result -name "*.apk")
        if [ -z "$APK_PATHS" ]; then
          echo "No APKs found in result/. Did you run 'nix build'?"
          exit 1
        fi

        for APK_PATH in $APK_PATHS; do
          BASE_NAME=$(basename "$APK_PATH")
          # Remove -unsigned from the filename if present
          SIGNED_NAME="signed-''${BASE_NAME/-unsigned/}"

          echo "Signing $SIGNED_NAME..."
          cp "$APK_PATH" "$SIGNED_NAME"
          chmod +w "$SIGNED_NAME"

          ${pkgs.apksigner}/bin/apksigner sign --ks release.keystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android "$SIGNED_NAME"
          ${pkgs.apksigner}/bin/apksigner verify "$SIGNED_NAME"
        done

        echo "Successfully signed all APKs!"
        popd
      '';
    in
    {
      packages.${system}.default = pkgs.callPackage ./package.nix { };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          jre
          android-tools
          signScript
        ];
      };
    };
}
