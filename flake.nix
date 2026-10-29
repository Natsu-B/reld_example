{
  description = "Reproducible x86-64 Linux development shell for reld examples";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          gcc
          binutils
          gnumake
          file
          gdb
          strace
          util-linux
          diffutils
          coreutils

          rustc
          cargo
          rustfmt
          git
        ];

        hardeningDisable = [ "all" ];

        GLIBC_STATIC_LIB_DIR = "${pkgs.glibc.static}/lib";
        GLIBC_CRT_DIR = "${pkgs.glibc}/lib";
        GLIBC_INCLUDE_DIR = "${pkgs.glibc.dev}/include";

        shellHook = ''
          export LIBGCC_DIR="$(dirname "$(gcc -print-libgcc-file-name)")"
        '';
      };
    };
}
