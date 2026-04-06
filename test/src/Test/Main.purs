module Test.Main where

import Prelude

import Cardano.Address.Derivation (Role(..), derivePipeline)
import Cardano.Address.Inspect (eitherInspectAddress)
import Cardano.Address.ScriptHash (hashNativeScriptHex)
import Data.Either (Either(..))
import Data.Traversable (traverse_)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Partial.Unsafe (unsafeCrashWith)
import Test.Vectors (DerivationVector, InspectionVector, ScriptHashVector, derivationVectors, inspectionVectors, scriptHashVectors)

main :: Effect Unit
main = launchAff_ do
  traverse_ assertDerivationVector derivationVectors
  liftEffect (traverse_ assertInspectionVector inspectionVectors)
  liftEffect (traverse_ assertScriptHashVector scriptHashVectors)

assertDerivationVector :: DerivationVector -> Aff Unit
assertDerivationVector vector = do
  actual <- derivePipeline vector.mnemonic vector.accountIndex (parseRole vector.role) vector.addressIndex
  when (actual /= vector.expected) do
    liftEffect $
      throw ("Derivation vector mismatch: " <> vector.label)

assertInspectionVector :: InspectionVector -> Effect Unit
assertInspectionVector vector =
  case eitherInspectAddress vector.address of
    Right actual | actual == vector.expected -> pure unit
    Right _ ->
      throw ("Inspection vector mismatch: " <> vector.label)
    Left err ->
      throw ("Inspection unexpectedly failed for " <> vector.label <> ": " <> err)

parseRole :: String -> Role
parseRole = case _ of
  "external" -> UTxOExternal
  "internal" -> UTxOInternal
  "stake" -> Stake
  other -> unsafeCrashWith ("Unsupported test role: " <> other)

assertScriptHashVector :: ScriptHashVector -> Effect Unit
assertScriptHashVector vector =
  case hashNativeScriptHex vector.scriptCborHex of
    Right actual | actual == vector.expected -> pure unit
    Right _ ->
      throw ("Script hash vector mismatch: " <> vector.label)
    Left err ->
      throw ("Script hash unexpectedly failed for " <> vector.label <> ": " <> err)
