{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.WELCOME = "Take a look at readme.md";

  # https://devenv.sh/languages/
  languages.java.jdk.package = pkgs.jdk21_headless;
  languages.scala.package    = pkgs.scala_3;
  languages.scala.sbt.enable = true;
  languages.scala.enable     = true;

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
  ];

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo $WELCOME
  '';

  enterShell = ''
    hello
  '';

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;
  
  # https://devenv.sh/integrations/dotenv/
  # dotenv.enable = true;

  # https://devenv.sh/integrations/codespaces-devcontainer/
  devcontainer.enable = true;

  # https://devenv.sh/integrations/difftastic/
  # difftastic.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
