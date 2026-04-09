module Cardano.Address.Inspect
  ( AddressInfo
  , DetailRow
  , eitherInspectAddress
  ) where

import Control.Promise (Promise, toAffE)
import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Effect (Effect)
import Effect.Aff (Aff)

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

foreign import inspectAddressWasmImpl
  :: (String -> Either String AddressInfo)
  -> (AddressInfo -> Either String AddressInfo)
  -> String
  -> Effect (Promise (Either String AddressInfo))

eitherInspectAddress :: String -> Aff (Either String AddressInfo)
eitherInspectAddress value = toAffE (inspectAddressWasmImpl Left Right value)
