module Cardano.Address.Inspect
  ( AddressInfo
  , DetailRow
  , inspectAddress
  , eitherInspectAddress
  ) where

import Prelude

import Cardano.Address (Address, unAddress)
import Cardano.Address.Base58 as Base58
import Cardano.Address.Bech32 as Bech32
import Cardano.Address.Style.Shelley as Shelley
import Cardano.Bytes as Bytes
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))

type DetailRow =
  { label :: String
  , value :: String
  }

type AddressInfo =
  { addressStyle :: String
  , addressType :: Int
  , addressTypeLabel :: String
  , networkTag :: Int
  , networkTagLabel :: String
  , stakeReference :: String
  , spendingKeyHash :: Maybe String
  , stakeKeyHash :: Maybe String
  , spendingScriptHash :: Maybe String
  , stakeScriptHash :: Maybe String
  , extraDetails :: Array DetailRow
  }

type LegacyAddressInfo =
  { addressStyle :: String
  , networkTag :: Int
  , extraDetails :: Array DetailRow
  }

foreign import inspectLegacyAddressImpl
  :: forall result
   . (String -> result)
  -> (LegacyAddressInfo -> result)
  -> Uint8Array
  -> result

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
      inspectLegacyAddress bytes
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
        inspectLegacyAddress bytes
      else
        map shelleyInfo (Shelley.parseAddressInfoShelley bytes)

isCardanoHrp :: String -> Boolean
isCardanoHrp hrp =
  hrp == "addr"
    || hrp == "addr_test"
    || hrp == "stake"
    || hrp == "stake_test"

inspectLegacyAddress :: Uint8Array -> Either String AddressInfo
inspectLegacyAddress =
  inspectLegacyAddressImpl Left
    ( \info ->
        Right
          { addressStyle: info.addressStyle
          , addressType: 8
          , addressTypeLabel: info.addressStyle <> " address"
          , networkTag: info.networkTag
          , networkTagLabel: legacyNetworkTagLabel info.networkTag
          , stakeReference: "none"
          , spendingKeyHash: Nothing
          , stakeKeyHash: Nothing
          , spendingScriptHash: Nothing
          , stakeScriptHash: Nothing
          , extraDetails: info.extraDetails
          }
    )

shelleyInfo
  :: { addressStyle :: String
     , addressType :: Int
     , addressTypeLabel :: String
     , networkTag :: Int
     , networkTagLabel :: String
     , stakeReference :: String
     , spendingKeyHash :: Maybe String
     , stakeKeyHash :: Maybe String
     , spendingScriptHash :: Maybe String
     , stakeScriptHash :: Maybe String
     }
  -> AddressInfo
shelleyInfo info =
  { addressStyle: info.addressStyle
  , addressType: info.addressType
  , addressTypeLabel: info.addressTypeLabel
  , networkTag: info.networkTag
  , networkTagLabel: info.networkTagLabel
  , stakeReference: info.stakeReference
  , spendingKeyHash: info.spendingKeyHash
  , stakeKeyHash: info.stakeKeyHash
  , spendingScriptHash: info.spendingScriptHash
  , stakeScriptHash: info.stakeScriptHash
  , extraDetails: []
  }

legacyNetworkTagLabel :: Int -> String
legacyNetworkTagLabel tag
  | tag < 0 = "No network tag"
legacyNetworkTagLabel 1 = "Preprod"
legacyNetworkTagLabel 2 = "Preview"
legacyNetworkTagLabel 633343913 = "Legacy staging"
legacyNetworkTagLabel 1097911063 = "Legacy testnet"
legacyNetworkTagLabel tag = "Custom legacy network (" <> show tag <> ")"
