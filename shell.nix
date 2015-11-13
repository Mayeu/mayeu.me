with (import <nixpkgs> {});

stdenv.mkDerivation rec {
   name = "mayeu.me";
   buildInputs = [jekyll nodejs python27Packages.pygments];
}
