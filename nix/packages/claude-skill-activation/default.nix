{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs,
}:

let
  # Build the npm package for the TypeScript script
  scriptPackage = buildNpmPackage {
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
      runHook postInstall
    '';
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

    # Copy the skill files (SKILL.md, references/, etc.)
    cp -r $src/* $out/share/claude/skills/skill-activation/

    # Create bin directory and executable wrapper
    mkdir -p $out/bin
    cat > $out/bin/claude-skill-activation <<EOF
#!${nodejs}/bin/node
require('${scriptPackage}/dist/skill-activation.js');
EOF
    chmod +x $out/bin/claude-skill-activation

    runHook postInstall
  '';

  meta = with lib; {
    description = "Skill activation plugin for Claude Code";
    mainProgram = "claude-skill-activation";
    license = licenses.mit;
    maintainers = [ maintainers.roman ];
  };
}
