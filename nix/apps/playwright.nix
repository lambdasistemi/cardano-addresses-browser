{lib}:

lib.mkCiApp {
  name = "cardano-addresses-browser-ci-playwright";
  command = "just test-playwright";
  withPlaywright = true;
}
