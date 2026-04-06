module Test.Vectors
  ( DerivationVector
  , ExpectedAddressInfo
  , ExpectedKeys
  , InspectionVector
  , derivationVectors
  , inspectionVectors
  ) where

import Prelude

import Data.Maybe (Maybe)

type ExpectedKeys =
  { rootKeyBech32 :: String
  , accountKeyBech32 :: String
  , addressKeyBech32 :: String
  , addressPublicKeyBech32 :: String
  , stakeKeyBech32 :: String
  , stakePublicKeyBech32 :: String
  }

type DerivationVector =
  { label :: String
  , mnemonic :: Array String
  , accountIndex :: Int
  , role :: String
  , addressIndex :: Int
  , expected :: ExpectedKeys
  }

type ExpectedAddressInfo =
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
  }

type InspectionVector =
  { label :: String
  , address :: String
  , expected :: ExpectedAddressInfo
  }

foreign import derivationVectors :: Array DerivationVector

foreign import inspectionVectors :: Array InspectionVector
