module Cardano.Address.Style.Shelley
  ( NetworkTag
  , mkNetworkTag
  , shelleyMainnet
  , shelleyTestnet
  , AddressType(..)
  , parseAddressInfoShelley
  ) where

import Prelude

import Cardano.Address.Hex as Hex
import Cardano.Bytes as Bytes
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))
import Data.Int.Bits ((.&.), zshr)
import Data.Maybe (Maybe(..))

newtype NetworkTag = NetworkTag Int

data AddressType
  = BaseKeyKey
  | BaseScriptKey
  | BaseKeyScript
  | BaseScriptScript
  | PointerKey
  | PointerScript
  | EnterpriseKey
  | EnterpriseScript
  | RewardKey
  | RewardScript

derive instance eqAddressType :: Eq AddressType

mkNetworkTag :: Int -> Maybe NetworkTag
mkNetworkTag value
  | value >= 0 && value <= 15 = Just (NetworkTag value)
  | otherwise = Nothing

shelleyMainnet :: NetworkTag
shelleyMainnet = NetworkTag 1

shelleyTestnet :: NetworkTag
shelleyTestnet = NetworkTag 0

parseAddressInfoShelley
  :: Uint8Array
  -> Either
       String
       { addressStyle :: String
       , addressType :: Int
       , networkTag :: Int
       , stakeReference :: String
       , spendingKeyHash :: Maybe String
       , stakeKeyHash :: Maybe String
       , spendingScriptHash :: Maybe String
       , stakeScriptHash :: Maybe String
       }
parseAddressInfoShelley bytes = do
  let
    length = Bytes.byteLength bytes
    header = Bytes.unsafeIndex bytes 0
    addressType = zshr header 4
    networkTag = header .&. 0x0f
    paymentHash = Hex.toHex (Bytes.slice 1 29 bytes)
    delegationHash = Hex.toHex (Bytes.slice 29 57 bytes)

  parsedType <- case addressType of
    0 -> expectLength 57 length BaseKeyKey
    1 -> expectLength 57 length BaseScriptKey
    2 -> expectLength 57 length BaseKeyScript
    3 -> expectLength 57 length BaseScriptScript
    4 -> expectMinimumLength 29 length PointerKey
    5 -> expectMinimumLength 29 length PointerScript
    6 -> expectLength 29 length EnterpriseKey
    7 -> expectLength 29 length EnterpriseScript
    14 -> expectLength 29 length RewardKey
    15 -> expectLength 29 length RewardScript
    _ -> Left "Unsupported Shelley address header."

  pure case parsedType of
    BaseKeyKey ->
      baseInfo addressType networkTag "by value"
        (Just paymentHash)
        Nothing
        (Just delegationHash)
        Nothing
    BaseScriptKey ->
      baseInfo addressType networkTag "by value"
        Nothing
        (Just paymentHash)
        (Just delegationHash)
        Nothing
    BaseKeyScript ->
      baseInfo addressType networkTag "by value"
        (Just paymentHash)
        Nothing
        Nothing
        (Just delegationHash)
    BaseScriptScript ->
      baseInfo addressType networkTag "by value"
        Nothing
        (Just paymentHash)
        Nothing
        (Just delegationHash)
    PointerKey ->
      baseInfo addressType networkTag "by pointer"
        (Just paymentHash)
        Nothing
        Nothing
        Nothing
    PointerScript ->
      baseInfo addressType networkTag "by pointer"
        Nothing
        (Just paymentHash)
        Nothing
        Nothing
    EnterpriseKey ->
      baseInfo addressType networkTag "none"
        (Just paymentHash)
        Nothing
        Nothing
        Nothing
    EnterpriseScript ->
      baseInfo addressType networkTag "none"
        Nothing
        (Just paymentHash)
        Nothing
        Nothing
    RewardKey ->
      baseInfo addressType networkTag "by value"
        Nothing
        Nothing
        (Just paymentHash)
        Nothing
    RewardScript ->
      baseInfo addressType networkTag "by value"
        Nothing
        Nothing
        Nothing
        (Just paymentHash)

expectLength :: forall a. Int -> Int -> a -> Either String a
expectLength expected actual value
  | actual == expected = Right value
  | otherwise = Left ("Unexpected Shelley address length: expected " <> show expected <> ", got " <> show actual <> ".")

expectMinimumLength :: forall a. Int -> Int -> a -> Either String a
expectMinimumLength minimumLength actual value
  | actual > minimumLength = Right value
  | otherwise = Left ("Pointer address payload is too short: got " <> show actual <> " bytes.")

baseInfo
  :: Int
  -> Int
  -> String
  -> Maybe String
  -> Maybe String
  -> Maybe String
  -> Maybe String
  -> { addressStyle :: String
     , addressType :: Int
     , networkTag :: Int
     , stakeReference :: String
     , spendingKeyHash :: Maybe String
     , stakeKeyHash :: Maybe String
     , spendingScriptHash :: Maybe String
     , stakeScriptHash :: Maybe String
     }
baseInfo addressType networkTag stakeReference spendingKeyHash spendingScriptHash stakeKeyHash stakeScriptHash =
  { addressStyle: "Shelley"
  , addressType
  , networkTag
  , stakeReference
  , spendingKeyHash
  , stakeKeyHash
  , spendingScriptHash
  , stakeScriptHash
  }
