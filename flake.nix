{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
      decorate-package = pkgs:
        let transitive-dependencies = p:
          let ipkgs = p.idrisLibraries pkgs.idris2Packages ++ p.idrxLibraries;
          in nixpkgs.lib.unique
            (ipkgs ++ builtins.concatMap transitive-dependencies ipkgs);
        in p: p // rec {
          idrisLibrariesClosure = transitive-dependencies p;
          repl = pkgs.writeShellScriptBin "${p.ipkgName}-repl" ''
            export IDRIS2_PACKAGE_PATH=${
              builtins.concatStringsSep ":"
                (builtins.map
                  (dep: "${dep.library {}}/lib/idris2-${pkgs.idris2.version}")
                  ([p] ++ idrisLibrariesClosure))}
            export CPPFLAGS="${
              builtins.concatStringsSep " "
                (builtins.map (i: "-I${i}/include") p.buildInputs)}"
            LIBPATH+="${
              builtins.concatStringsSep ":"
                (builtins.map (l: "${l}/lib") p.runtimeInputs)}"
            export LIBRARY_PATH=$LIBPATH
            export LD_LIBRARY_PATH=$LIBPATH
            PACKAGE_DEPENDENCIES="${
              builtins.concatStringsSep " "
                (builtins.map (dep: "-p ${dep.ipkgName}") (transitive-dependencies p))}"
            set -x
            exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
                ${pkgs.idris2}/bin/idris2 -p "${p.ipkgName}" $PACKAGE_DEPENDENCIES "$@"
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
              inherit buildInputs runtimeInputs ipkgName idrisLibraries version;
            })
          )
          nixpkgs.outputs.legacyPackages;
      };
    };
}
