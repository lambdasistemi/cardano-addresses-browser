module Test.Main where

import Prelude

import Cardano.Address (base58)
import Cardano.Address.Bootstrap as Bootstrap
import Cardano.Address.Derivation (Role(..), derivePipeline)
import Cardano.Address.Inspect (eitherInspectAddress)
import Cardano.Address.Script (analyzeNativeScriptHex, analyzeNativeScriptJson, analyzeScriptTemplateJson)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Traversable (traverse_)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Partial.Unsafe (unsafeCrashWith)
import Test.Vectors (BootstrapVector, DerivationVector, InspectionVector, ScriptHashVector, ScriptTemplateVector, bootstrapVectors, derivationVectors, inspectionVectors, scriptHashVectors, scriptTemplateVectors)

main :: Effect Unit
main = launchAff_ do
  traverse_ assertDerivationVector derivationVectors
  liftEffect (traverse_ assertInspectionVector inspectionVectors)
  traverse_ assertBootstrapVector bootstrapVectors
  liftEffect (traverse_ assertScriptHashVector scriptHashVectors)
  liftEffect (traverse_ assertScriptTemplateVector scriptTemplateVectors)

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

assertBootstrapVector :: BootstrapVector -> Aff Unit
assertBootstrapVector vector = do
  addressXPub <- liftEffect (parseXPub vector.addressXPubBech32)
  actual <- case vector.style of
    "Icarus" ->
      pure (Bootstrap.constructIcarusAddress (parseLegacyNetwork vector.protocolMagic) addressXPub)
    "Byron" -> do
      rootXPub <- case vector.rootXPubBech32 of
        Just value -> liftEffect (parseXPub value)
        Nothing -> liftEffect (throw ("Missing root xpub for Byron vector: " <> vector.label))
      derivationPath <- case vector.derivationPath of
        Just value -> pure value
        Nothing -> liftEffect (throw ("Missing derivation path for Byron vector: " <> vector.label))
      Bootstrap.constructByronAddress
        (parseLegacyNetwork vector.protocolMagic)
        addressXPub
        rootXPub
        derivationPath
    other ->
      liftEffect (throw ("Unsupported bootstrap style: " <> other))

  when (base58 actual /= vector.expectedAddressBase58) do
    liftEffect (throw ("Bootstrap vector mismatch: " <> vector.label))

parseXPub :: String -> Effect Uint8Array
parseXPub value = case Bootstrap.parseBootstrapXPub value of
  Right parsed -> pure parsed
  Left err -> throw err

parseLegacyNetwork :: Int -> Bootstrap.LegacyNetwork
parseLegacyNetwork = case _ of
  764824073 -> Bootstrap.LegacyMainnet
  633343913 -> Bootstrap.LegacyStaging
  1097911063 -> Bootstrap.LegacyTestnet
  2 -> Bootstrap.LegacyPreview
  1 -> Bootstrap.LegacyPreprod
  magic -> Bootstrap.LegacyCustom magic

assertScriptHashVector :: ScriptHashVector -> Effect Unit
assertScriptHashVector vector = do
  case analyzeNativeScriptHex vector.scriptCborHex of
    Right actual | actual == vector.expected -> pure unit
    Right _ ->
      throw ("Script hash vector mismatch: " <> vector.label)
    Left err ->
      throw ("Script hash unexpectedly failed for " <> vector.label <> ": " <> err)

  case analyzeNativeScriptJson vector.scriptJson of
    Right actual | actual == vector.expected -> pure unit
    Right _ ->
      throw ("Script JSON vector mismatch: " <> vector.label)
    Left err ->
      throw ("Script JSON unexpectedly failed for " <> vector.label <> ": " <> err)

assertScriptTemplateVector :: ScriptTemplateVector -> Effect Unit
assertScriptTemplateVector vector =
  case analyzeScriptTemplateJson vector.templateJson of
    Right actual | actual == vector.expected -> pure unit
    Right _ ->
      throw ("ScriptTemplate vector mismatch: " <> vector.label)
    Left err ->
      throw ("ScriptTemplate unexpectedly failed for " <> vector.label <> ": " <> err)
