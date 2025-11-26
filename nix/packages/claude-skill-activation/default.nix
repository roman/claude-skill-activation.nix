{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs,
  writeShellApplication,
  jq,
  gawk,
  coreutils,
}:

let
  # Build the npm package for the TypeScript script
  activationScript = buildNpmPackage {
    pname = "claude-skill-activation-script";
    version = "0.0.1";

    src = ../../../skill/scripts;

    npmDepsHash = "sha256-urAeUG7ApdqDB6MIEbke0McVlzN5uV86+v+mKBn0l3U=";

    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/dist
      # Create bin directory and executable wrapper
      mkdir -p $out/bin
      cat > $out/bin/claude-skill-activation <<EOF
#!${nodejs}/bin/node
require('$out/dist/skill-activation.js');
EOF
      chmod +x $out/bin/claude-skill-activation
      runHook postInstall
    '';
  };

  # Build the test script with proper dependencies
  testScript = writeShellApplication {
    name = "test-skill-activation";

    runtimeInputs = [
      jq         # JSON parsing
      gawk       # awk for text processing
      coreutils  # basename, cat, etc.
    ];

    text =
      let
        scriptContent = builtins.readFile ../../../skill/scripts/test-skill-activation.sh;
        # Remove shebang and set -euo pipefail as writeShellApplication adds its own
        cleanedScript = builtins.replaceStrings
          ["#!/usr/bin/env bash\n\nset -euo pipefail\n\n"]
          [""]
          scriptContent;
      in
        cleanedScript;
  };
in
stdenv.mkDerivation {
  pname = "claude-skill-activation";
  version = "0.0.1";

  src = ../../../skill;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create output directory structure for skills
    mkdir -p $out/share/claude/skills/skill-activation

    # Copy the skill files (SKILL.md, references/, etc.), excluding scripts temporarily
    shopt -s extglob
    cp -r $src/!(scripts) $out/share/claude/skills/skill-activation/


    # Install both compiled scripts to the scripts folder in the skill output
    mkdir -p $out/share/claude/skills/skill-activation/scripts

    # Copy the main TypeScript script wrapper
    cp ${activationScript}/bin/claude-skill-activation $out/share/claude/skills/skill-activation/scripts/claude-skill-activation

    # Copy the compiled test script (with all dependencies wrapped by Nix)
    cp ${testScript}/bin/test-skill-activation $out/share/claude/skills/skill-activation/scripts/test-skill-activation

    # Also create bin/ directory for direct binary access (used by home-manager hooks)
    mkdir -p $out/bin
    ln -s $out/share/claude/skills/skill-activation/scripts/claude-skill-activation $out/bin/claude-skill-activation
    ln -s $out/share/claude/skills/skill-activation/scripts/test-skill-activation $out/bin/test-skill-activation

    runHook postInstall
  '';

  meta = with lib; {
    description = "Skill activation plugin for Claude Code";
    mainProgram = "claude-skill-activation";
    license = licenses.mit;
    maintainers = [ maintainers.roman ];
  };
}
