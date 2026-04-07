module App.Vault
  ( VaultEntry
  , VaultImportResult
  , VaultKind(..)
  , createVaultEntry
  , exportVaultFile
  , importVaultFile
  , kindTag
  , labelForKind
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)

data VaultKind
  = VaultMnemonic
  | VaultSigningKey

derive instance eqVaultKind :: Eq VaultKind

type VaultEntry =
  { id :: String
  , kind :: String
  , label :: String
  , value :: String
  , createdAt :: String
  }

type VaultImportResult =
  { canceled :: Boolean
  , fileName :: String
  , entries :: Array VaultEntry
  }

foreign import createVaultEntryImpl :: String -> String -> String -> Effect VaultEntry

foreign import exportVaultFileImpl :: String -> String -> Array VaultEntry -> Effect (Promise Unit)

foreign import importVaultFileImpl :: String -> Effect (Promise VaultImportResult)

createVaultEntry :: VaultKind -> String -> String -> Effect VaultEntry
createVaultEntry kind label value = createVaultEntryImpl (kindTag kind) label value

exportVaultFile :: String -> String -> Array VaultEntry -> Aff Unit
exportVaultFile fileName passphrase entries = toAffE (exportVaultFileImpl fileName passphrase entries)

importVaultFile :: String -> Aff VaultImportResult
importVaultFile passphrase = toAffE (importVaultFileImpl passphrase)

kindTag :: VaultKind -> String
kindTag = case _ of
  VaultMnemonic -> "mnemonic"
  VaultSigningKey -> "signing-key"

labelForKind :: VaultKind -> String
labelForKind = case _ of
  VaultMnemonic -> "Mnemonic"
  VaultSigningKey -> "Signing key"
