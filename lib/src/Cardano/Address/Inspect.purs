module Cardano.Address.Inspect
  ( AddressInfo
  , inspectAddress
  , eitherInspectAddress
  ) where

import Prelude

import Cardano.Address (Address, unAddress)
import Cardano.Address.Base58 as Base58
import Cardano.Address.Bech32 as Bech32
import Cardano.Address.Hex as Hex
import Cardano.Address.Style.Shelley as Shelley
import Cardano.Bytes as Bytes
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))

type AddressInfo =
  { addressStyle :: String
  , addressType :: Int
  , networkTag :: Int
  , stakeReference :: String
  , spendingKeyHash :: Maybe String
  , stakeKeyHash :: Maybe String
  , spendingScriptHash :: Maybe String
  , stakeScriptHash :: Maybe String
  }

inspectAddress :: Address -> Either String AddressInfo
inspectAddress = inspectBytes <<< unAddress

eitherInspectAddress :: String -> Either String AddressInfo
eitherInspectAddress value = case Bech32.decode value of
  Right decoded ->
    if isCardanoHrp decoded.hrp then
      inspectBytes decoded.bytes
    else
      Left "Unrecognized address format."
  Left _ -> case Base58.decode value of
    Right bytes ->
      Right (byronInfo bytes)
    Left _ ->
      Left "Unrecognized address format."

inspectBytes :: Uint8Array -> Either String AddressInfo
inspectBytes bytes =
  if Bytes.byteLength bytes == 0 then
    Left "Address payload is empty."
  else
    let
      header = Bytes.unsafeIndex bytes 0
      addressType = header / 16
    in
      if addressType == 8 then
        Right (byronInfo bytes)
      else
        Shelley.parseAddressInfoShelley bytes

isCardanoHrp :: String -> Boolean
isCardanoHrp hrp =
  hrp == "addr"
    || hrp == "addr_test"
    || hrp == "stake"
    || hrp == "stake_test"

byronInfo :: Uint8Array -> AddressInfo
byronInfo bytes =
  { addressStyle: "Byron"
  , addressType: 8
  , networkTag: 0
  , stakeReference: "none"
  , spendingKeyHash: Just (Hex.toHex bytes)
  , stakeKeyHash: Nothing
  , spendingScriptHash: Nothing
  , stakeScriptHash: Nothing
  }
