{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import Prelude

import Cardano.Address
  ( Address
  , ChainPointer (..)
  , NetworkDiscriminant
  , NetworkTag (..)
  , bech32
  , bech32With
  , unsafeMkAddress
  )
import Cardano.Address.Derivation
  ( Depth (AccountK, DelegationK, PaymentK, RootK)
  , DerivationType (Hardened, Soft)
  , Index
  , XPrv
  , XPub
  , indexFromWord32
  , toXPub
  , xprvToBytes
  , xpubToBytes
  )
import Cardano.Address.Style.Shelley
  ( AddressInfo (..)
  , Credential (DelegationFromExtendedKey, PaymentFromExtendedKey)
  , InspectAddress (InspectAddressShelley)
  , ReferenceInfo (ByPointer, ByValue)
  , Role (UTxOExternal, UTxOInternal)
  , Shelley (..)
  , delegationAddress
  , deriveAccountPrivateKey
  , deriveAddressPrivateKey
  , deriveDelegationPrivateKey
  , eitherInspectAddress
  , genMasterKeyFromMnemonic
  , mkNetworkDiscriminant
  , paymentAddress
  , pointerAddress
  , shelleyMainnet
  , shelleyTestnet
  , stakeAddress
  )
import Cardano.Mnemonic
  ( SomeMnemonic
  , mkSomeMnemonic
  )
import Data.Aeson
  ( ToJSON
  , encode
  )
import Data.Maybe
  ( fromMaybe )
import Data.String
  ( fromString )
import Data.Text
  ( Text )
import GHC.Generics
  ( Generic )

import qualified Codec.Binary.Bech32 as Bech32
import qualified Codec.Binary.Encoding as Encoding
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text.Encoding as Text
import qualified Cardano.Codec.Bech32.Prefixes as CIP5

data Vectors = Vectors
  { derivationVectors :: [DerivationVector]
  , inspectionVectors :: [InspectionVector]
  }
  deriving (Eq, Generic, Show)

instance ToJSON Vectors

data DerivationVector = DerivationVector
  { label :: Text
  , mnemonic :: [Text]
  , accountIndex :: Int
  , role :: Text
  , addressIndex :: Int
  , expected :: ExpectedKeys
  }
  deriving (Eq, Generic, Show)

instance ToJSON DerivationVector

data ExpectedKeys = ExpectedKeys
  { rootKeyBech32 :: Text
  , accountKeyBech32 :: Text
  , addressKeyBech32 :: Text
  , addressPublicKeyBech32 :: Text
  , stakeKeyBech32 :: Text
  , stakePublicKeyBech32 :: Text
  }
  deriving (Eq, Generic, Show)

instance ToJSON ExpectedKeys

data InspectionVector = InspectionVector
  { label :: Text
  , address :: Text
  , expected :: ExpectedAddressInfo
  }
  deriving (Eq, Generic, Show)

instance ToJSON InspectionVector

data ExpectedAddressInfo = ExpectedAddressInfo
  { addressStyle :: Text
  , addressType :: Int
  , addressTypeLabel :: Text
  , networkTag :: Int
  , networkTagLabel :: Text
  , stakeReference :: Text
  , spendingKeyHash :: Maybe Text
  , stakeKeyHash :: Maybe Text
  , spendingScriptHash :: Maybe Text
  , stakeScriptHash :: Maybe Text
  }
  deriving (Eq, Generic, Show)

instance ToJSON ExpectedAddressInfo

main :: IO ()
main = BL.putStr (encode vectors)

vectors :: Vectors
vectors =
  Vectors
    { derivationVectors =
        concatMap derivationVectorsForMnemonic mnemonics
    , inspectionVectors =
        concatMap inspectionVectorsForMnemonic mnemonics
    }

mnemonics :: [[Text]]
mnemonics =
  [ [ "message"
    , "mask"
    , "aunt"
    , "wheel"
    , "ten"
    , "maze"
    , "between"
    , "tomato"
    , "slow"
    , "analyst"
    , "ladder"
    , "such"
    , "report"
    , "capital"
    , "produce"
    ]
  , [ "network"
    , "empty"
    , "cause"
    , "mean"
    , "expire"
    , "private"
    , "finger"
    , "accident"
    , "session"
    , "problem"
    , "absurd"
    , "banner"
    , "stage"
    , "void"
    , "what"
    ]
  , [ "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "abandon"
    , "about"
    ]
  ]

derivationVectorsForMnemonic :: [Text] -> [DerivationVector]
derivationVectorsForMnemonic mnemonicWords =
  concatMap (derivationVectorsForAccount mnemonicWords) [0, 1]

derivationVectorsForAccount :: [Text] -> Int -> [DerivationVector]
derivationVectorsForAccount mnemonicWords accountIx =
  [ mkDerivationVector mnemonicWords accountIx "external" 0
  , mkDerivationVector mnemonicWords accountIx "external" 1
  , mkDerivationVector mnemonicWords accountIx "external" 17
  , mkDerivationVector mnemonicWords accountIx "external" 1442
  , mkDerivationVector mnemonicWords accountIx "internal" 0
  , mkDerivationVector mnemonicWords accountIx "internal" 7
  , mkDerivationVector mnemonicWords accountIx "stake" 0
  ]

inspectionVectorsForMnemonic :: [Text] -> [InspectionVector]
inspectionVectorsForMnemonic mnemonicWords =
  let rootKey = rootKeyFromMnemonic mnemonicWords
      account0 = accountKey rootKey 0
      account1 = accountKey rootKey 1
      external0 = addressKey account0 UTxOExternal 0
      external1 = addressKey account0 UTxOExternal 1
      internal0 = addressKey account0 UTxOInternal 0
      stake0 = delegationKey account0
      stake1 = delegationKey account1
      paymentMainnet0 =
        paymentAddress shelleyMainnet (PaymentFromExtendedKey (toXPub <$> external0))
      paymentTestnet0 =
        paymentAddress shelleyTestnet (PaymentFromExtendedKey (toXPub <$> external0))
      paymentCustom3 =
        paymentAddress (unsafeNetworkDiscriminant 3) (PaymentFromExtendedKey (toXPub <$> external0))
      paymentCustom6 =
        paymentAddress (unsafeNetworkDiscriminant 6) (PaymentFromExtendedKey (toXPub <$> external0))
      changeMainnet0 =
        paymentAddress shelleyMainnet (PaymentFromExtendedKey (toXPub <$> internal0))
      delegationTestnet0 =
        delegationAddress
          shelleyTestnet
          (PaymentFromExtendedKey (toXPub <$> external0))
          (DelegationFromExtendedKey (toXPub <$> stake0))
      delegationMainnet0 =
        delegationAddress
          shelleyMainnet
          (PaymentFromExtendedKey (toXPub <$> external0))
          (DelegationFromExtendedKey (toXPub <$> stake0))
      delegationMainnet1 =
        delegationAddress
          shelleyMainnet
          (PaymentFromExtendedKey (toXPub <$> external1))
          (DelegationFromExtendedKey (toXPub <$> stake1))
      pointerMainnet0 =
        pointerAddress
          shelleyMainnet
          (PaymentFromExtendedKey (toXPub <$> external0))
          (ChainPointer 24157 177 42)
      pointerTestnet0 =
        pointerAddress
          shelleyTestnet
          (PaymentFromExtendedKey (toXPub <$> external0))
          (ChainPointer 1 2 3)
      rewardMainnet0 =
        unsafeRight $
          stakeAddress shelleyMainnet (DelegationFromExtendedKey (toXPub <$> stake0))
      rewardTestnet0 =
        unsafeRight $
          stakeAddress shelleyTestnet (DelegationFromExtendedKey (toXPub <$> stake0))
      stem = mnemonicStem mnemonicWords
   in
    [ mkInspectionVector (stem <> "-payment-mainnet") paymentMainnet0
    , mkInspectionVector (stem <> "-payment-testnet") paymentTestnet0
    , mkInspectionVector (stem <> "-payment-custom-3") paymentCustom3
    , mkInspectionVector (stem <> "-payment-custom-6") paymentCustom6
    , mkInspectionVector (stem <> "-change-mainnet") changeMainnet0
    , mkInspectionVector (stem <> "-delegation-mainnet") delegationMainnet0
    , mkInspectionVector (stem <> "-delegation-testnet") delegationTestnet0
    , mkInspectionVector (stem <> "-delegation-mainnet-alt") delegationMainnet1
    , mkInspectionVector (stem <> "-pointer-mainnet") pointerMainnet0
    , mkInspectionVector (stem <> "-pointer-testnet") pointerTestnet0
    , mkInspectionVector (stem <> "-reward-mainnet") rewardMainnet0
    , mkInspectionVector (stem <> "-reward-testnet") rewardTestnet0
    ]

mkDerivationVector :: [Text] -> Int -> Text -> Int -> DerivationVector
mkDerivationVector mnemonicWords accountIx roleName addressIx =
  let root = rootKeyFromMnemonic mnemonicWords
      account = accountKey root accountIx
      stake = delegationKey account
      expected =
        case roleName of
          "external" ->
            let derived = addressKey account UTxOExternal addressIx
             in expectedKeys root account derived stake CIP5.addr_xsk CIP5.addr_xvk
          "internal" ->
            let derived = addressKey account UTxOInternal addressIx
             in expectedKeys root account derived stake CIP5.addr_xsk CIP5.addr_xvk
          "stake" ->
            expectedKeys root account stake stake CIP5.stake_xsk CIP5.stake_xvk
          other ->
            error ("Unsupported role: " <> show other)
   in
    DerivationVector
      { label = mnemonicStem mnemonicWords <> "-" <> roleName <> "-" <> toText addressIx
      , mnemonic = mnemonicWords
      , accountIndex = accountIx
      , role = roleName
      , addressIndex = addressIx
      , expected
      }

expectedKeys
  :: Shelley depth XPrv
  -> Shelley depth1 XPrv
  -> Shelley depth2 XPrv
  -> Shelley depth3 XPrv
  -> Bech32.HumanReadablePart
  -> Bech32.HumanReadablePart
  -> ExpectedKeys
expectedKeys root account derived stake addrXskHrp addrXvkHrp =
  ExpectedKeys
    { rootKeyBech32 = bech32With CIP5.root_xsk (xprvAddress root)
    , accountKeyBech32 = bech32With CIP5.acct_xsk (xprvAddress account)
    , addressKeyBech32 = bech32With addrXskHrp (xprvAddress derived)
    , addressPublicKeyBech32 = bech32With addrXvkHrp (xpubAddress (toXPub <$> derived))
    , stakeKeyBech32 = bech32With CIP5.stake_xsk (xprvAddress stake)
    , stakePublicKeyBech32 = bech32With CIP5.stake_xvk (xpubAddress (toXPub <$> stake))
    }

mkInspectionVector :: Text -> Address -> InspectionVector
mkInspectionVector label address =
  InspectionVector
    { label
    , address = bech32 address
    , expected = toExpectedAddressInfo (inspectShelleyAddress address)
    }

toExpectedAddressInfo :: AddressInfo -> ExpectedAddressInfo
toExpectedAddressInfo AddressInfo {..} =
  ExpectedAddressInfo
    { addressStyle = "Shelley"
    , addressType = fromIntegral infoAddressType
    , addressTypeLabel = addressTypeLabelFor (fromIntegral infoAddressType)
    , networkTag = networkTagToInt infoNetworkTag
    , networkTagLabel = networkTagLabelFor (networkTagToInt infoNetworkTag)
    , stakeReference =
        case infoStakeReference of
          Just ByValue -> "by value"
          Just (ByPointer _) -> "by pointer"
          Nothing -> "none"
    , spendingKeyHash = fmap hexText infoSpendingKeyHash
    , stakeKeyHash = fmap hexText infoStakeKeyHash
    , spendingScriptHash = fmap hexText infoSpendingScriptHash
    , stakeScriptHash = fmap hexText infoStakeScriptHash
    }

rootKeyFromMnemonic :: [Text] -> Shelley 'RootK XPrv
rootKeyFromMnemonic mnemonicWords =
  genMasterKeyFromMnemonic (someMnemonic mnemonicWords) mempty

accountKey :: Shelley 'RootK XPrv -> Int -> Shelley 'AccountK XPrv
accountKey rootKey ix =
  deriveAccountPrivateKey rootKey (hardenedAccountIndex ix)

addressKey
  :: Shelley 'AccountK XPrv
  -> Cardano.Address.Style.Shelley.Role
  -> Int
  -> Shelley 'PaymentK XPrv
addressKey account role ix =
  deriveAddressPrivateKey account role (softPaymentIndex ix)

delegationKey :: Shelley 'AccountK XPrv -> Shelley 'DelegationK XPrv
delegationKey = deriveDelegationPrivateKey

inspectShelleyAddress :: Address -> AddressInfo
inspectShelleyAddress address =
  case eitherInspectAddress Nothing address of
    Right (InspectAddressShelley info) -> info
    _ -> error "Expected a Shelley address"

unsafeNetworkDiscriminant :: Integer -> NetworkDiscriminant Shelley
unsafeNetworkDiscriminant tag =
  unsafeRight (mkNetworkDiscriminant tag)

hardenedAccountIndex :: Int -> Index 'Hardened 'AccountK
hardenedAccountIndex ix =
  fromMaybe (error "Invalid hardened index") $
    indexFromWord32 @(Index 'Hardened 'AccountK) (0x80000000 + fromIntegral ix)

softPaymentIndex :: Int -> Index 'Soft 'PaymentK
softPaymentIndex ix =
  fromMaybe (error "Invalid soft index") $
    indexFromWord32 @(Index 'Soft 'PaymentK) (fromIntegral ix)

someMnemonic :: [Text] -> SomeMnemonic
someMnemonic words' =
  case mkSomeMnemonic @'[9, 12, 15, 18, 21, 24] words' of
    Right mnemonic -> mnemonic
    Left err -> error ("Invalid mnemonic fixture: " <> show err)

xprvAddress :: Shelley depth XPrv -> Address
xprvAddress = unsafeMkAddress . xprvToBytes . getKey

xpubAddress :: Shelley depth XPub -> Address
xpubAddress = unsafeMkAddress . xpubToBytes . getKey

mnemonicStem :: [Text] -> Text
mnemonicStem mnemonicWords =
  case mnemonicWords of
    firstWord : _ -> firstWord
    [] -> "empty"

unsafeRight :: Either err a -> a
unsafeRight = \case
  Right value -> value
  Left _ -> error "Unexpected Left"

toText :: Int -> Text
toText = fromString . show

addressTypeLabelFor :: Int -> Text
addressTypeLabelFor value =
  case value of
    0 -> "Base address (key / key)"
    1 -> "Base address (script / key)"
    2 -> "Base address (key / script)"
    3 -> "Base address (script / script)"
    4 -> "Pointer address (key)"
    5 -> "Pointer address (script)"
    6 -> "Enterprise address (key)"
    7 -> "Enterprise address (script)"
    14 -> "Reward address (key)"
    15 -> "Reward address (script)"
    _ -> error ("Unsupported address type: " <> show value)

networkTagLabelFor :: Int -> Text
networkTagLabelFor value =
  case value of
    0 -> "Testnet-compatible (preview / preprod / custom)"
    1 -> "Mainnet"
    _ -> "Custom network (" <> toText value <> ")"

networkTagToInt :: NetworkTag -> Int
networkTagToInt (NetworkTag tag) = fromIntegral tag

hexText :: BS.ByteString -> Text
hexText =
  Text.decodeUtf8
    . Encoding.encode Encoding.EBase16
