module Cardano.Address.Signing
  ( PayloadMode(..)
  , SignResult
  , payloadModeLabel
  , signPayload
  , verifySignature
  ) where

import Prelude

import Cardano.Address.Bech32 as Bech32
import Cardano.Address.Hex as Hex
import Cardano.Bytes (byteLength)
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))

data PayloadMode
  = PayloadText
  | PayloadHex

derive instance eqPayloadMode :: Eq PayloadMode

type SignResult =
  { payloadHex :: String
  , signatureHex :: String
  , verificationKeyBech32 :: String
  }

foreign import encodeUtf8Impl :: String -> Uint8Array

foreign import signSerializedXPrvImpl :: Uint8Array -> Uint8Array -> Uint8Array

foreign import verificationKeyFromSerializedXPrvImpl :: Uint8Array -> Uint8Array

foreign import verifyXPubImpl :: Uint8Array -> Uint8Array -> Uint8Array -> Boolean

payloadModeLabel :: PayloadMode -> String
payloadModeLabel = case _ of
  PayloadText -> "Text"
  PayloadHex -> "Hex"

signPayload :: PayloadMode -> String -> String -> Either String SignResult
signPayload payloadMode payloadInput signingKeyBech32 = do
  decoded <- Bech32.decode signingKeyBech32
  verificationHrp <- verificationHrpFor decoded.hrp
  if byteLength decoded.bytes /= 96 then
    Left "Expected a serialized extended signing key with 96 bytes."
  else do
    payloadBytes <- parsePayload payloadMode payloadInput
    let
      signatureBytes = signSerializedXPrvImpl decoded.bytes payloadBytes
      verificationKeyBytes = verificationKeyFromSerializedXPrvImpl decoded.bytes
    Right
      { payloadHex: Hex.toHex payloadBytes
      , signatureHex: Hex.toHex signatureBytes
      , verificationKeyBech32: Bech32.encode verificationHrp verificationKeyBytes
      }

verifySignature :: PayloadMode -> String -> String -> String -> Either String Boolean
verifySignature payloadMode payloadInput verificationKeyBech32 signatureHex = do
  decoded <- Bech32.decode verificationKeyBech32
  _ <- ensureVerificationHrp decoded.hrp
  if byteLength decoded.bytes /= 64 then
    Left "Expected an extended verification key with 64 bytes."
  else do
    payloadBytes <- parsePayload payloadMode payloadInput
    signatureBytes <- Hex.fromHex signatureHex
    if byteLength signatureBytes /= 64 then
      Left "Expected a 64-byte Ed25519 signature encoded as hex."
    else
      Right (verifyXPubImpl payloadBytes decoded.bytes signatureBytes)

parsePayload :: PayloadMode -> String -> Either String Uint8Array
parsePayload = case _ of
  PayloadText -> Right <<< encodeUtf8Impl
  PayloadHex -> Hex.fromHex

verificationHrpFor :: String -> Either String String
verificationHrpFor = case _ of
  "root_xsk" -> Right "root_xvk"
  "acct_xsk" -> Right "acct_xvk"
  "addr_xsk" -> Right "addr_xvk"
  "stake_xsk" -> Right "stake_xvk"
  other -> Left ("Unsupported signing key prefix: " <> other <> ".")

ensureVerificationHrp :: String -> Either String Unit
ensureVerificationHrp = case _ of
  "root_xvk" -> Right unit
  "acct_xvk" -> Right unit
  "addr_xvk" -> Right unit
  "stake_xvk" -> Right unit
  other -> Left ("Unsupported verification key prefix: " <> other <> ".")
