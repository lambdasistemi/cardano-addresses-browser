module Cardano.Address.Bootstrap
  ( LegacyStyle(..)
  , LegacyNetwork(..)
  , legacyNetworkLabel
  , parseBootstrapXPub
  , constructIcarusAddress
  , constructByronAddress
  ) where

import Prelude

import Cardano.Address (Address, unsafeMkAddress)
import Cardano.Address.Bech32 as Bech32
import Cardano.Codec.Bech32.Prefixes as Prefixes
import Control.Promise (Promise, toAffE)
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff)

data LegacyStyle
  = LegacyIcarus
  | LegacyByron

derive instance eqLegacyStyle :: Eq LegacyStyle

data LegacyNetwork
  = LegacyMainnet
  | LegacyStaging
  | LegacyTestnet
  | LegacyPreview
  | LegacyPreprod
  | LegacyCustom Int

derive instance eqLegacyNetwork :: Eq LegacyNetwork

foreign import constructIcarusAddressImpl
  :: Int
  -> Uint8Array
  -> Uint8Array

foreign import constructByronAddressImpl
  :: Int
  -> Uint8Array
  -> Uint8Array
  -> String
  -> Effect (Promise Uint8Array)

parseBootstrapXPub :: String -> Either String Uint8Array
parseBootstrapXPub value = do
  decoded <- Bech32.decode value
  if decoded.hrp == Prefixes.addr_xvk || decoded.hrp == Prefixes.root_xvk then
    Right decoded.bytes
  else
    Left "Expected a bech32 extended public key with addr_xvk or root_xvk prefix."

constructIcarusAddress :: LegacyNetwork -> Uint8Array -> Address
constructIcarusAddress network xpub =
  unsafeMkAddress (constructIcarusAddressImpl (legacyProtocolMagic network) xpub)

constructByronAddress
  :: LegacyNetwork
  -> Uint8Array
  -> Uint8Array
  -> String
  -> Aff Address
constructByronAddress network addressXPub rootXPub derivationPath =
  map unsafeMkAddress
    ( toAffE
        ( constructByronAddressImpl
            (legacyProtocolMagic network)
            addressXPub
            rootXPub
            derivationPath
        )
    )

legacyProtocolMagic :: LegacyNetwork -> Int
legacyProtocolMagic = case _ of
  LegacyMainnet -> 764824073
  LegacyStaging -> 633343913
  LegacyTestnet -> 1097911063
  LegacyPreview -> 2
  LegacyPreprod -> 1
  LegacyCustom magic -> magic

legacyNetworkLabel :: LegacyNetwork -> String
legacyNetworkLabel = case _ of
  LegacyMainnet -> "Mainnet"
  LegacyStaging -> "Legacy staging"
  LegacyTestnet -> "Legacy testnet"
  LegacyPreview -> "Preview"
  LegacyPreprod -> "Preprod"
  LegacyCustom magic -> "Custom (" <> show magic <> ")"
