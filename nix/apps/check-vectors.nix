{lib, testVectorsPath}:

lib.mkCiApp {
  name = "cardano-addresses-browser-ci-check-vectors";
  command = ''
    diff -u test-vectors/vectors.json ${testVectorsPath}/vectors.json
  '';
}
