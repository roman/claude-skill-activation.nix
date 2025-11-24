{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage {
  pname = "claude-skill-activation";
  version = "0.0.1";

  src = ../../../skill/scripts;

  npmDepsHash = "sha256-urAeUG7ApdqDB6MIEbke0McVlzN5uV86+v+mKBn0l3U=";

  # Compile TypeScript to JavaScript
  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  # Install the compiled output and create executable wrapper
  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        cp -r dist $out/dist

        # Create executable wrapper that runs the compiled JS with Node
        cat > $out/bin/claude-skill-activation <<EOF
    #!${nodejs}/bin/node
    require('$out/dist/skill-activation.js');
    EOF
        chmod +x $out/bin/claude-skill-activation

        runHook postInstall
  '';

  meta = with lib; {
    description = "hooks for Claude Code skill auto-activation";
    mainProgram = "claude-skill-activation";
    license = licenses.mit;
    maintainers = [ maintainers.roman ];
  };
}
