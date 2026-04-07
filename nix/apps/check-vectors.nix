{lib}:

lib.mkCiApp {
  name = "cardano-addresses-browser-ci-check-vectors";
  command = "just check-vectors";
}
