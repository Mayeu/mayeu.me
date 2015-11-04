with (import <nixpkgs> {});

stdenv.mkDerivation rec {
   name = "mayeu.me";
   buildInputs = [jekyll python34Packages.pygments];
}
