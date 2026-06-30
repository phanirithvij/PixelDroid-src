{
  lib,
  stdenv,
  fetchFromGitLab,

  gradle_9,
  androidenv,
  jdk21_headless,
}:
let
  gradle = gradle_9.override { java = jdk21_headless; };

  androidComposition = androidenv.composeAndroidPackages {
    buildToolsVersions = [ "36.0.0" ];
    platformVersions = [
      "36"
      "37"
    ];
    abiVersions = [
      "x86_64"
      "arm64-v8a"
    ];
    includeNDK = false; # TODO check if we need ndk later
    includeSystemImages = false;
    includeEmulator = false;
  };

  androidSdk = androidComposition.androidsdk;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "pixeldroid";
  version = "1.0.beta42";
  src = fetchFromGitLab {
    domain = "gitlab.shinice.net";
    owner = "pixeldroid";
    repo = "PixelDroid";
    tag = finalAttrs.version;
    hash = "sha256-q0kIaQyGY8Icjfe6JcgWXSBN4CyhQ0v9njCe7FgSF94=";
    fetchSubmodules = true;
  };

  patches = [
    # To access local pixelfed servers for testing
    ./0001-allow-insecure-pixelfed-server-access.patch
  ];

  nativeBuildInputs = [
    gradle
  ];

  # TODO no icon?

  postPatch = ''
    find . -type f -name "build.gradle" -exec sed -i \
      -e 's/VERSION_17/VERSION_21/g' \
      -e 's/jvmTarget = .17./jvmTarget = '"'"'21'"'"'/g' \
      -e 's/jvmToolchain(17)/jvmToolchain(21)/g' {} +
  '';

  preBuild = ''
    export ANDROID_USER_HOME=$TMPDIR/.android
  '';

  env = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  };

  gradleUpdateTask = "assembleRelease";

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  # this is required for using mitm-cache on Darwin
  __darwinAllowLocalNetworking = true;

  gradleFlags = [
    "-Dfile.encoding=utf-8"
    "-Dorg.gradle.configuration-cache=false"
    "-Pandroid.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/36.0.0/aapt2"
  ];

  gradleBuildTask = "assembleRelease";

  doCheck = false;

  installPhase = ''
    mkdir -p $out
    cp app/build/outputs/apk/release/*.apk $out/
  '';

  meta.sourceProvenance = with lib.sourceTypes; [
    fromSource
    binaryBytecode # mitm cache
  ];
})
