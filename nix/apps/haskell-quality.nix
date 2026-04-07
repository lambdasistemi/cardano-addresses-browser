{lib}:

lib.mkCiApp {
  name = "cardano-addresses-browser-ci-haskell-quality";
  command = "just haskell-quality";
}
