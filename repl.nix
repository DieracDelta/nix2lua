let
  flake = builtins.getFlake (toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs {system = "x86_64-linux"; };
in
  {
    pkgs = pkgs; 
    flake = flake;
    dsl = flake.DSL;

  }
