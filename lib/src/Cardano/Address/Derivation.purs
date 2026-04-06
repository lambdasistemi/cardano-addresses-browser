module Cardano.Address.Derivation
  ( Role(..)
  , DerivedKeys
  , derivePipeline
  , roleLabel
  ) where

import Prelude

import Cardano.Address.Bech32 as Bech32
import Control.Promise (Promise, toAffE)
import Data.ArrayBuffer.Types (Uint8Array)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Aff (Aff)

data Role
  = UTxOExternal
  | UTxOInternal
  | Stake

derive instance eqRole :: Eq Role

type DerivedKeys =
  { rootKeyBech32 :: String
  , accountKeyBech32 :: String
  , addressKeyBech32 :: String
  , addressPublicKeyBech32 :: String
  , stakeKeyBech32 :: String
  , stakePublicKeyBech32 :: String
  }

foreign import deriveRootKeyImpl :: String -> Effect (Promise Uint8Array)

foreign import deriveAccountKeyImpl :: Uint8Array -> Int -> Uint8Array

foreign import deriveAddressKeyImpl :: Uint8Array -> Int -> Int -> Uint8Array

foreign import deriveStakeKeyImpl :: Uint8Array -> Uint8Array

foreign import toXPubImpl :: Uint8Array -> Uint8Array

foreign import serializeXPrvImpl :: Uint8Array -> Uint8Array

derivePipeline :: Array String -> Int -> Role -> Int -> Aff DerivedKeys
derivePipeline words accountIndex role addressIndex = do
  rootKey <- toAffE (deriveRootKeyImpl (joinWith " " words))
  let
    accountKey = deriveAccountKeyImpl rootKey accountIndex
    addressKey = deriveAddressKeyImpl accountKey (roleIndex role) addressIndex
    addressPublicKey = toXPubImpl addressKey
    stakeKey = deriveStakeKeyImpl accountKey
    stakePublicKey = toXPubImpl stakeKey
  pure
    { rootKeyBech32: Bech32.encode "root_xsk" (serializeXPrvImpl rootKey)
    , accountKeyBech32: Bech32.encode "acct_xsk" (serializeXPrvImpl accountKey)
    , addressKeyBech32: Bech32.encode (addressXskPrefix role) (serializeXPrvImpl addressKey)
    , addressPublicKeyBech32: Bech32.encode (addressXvkPrefix role) addressPublicKey
    , stakeKeyBech32: Bech32.encode "stake_xsk" (serializeXPrvImpl stakeKey)
    , stakePublicKeyBech32: Bech32.encode "stake_xvk" stakePublicKey
    }

roleIndex :: Role -> Int
roleIndex = case _ of
  UTxOExternal -> 0
  UTxOInternal -> 1
  Stake -> 2

roleLabel :: Role -> String
roleLabel = case _ of
  UTxOExternal -> "External"
  UTxOInternal -> "Internal"
  Stake -> "Stake"

addressXskPrefix :: Role -> String
addressXskPrefix = case _ of
  Stake -> "stake_xsk"
  _ -> "addr_xsk"

addressXvkPrefix :: Role -> String
addressXvkPrefix = case _ of
  Stake -> "stake_xvk"
  _ -> "addr_xvk"
