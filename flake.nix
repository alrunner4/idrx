{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
      transitive-dependencies = p: nixpkgs.lib.unique
        (p.idrisLibraries ++ builtins.concatMap transitive-dependencies p.idrisLibraries);
      decorate-package = pkgs: p: p // rec {
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
          LIBPATH+=":${
            builtins.concatStringsSep ":"
              (builtins.map (l: "${l}/lib") p.runtimeInputs)}"
          export LIBRARY_PATH=$LIBPATH
          export LD_LIBRARY_PATH=$LIBPATH
          ${pkgs.idris2}/bin/idris2 --list-packages
          exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
              ${pkgs.idris2}/bin/idris2 "$@"
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
      importFromSrc = {src, ipkgName, idrisLibraries ? [], version ? "", buildInputs ? [], runtimeInputs ? []}: {
        packages = builtins.mapAttrs
          (system: pkgs: decorate-package pkgs
            (pkgs.idris2Packages.buildIdris {
              inherit src ipkgName idrisLibraries version;
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
