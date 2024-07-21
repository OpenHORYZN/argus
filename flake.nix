{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };


        packages = with pkgs; [
          curl
          protobuf
          wget
          rustup
          wayland
          pkg-config
          dbus
          openssl_3
          fuse3
          glib
          gtk3
          clang
          libclang
          vulkan-headers
          vulkan-loader
          sqlite
          libsoup
          sass
          librsvg
          (rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "rustc" ];
          })
        ];
      in {
        devShell = pkgs.mkShell {
          buildInputs = packages;

          shellHook = ''
            export PATH="$PATH":"$HOME/.cargo/bin"

            export LD_LIBRARY_PATH="$(pwd)/build/linux/x64/debug/bundle/lib:$(pwd)/build/linux/x64/release/bundle/lib:$LD_LIBRARY_PATH"

          '';
        };
      });
}
