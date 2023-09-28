{
  description = "A very basic flake";

  inputs = {
    oxalica.url = "github:oxalica/rust-overlay";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  };

  outputs = { self, nixpkgs, oxalica }: rec {
    frequency = let
      pkgs = import nixpkgs { system = "x86_64-linux" ; overlays = [ oxalica.overlays.default ]; };

      # this should follow ./rust-toolchain.toml
      customRust = pkgs.rust-bin.nightly."2023-05-22".default.override({
        targets = [ "wasm32-unknown-unknown" ];
        extensions = [ "clippy" "rust-docs" "rustfmt" "rustc-dev" "rustc" ];
      });

      rustPlatform = pkgs.makeRustPlatform {
        cargo = customRust;
        rustc = customRust;
      };
    in
      rustPlatform.buildRustPackage rec {
        pname = "frequency";
        version = "1.7.4";

        src = ./.;

        nativeBuildInputs = with pkgs; [
          clang
          protobuf
          llvmPackages.libclang.lib
          git
        ];

        doCheck = false;

        # whole build should be extracted to a function
        # so that different features could generate
        # different binaries
        buildFeatures = [
          # "frequency"
          # "frequency-rococo-testnet"
          # "frequency-rococo-local"
          "frequency-no-relay"
          # "frequency-lint-check"
        ];

        SKIP_WASM_BUILD = true;

        # may help to avoid error raised
        # somewhere at this line: https://github.com/paritytech/substrate/blob/033d4e86cc7eff0066cd376b9375f815761d653c/utils/wasm-builder/src/wasm_project.rs#L97
        # WASM_BUILD_WORKSPACE_HINT = "/build/cargo-vendor-dir";
        LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.lib.getVersion pkgs.clang}/include";

        cargoLock =  {
          lockFile = ./Cargo.lock;
          outputHashes = {
            "binary-merkle-tree-4.0.0-dev" = "sha256-sM0e0/VLCIuebzjsHOF0jJZYumo4CSwlrWc/NN8ubvQ=";
            "cumulus-client-cli-0.1.0" = "sha256-nFC1+sEbXm89Vc+Fqz9uzJCfFTqqVGCZP4jR3TqBjDY=";
            "kusama-runtime-0.9.43" = "sha256-KYmMMcQMkkXfWj5ZTr549a/8ftELKo0PUvCrmRMiDaE=";
          };
        };
      };

    packages.x86_64-linux.default = frequency;

  };
}
