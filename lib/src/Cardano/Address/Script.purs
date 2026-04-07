module Cardano.Address.Script
  ( ValidationIssue
  , ScriptAnalysis
  , analyzeNativeScript
  , analyzeNativeScriptHex
  ) where

import Prelude

import Cardano.Address.ScriptHash as ScriptHash
import Cardano.Address.Hex as Hex
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either(..))

type ValidationIssue =
  { level :: String
  , code :: String
  , message :: String
  }

type ScriptValidationCore =
  { scriptType :: String
  , validationStatus :: String
  , issues :: Array ValidationIssue
  }

type ScriptAnalysis =
  { canonicalCborHex :: String
  , scriptType :: String
  , validationStatus :: String
  , issues :: Array ValidationIssue
  , hashHex :: String
  , hashBech32 :: String
  }

foreign import analyzeNativeScriptImpl
  :: forall r
   . (String -> r)
  -> (ScriptValidationCore -> r)
  -> Uint8Array
  -> r

analyzeNativeScript :: Uint8Array -> Either String ScriptAnalysis
analyzeNativeScript bytes = do
  validation <- analyzeNativeScriptImpl Left Right bytes
  let
    hash = ScriptHash.hashNativeScript bytes
  pure
    { canonicalCborHex: Hex.toHex bytes
    , scriptType: validation.scriptType
    , validationStatus: validation.validationStatus
    , issues: validation.issues
    , hashHex: hash.hashHex
    , hashBech32: hash.hashBech32
    }

analyzeNativeScriptHex :: String -> Either String ScriptAnalysis
analyzeNativeScriptHex value = do
  bytes <- Hex.fromHex value
  analyzeNativeScript bytes
