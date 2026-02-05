{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
      decorate-package = pkgs:
        let transitive-dependencies = upstream: p:
          let deps = p.idrisLibraries upstream ++ p.idrxLibraries;
          in nixpkgs.lib.unique (deps ++ builtins.concatMap (transitive-dependencies upstream) deps);
        in p: p // rec {
          idris2 = pkgs.idris2.withPackages (upstream: transitive-dependencies upstream p);
          repl = pkgs.writeShellScriptBin "${p.ipkgName}-repl" ''
            export CPPFLAGS="${
              builtins.concatStringsSep " "
                (builtins.map (i: "-I${i}/include") p.buildInputs)}"
            LIBPATH+="${
              builtins.concatStringsSep ":"
                (builtins.map (l: "${l}/lib") p.runtimeInputs)}"
            export LIBRARY_PATH=$LIBPATH
            export LD_LIBRARY_PATH=$LIBPATH
            exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
                ${idris2}/bin/idris2 --repl "${p.ipkgName}.ipkg"
            '';
        };
    in
    {
      systems = builtins.attrNames nixpkgs.outputs.legacyPackages;
      importFromGitHub = {owner, repo, rev, hash ? ""}: {
        packages = builtins.mapAttrs
          (system: pkgs: decorate-package pkgs
            (import (pkgs.fetchFromGitHub { inherit owner repo rev hash; }){ idrx = self; }))
          nixpkgs.outputs.legacyPackages;
      };
      importFromSrc = {src, ipkgName, idrisLibraries ? (_: []), idrxLibraries ? [], version ? "", buildInputs ? [], runtimeInputs ? []}: {
        packages = builtins.mapAttrs
          (system: pkgs: decorate-package pkgs
            (pkgs.idris2Packages.buildIdris {
              inherit src ipkgName version;
              idrisLibraries = idrisLibraries pkgs.idris2Packages
                ++ builtins.map (i: i.packages.${system}.library {}) idrxLibraries;
              nativeBuildInputs = buildInputs;
              buildInputs = runtimeInputs;
            } // {
              inherit buildInputs runtimeInputs ipkgName idrisLibraries idrxLibraries version;
            })
          )
          nixpkgs.outputs.legacyPackages;
      };
    };
}
