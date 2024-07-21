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

        libraries = with pkgs; [
          webkitgtk
          gtk3
          cairo
          gdk-pixbuf
          fuse3
          pcre2
          om4
          libxkbcommon
          glib
          dbus
          sqlite
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi
          xorg.libX11
          openssl_3
          librsvg
          vulkan-headers
          vulkan-loader
          wayland
          llvmPackages_15.libllvm

          gst_all_1.gstreamer
          # Common plugins like "filesrc" to combine within e.g. gst-launch
          gst_all_1.gst-plugins-base
          # Specialized plugins separated by quality
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-ugly
          gst_all_1.gst-plugins-rs
          # Plugins to reuse ffmpeg to play almost every video format
          gst_all_1.gst-libav
          # Support the Video Audio (Hardware) Acceleration API
          gst_all_1.gst-vaapi
        ];

        packages = with pkgs; [
          curl
          protobuf
          wget
          pcre2
          rustup
          wayland
          pkg-config
          dbus
          openssl_3
          fuse3
          glib
          om4
          gtk3
          vulkan-headers
          vulkan-loader
          sqlite
          libsoup
          sass
          librsvg
          (rust-bin.beta.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "rustc" ];
          })

          gst_all_1.gstreamer
          # Common plugins like "filesrc" to combine within e.g. gst-launch
          gst_all_1.gst-plugins-base
          # Specialized plugins separated by quality
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-ugly
          gst_all_1.gst-plugins-rs
          # Plugins to reuse ffmpeg to play almost every video format
          gst_all_1.gst-libav
          # Support the Video Audio (Hardware) Acceleration API
          gst_all_1.gst-vaapi
        ];
      in {
        devShell = pkgs.mkShell {
          buildInputs = packages;

          shellHook = ''
            export PATH="$PATH":"$HOME/.cargo/bin"
            # export LD_LIBRARY_PATH={
            #  pkgs.lib.makeLibraryPath libraries
            # }:$LD_LIBRARY_PATH

            export LD_LIBRARY_PATH="$(pwd)/build/linux/x64/debug/bundle/lib:$(pwd)/build/linux/x64/release/bundle/lib:$LD_LIBRARY_PATH"

          '';
        };
      });
}
