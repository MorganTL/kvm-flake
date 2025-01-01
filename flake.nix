{
  # modified from the flake that was provided by discord user Kranzes on jetkvm "open-source" channel
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    { nixpkgs, treefmt-nix, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };

      jetkvm_app = pkgs.pkgsCross.armv7l-hf-multiplatform.buildGoModule rec {
        pname = "jetkvm_app";
        version = "0.0.0"; # Not worth parsing from Makefile?

        src = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = (
            pkgs.lib.fileset.unions [
              (pkgs.lib.fileset.fileFilter (f: f.hasExt "go") ./.)
              ./go.mod
              ./go.sum
              ./resource
            ]
          );
        };

        postPatch = "cp -r --no-preserve=mode ${ui} static"; # The UI is expected to be there

        vendorHash = "sha256-+tn+0qK0l8hxZ5+2lVX/duPGibsSGYeilwV2EtspI3I="; # Needs to be updated whenever go.{mod,sum} are changed

        ldflags = [
          "-s"
          "-w"
          "-X kvm.builtAppVersion=${version}"
        ];

        env.CGO_ENABLED = 0;

        postInstall = "mv $out/bin/cmd $out/bin/jetkvm_app"; # Rename
      };

      packageJSON = (pkgs.lib.importJSON ./ui/package.json);
      ui = pkgs.buildNpmPackage rec {
        pname = packageJSON.name;
        version = packageJSON.version;
        # inherit (packageJSON) version;

        src = ./ui;

        # Set output directory to $out unconditionally
        postPatch = ''
          substituteInPlace vite.config.ts \
            --replace-fail "../static" "$out" \
            --replace-fail "dist" "$out"
        '';

        npmDeps = pkgs.importNpmLock { npmRoot = src; };

        npmConfigHook = pkgs.importNpmLock.npmConfigHook;

        dontNpmInstall = true;
      };
    in
    {
      formatter.x86_64-linux = treefmt-nix.lib.mkWrapper nixpkgs.legacyPackages.x86_64-linux {
        projectRootFile = "flake.nix";
        # see for more options https://flake.parts/options/treefmt-nix
        programs.nixfmt.enable = true;
      };

      packages.x86_64-linux = {
        default = jetkvm_app;
        jetkvm_app = jetkvm_app;
        ui = ui;
      };
    };

}
