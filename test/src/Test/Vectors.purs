module Test.Vectors
  ( BootstrapVector
  , DerivationVector
  , DetailRow
  , ExpectedAddressInfo
  , ExpectedKeys
  , ExpectedScriptHash
  , ExpectedScriptTemplate
  , InspectionVector
  , ScriptHashVector
  , ScriptTemplateVector
  , ValidationIssue
  , derivationVectors
  , inspectionVectors
  , bootstrapVectors
  , scriptHashVectors
  , scriptTemplateVectors
  ) where

import Data.Maybe (Maybe)

type DetailRow =
  { label :: String
  , value :: String
  }

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
  , extraDetails :: Array DetailRow
  }

type InspectionVector =
  { label :: String
  , address :: String
  , expected :: ExpectedAddressInfo
  }

type BootstrapVector =
  { label :: String
  , style :: String
  , network :: String
  , protocolMagic :: Int
  , addressXPubBech32 :: String
  , rootXPubBech32 :: Maybe String
  , derivationPath :: Maybe String
  , expectedAddressBase58 :: String
  }

type ExpectedScriptHash =
  { hashHex :: String
  , hashBech32 :: String
  , canonicalCborHex :: String
  , canonicalJson :: String
  , scriptType :: String
  , validationStatus :: String
  , issues :: Array ValidationIssue
  }

type ValidationIssue =
  { level :: String
  , code :: String
  , message :: String
  }

type ScriptHashVector =
  { label :: String
  , scriptCborHex :: String
  , scriptJson :: String
  , expected :: ExpectedScriptHash
  }

type ExpectedScriptTemplate =
  { canonicalTemplateJson :: String
  , templateValidationStatus :: String
  , templateIssues :: Array ValidationIssue
  , hasDerivedScript :: Boolean
  , derivedScript :: ExpectedScriptHash
  }

type ScriptTemplateVector =
  { label :: String
  , templateJson :: String
  , expected :: ExpectedScriptTemplate
  }

foreign import derivationVectors :: Array DerivationVector

foreign import inspectionVectors :: Array InspectionVector

foreign import bootstrapVectors :: Array BootstrapVector

foreign import scriptHashVectors :: Array ScriptHashVector

foreign import scriptTemplateVectors :: Array ScriptTemplateVector
