module App where

import Prelude

import Cardano.Address (base58)
import Cardano.Address.Bootstrap as Bootstrap
import Cardano.Address.Derivation as Derivation
import Cardano.Address.Inspect as Inspect
import Cardano.Address.Script as Script
import Cardano.Codec.Bech32.Prefixes as Prefixes
import Cardano.Mnemonic as Mnemonic
import Data.Array (length, mapWithIndex)
import Data.Either (Either(..))
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String (joinWith)
import Effect (Effect)
import Effect.Aff (try)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

data Page
  = Overview
  | Inspect
  | Mnemonic
  | Derivation
  | Legacy
  | Scripts
  | Library

derive instance eqPage :: Eq Page

data RestoreFamily
  = RestoreShelley
  | RestoreIcarus
  | RestoreByron

derive instance eqRestoreFamily :: Eq RestoreFamily

data ScriptInputMode
  = ScriptInputCbor
  | ScriptInputJson
  | ScriptInputTemplate

derive instance eqScriptInputMode :: Eq ScriptInputMode

data Action
  = SelectPage Page
  | SetInspectInput String
  | RunInspect
  | SetMnemonicWordCount Int
  | GenerateMnemonic
  | CopyMnemonic
  | CopyValue String
  | ToggleStatePanel
  | ToggleRestorePhraseVisibility
  | ToggleDerivedKeysVisibility
  | SetDerivationInput String
  | UseGeneratedMnemonic
  | SetRestoreFamily RestoreFamily
  | SetAccountIndexInput String
  | SetAddressIndexInput String
  | SetDerivationRole Derivation.Role
  | RunDerivation
  | SetLegacyStyle Bootstrap.LegacyStyle
  | SetLegacyNetwork Bootstrap.LegacyNetwork
  | SelectLegacyCustomNetwork
  | SetLegacyAddressXPubInput String
  | SetLegacyRootXPubInput String
  | SetLegacyDerivationPathInput String
  | SetLegacyCustomMagicInput String
  | SetScriptInputMode ScriptInputMode
  | SetScriptInput String

type State =
  { activePage :: Page
  , inspectInput :: String
  , inspectResult :: Maybe (Either String Inspect.AddressInfo)
  , mnemonicWordCount :: Int
  , generatedMnemonic :: Maybe (Array String)
  , showStatePanel :: Boolean
  , showRestorePhrase :: Boolean
  , showDerivedKeys :: Boolean
  , derivationInput :: String
  , restoreFamily :: RestoreFamily
  , accountIndexInput :: String
  , addressIndexInput :: String
  , derivationRole :: Derivation.Role
  , previousDerivedKeys :: Maybe Derivation.DerivedKeys
  , derivationResult :: Maybe (Either String Derivation.DerivedKeys)
  , familyRestoreResult :: Maybe (Either String String)
  , legacyStyle :: Bootstrap.LegacyStyle
  , legacyNetwork :: Bootstrap.LegacyNetwork
  , legacyAddressXPubInput :: String
  , legacyRootXPubInput :: String
  , legacyDerivationPathInput :: String
  , legacyCustomMagicInput :: String
  , legacyResult :: Maybe (Either String String)
  , scriptInputMode :: ScriptInputMode
  , scriptInput :: String
  , scriptAnalysisResult :: Maybe (Either String Script.ScriptAnalysis)
  , scriptTemplateAnalysisResult :: Maybe (Either String Script.ScriptTemplateAnalysis)
  }

initialState :: State
initialState =
  { activePage: Overview
  , inspectInput: ""
  , inspectResult: Nothing
  , mnemonicWordCount: 24
  , generatedMnemonic: Nothing
  , showStatePanel: false
  , showRestorePhrase: false
  , showDerivedKeys: false
  , derivationInput: ""
  , restoreFamily: RestoreShelley
  , accountIndexInput: "0"
  , addressIndexInput: "0"
  , derivationRole: Derivation.UTxOExternal
  , previousDerivedKeys: Nothing
  , derivationResult: Nothing
  , familyRestoreResult: Nothing
  , legacyStyle: Bootstrap.LegacyIcarus
  , legacyNetwork: Bootstrap.LegacyMainnet
  , legacyAddressXPubInput: ""
  , legacyRootXPubInput: ""
  , legacyDerivationPathInput: "0H/0"
  , legacyCustomMagicInput: "4242"
  , legacyResult: Nothing
  , scriptInputMode: ScriptInputCbor
  , scriptInput: ""
  , scriptAnalysisResult: Nothing
  , scriptTemplateAnalysisResult: Nothing
  }

component :: forall query input output monad. MonadAff monad => H.Component query input output monad
component =
  H.mkComponent
    { initialState: const initialState
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

foreign import copyToClipboard :: String -> Effect Unit
foreign import normalizeMnemonicInput :: String -> Array String
foreign import normalizeHexInput :: String -> String
foreign import parseIndexInput :: String -> Int

handleAction :: forall output monad. MonadAff monad => Action -> H.HalogenM State Action () output monad Unit
handleAction = case _ of
  SelectPage page ->
    H.modify_ _ { activePage = page }
  SetInspectInput value ->
    H.modify_ _ { inspectInput = value, inspectResult = Nothing }
  RunInspect ->
    H.modify_ \state ->
      state
        { inspectResult =
            if state.inspectInput == "" then
              Just (Left "Paste a Cardano address to inspect.")
            else
              Just (Inspect.eitherInspectAddress state.inspectInput)
        }
  SetMnemonicWordCount value ->
    H.modify_ _ { mnemonicWordCount = value }
  GenerateMnemonic -> do
    state <- H.get
    words <- liftEffect (Mnemonic.generateMnemonic state.mnemonicWordCount)
    H.modify_ _
      { generatedMnemonic = Just words
      , derivationInput = joinWith " " words
      }
    refreshDerivation
  CopyMnemonic -> do
    state <- H.get
    let
      normalizedPhrase = joinWith " " (normalizeMnemonicInput state.derivationInput)
    if normalizedPhrase == "" then
      pure unit
    else
      liftEffect (copyToClipboard normalizedPhrase)
  CopyValue value ->
    liftEffect (copyToClipboard value)
  ToggleStatePanel ->
    H.modify_ \state -> state { showStatePanel = not state.showStatePanel }
  ToggleRestorePhraseVisibility ->
    H.modify_ \state -> state { showRestorePhrase = not state.showRestorePhrase }
  ToggleDerivedKeysVisibility ->
    H.modify_ \state -> state { showDerivedKeys = not state.showDerivedKeys }
  SetDerivationInput value ->
    H.modify_ _ { derivationInput = value }
      *> refreshDerivation
  UseGeneratedMnemonic -> do
    state <- H.get
    case state.generatedMnemonic of
      Nothing -> pure unit
      Just words ->
        H.modify_ _
          { derivationInput = joinWith " " words
          }
          *> refreshDerivation
  SetRestoreFamily family -> do
    state <- H.get
    H.modify_ _ { restoreFamily = family, derivationRole = normalizeRoleForFamily family state.derivationRole }
      *> refreshDerivation
  SetAccountIndexInput value ->
    H.modify_ _ { accountIndexInput = normalizeIndexInput value }
      *> refreshDerivation
  SetAddressIndexInput value ->
    H.modify_ _ { addressIndexInput = normalizeIndexInput value }
      *> refreshDerivation
  SetDerivationRole role ->
    H.modify_ _ { derivationRole = role }
      *> refreshDerivation
  RunDerivation ->
    refreshDerivation
  SetLegacyStyle style ->
    H.modify_ _ { legacyStyle = style }
      *> refreshLegacyConstruction
  SetLegacyNetwork network ->
    H.modify_ _ { legacyNetwork = network }
      *> refreshDerivation
      *> refreshLegacyConstruction
  SelectLegacyCustomNetwork -> do
    state <- H.get
    let
      nextNetwork = case parseLegacyCustomMagic state.legacyCustomMagicInput of
        Right magic -> Bootstrap.LegacyCustom magic
        Left _ -> Bootstrap.LegacyCustom 4242
    H.modify_ _ { legacyNetwork = nextNetwork }
      *> refreshDerivation
      *> refreshLegacyConstruction
  SetLegacyAddressXPubInput value ->
    H.modify_ _ { legacyAddressXPubInput = value }
      *> refreshLegacyConstruction
  SetLegacyRootXPubInput value ->
    H.modify_ _ { legacyRootXPubInput = value }
      *> refreshLegacyConstruction
  SetLegacyDerivationPathInput value ->
    H.modify_ _ { legacyDerivationPathInput = value }
      *> refreshLegacyConstruction
  SetLegacyCustomMagicInput value -> do
    state <- H.get
    let
      nextNetwork =
        if isLegacyCustomNetwork state.legacyNetwork then
          case parseLegacyCustomMagic value of
            Right magic -> Bootstrap.LegacyCustom magic
            Left _ -> state.legacyNetwork
        else
          state.legacyNetwork
    H.modify_ _ { legacyCustomMagicInput = value, legacyNetwork = nextNetwork }
      *> refreshDerivation
      *> refreshLegacyConstruction
  SetScriptInputMode mode -> do
    state <- H.get
    H.modify_ _
      { scriptInputMode = mode
      , scriptAnalysisResult = scriptAnalysisStatus mode state.scriptInput
      , scriptTemplateAnalysisResult = scriptTemplateAnalysisStatus mode state.scriptInput
      }
  SetScriptInput value ->
    H.modify_ \state ->
      state
        { scriptInput = value
        , scriptAnalysisResult = scriptAnalysisStatus state.scriptInputMode value
        , scriptTemplateAnalysisResult = scriptTemplateAnalysisStatus state.scriptInputMode value
        }

refreshDerivation :: forall output monad. MonadAff monad => H.HalogenM State Action () output monad Unit
refreshDerivation = do
  state <- H.get
  let
    words = normalizeMnemonicInput state.derivationInput
    accountIndex = parseIndexInput state.accountIndexInput
    addressIndex = parseIndexInput state.addressIndexInput
  if length words == 0 then
    H.modify_ _ { derivationResult = Nothing, familyRestoreResult = Nothing }
  else if not (Mnemonic.validateMnemonic words) then
    H.modify_ _
      { derivationResult = invalidMnemonicResult state.restoreFamily
      , familyRestoreResult = invalidMnemonicAddressResult state.restoreFamily
      }
  else do
    case state.restoreFamily of
      RestoreShelley -> do
        result <- liftAff (try (Derivation.derivePipeline words accountIndex state.derivationRole addressIndex))
        H.modify_ _
          { previousDerivedKeys = latestSuccessfulDerivation state
          , derivationResult = Just case result of
              Left err -> Left ("Key derivation failed: " <> message err)
              Right value -> Right value
          , familyRestoreResult = Nothing
          }
      RestoreIcarus -> do
        let
          selectedNetwork = resolveLegacyNetwork state
          role = icarusRoleFor state.derivationRole
          result = case selectedNetwork of
            Left err -> pure (Left err)
            Right network -> do
              address <- Bootstrap.constructIcarusAddressFromMnemonic network words accountIndex role addressIndex
              pure (Right (base58 address))
        actual <- liftAff (try result)
        H.modify_ _
          { derivationResult = Nothing
          , familyRestoreResult = Just case actual of
              Left err -> Left ("Restore failed: " <> message err)
              Right value -> value
          }
      RestoreByron -> do
        let
          selectedNetwork = resolveLegacyNetwork state
          result = case selectedNetwork of
            Left err -> pure (Left err)
            Right network -> do
              address <- Bootstrap.constructByronAddressFromMnemonic network words accountIndex addressIndex
              pure (Right (base58 address))
        actual <- liftAff (try result)
        H.modify_ _
          { derivationResult = Nothing
          , familyRestoreResult = Just case actual of
              Left err -> Left ("Restore failed: " <> message err)
              Right value -> value
          }

latestSuccessfulDerivation :: State -> Maybe Derivation.DerivedKeys
latestSuccessfulDerivation state = case state.derivationResult of
  Just (Right keys) -> Just keys
  _ -> state.previousDerivedKeys

refreshLegacyConstruction :: forall output monad. MonadAff monad => H.HalogenM State Action () output monad Unit
refreshLegacyConstruction = do
  state <- H.get
  if String.trim state.legacyAddressXPubInput == "" then
    H.modify_ _ { legacyResult = Nothing }
  else do
    let
      selectedNetwork = resolveLegacyNetwork state
      result = case selectedNetwork of
        Left err ->
          pure (Left err)
        Right network ->
          case Bootstrap.parseBootstrapXPub state.legacyAddressXPubInput of
            Left err ->
              pure (Left err)
            Right addressXPub -> case state.legacyStyle of
              Bootstrap.LegacyIcarus ->
                pure (Right (base58 (Bootstrap.constructIcarusAddress network addressXPub)))
              Bootstrap.LegacyByron ->
                if String.trim state.legacyRootXPubInput == "" then
                  pure (Left "Paste the root_xvk key for Byron bootstrap addresses.")
                else case Bootstrap.parseBootstrapXPub state.legacyRootXPubInput of
                  Left err ->
                    pure (Left err)
                  Right rootXPub ->
                    if String.trim state.legacyDerivationPathInput == "" then
                      pure (Left "Enter a 2-segment Byron path like 0H/0.")
                    else do
                      address <- Bootstrap.constructByronAddress
                        network
                        addressXPub
                        rootXPub
                        state.legacyDerivationPathInput
                      pure (Right (base58 address))
    actual <- liftAff (try result)
    H.modify_ _
      { legacyResult = Just case actual of
          Left err -> Left ("Legacy construction failed: " <> message err)
          Right value -> value
      }

scriptAnalysisStatus :: ScriptInputMode -> String -> Maybe (Either String Script.ScriptAnalysis)
scriptAnalysisStatus mode value =
  let
    trimmed = String.trim value
    normalizedHex = normalizeHexInput value
  in
    case mode of
      ScriptInputCbor ->
        if normalizedHex == "" then
          Nothing
        else
          Just (Script.analyzeNativeScriptHex normalizedHex)
      ScriptInputJson ->
        if trimmed == "" then
          Nothing
        else
          Just (Script.analyzeNativeScriptJson trimmed)
      ScriptInputTemplate ->
        Nothing

scriptTemplateAnalysisStatus :: ScriptInputMode -> String -> Maybe (Either String Script.ScriptTemplateAnalysis)
scriptTemplateAnalysisStatus mode value =
  let
    trimmed = String.trim value
  in
    case mode of
      ScriptInputTemplate ->
        if trimmed == "" then
          Nothing
        else
          Just (Script.analyzeScriptTemplateJson trimmed)
      _ ->
        Nothing

render :: forall monad. State -> H.ComponentHTML Action () monad
render state =
  HH.div
    [ HP.class_ (HH.ClassName "shell") ]
    [ renderSidebar state.activePage
    , HH.main
        [ HP.class_ (HH.ClassName "main-panel") ]
        [ renderTopbar state
        , renderActivePage state
        , renderStatePanel state
        ]
    ]

renderSidebar :: forall w. Page -> HH.HTML w Action
renderSidebar activePage =
  HH.aside
    [ HP.class_ (HH.ClassName "sidebar") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "sidebar-brand") ]
        [ HH.p [ HP.class_ (HH.ClassName "sidebar-kicker") ] [ HH.text "Cardano tools" ]
        , HH.h1 [ HP.class_ (HH.ClassName "sidebar-title") ] [ HH.text "Address Browser" ]
        , HH.p
            [ HP.class_ (HH.ClassName "sidebar-copy") ]
            [ HH.text "A browser-native workspace for inspecting, deriving, and composing Cardano address data." ]
        ]
    , HH.nav
        [ HP.class_ (HH.ClassName "nav-list") ]
        (map (renderNavItem activePage) navItems)
    , HH.div
        [ HP.class_ (HH.ClassName "sidebar-footer") ]
        [ statTile "Library" "Buildable"
        , statTile "App" "Live shell"
        , statTile "Next" "Address inspect"
        ]
    ]

renderTopbar :: forall w. State -> HH.HTML w Action
renderTopbar state =
  HH.header
    [ HP.class_ (HH.ClassName "topbar") ]
    [ HH.div_
        [ HH.p [ HP.class_ (HH.ClassName "eyebrow") ] [ HH.text "Workspace status" ]
        , HH.h2 [ HP.class_ (HH.ClassName "page-title") ] [ HH.text (pageTitle state.activePage) ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "topbar-badges") ]
        [ badge "PureScript"
        , badge "Halogen"
        , badge "Offline-first"
        , HH.button
            [ HP.class_
                (HH.ClassName ("secondary-btn" <> if state.showStatePanel then " active" else ""))
            , HE.onClick \_ -> ToggleStatePanel
            ]
            [ HH.text (if state.showStatePanel then "Hide state" else "Show state") ]
        ]
    ]

renderActivePage :: forall w. State -> HH.HTML w Action
renderActivePage state = case state.activePage of
  Overview -> renderOverview
  Inspect -> renderInspectPage state
  Mnemonic -> renderDerivationPage state
  Derivation -> renderDerivationPage state
  Legacy -> renderLegacyPage state
  Scripts -> renderScriptsPage state
  Library -> renderLibraryPage

renderOverview :: forall w. HH.HTML w Action
renderOverview =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ heroCard
        "Buildable baseline"
        "The repo now compiles, bundles, deploys, and has a stable shell for feature work."
        [ "just build"
        , "just bundle"
        , "nix develop -c just build"
        ]
    , heroCard
        "Crypto primitives ready"
        "Bech32, Base58, hex decoding, and Blake2b-224 hashing are wired through FFI."
        [ "Cardano.Address"
        , "Cardano.Address.Bech32"
        , "Cardano.Address.Hash"
        ]
    , sectionCard
        "Planned workflow"
        [ roadmapStep "1" "Inspect any address" "Decode Shelley and Byron payloads into structured fields."
        , roadmapStep "2" "Generate mnemonic" "Add BIP39 generation and validation in the browser."
        , roadmapStep "3" "Derive keys" "Expose the CIP-1852 pipeline from mnemonic to account and address keys."
        ]
    , sectionCard
        "Current bundles"
        [ keyValue "App bundle" "dist/app.js"
        , keyValue "Library bundle" "dist/cardano-addresses.js"
        , keyValue "Published shell" "surge.sh"
        ]
    ]

renderInspectPage :: forall w. State -> HH.HTML w Action
renderInspectPage state =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Address inspection panel"
        [ HH.p_
            [ HH.text "Paste a Cardano address and inspect its decoded structure locally in the browser." ]
        , HH.textarea
            [ HP.class_ (HH.ClassName "text-input inspector-input")
            , HP.rows 6
            , HP.placeholder "addr1... or DdzFF..."
            , HP.value state.inspectInput
            , HE.onValueInput SetInspectInput
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "primary-btn")
                , HE.onClick \_ -> RunInspect
                ]
                [ HH.text "Inspect address" ]
            ]
        ]
    , sectionCard
        "Inspection result"
        [ renderInspectResult state.inspectResult ]
    ]

renderMnemonicPage :: forall w. State -> HH.HTML w Action
renderMnemonicPage state =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Mnemonic generation"
        [ HH.p_
            [ HH.text "Generate an English BIP39 recovery phrase directly in the browser." ]
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            (map (renderWordCountButton state.mnemonicWordCount) mnemonicWordCounts)
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "primary-btn")
                , HE.onClick \_ -> GenerateMnemonic
                ]
                [ HH.text "Generate phrase" ]
            ]
        ]
    , sectionCard
        "Generated phrase"
        [ renderMnemonicResult state.showRestorePhrase state.derivationInput ]
    ]

renderDerivationPage :: forall w. State -> HH.HTML w Action
renderDerivationPage state =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Restore and build"
        [ HH.p_
            [ HH.text "Choose the wallet family first, then restore or build from the recovery phrase you actually have." ]
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            [ renderRestoreFamilyButton state.restoreFamily RestoreShelley
            , renderRestoreFamilyButton state.restoreFamily RestoreIcarus
            , renderRestoreFamilyButton state.restoreFamily RestoreByron
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "mnemonic-controls") ]
            [ HH.p_
                [ HH.text "Generate a fresh phrase here when you are starting from mnemonic material. Generation immediately feeds the restore input below." ]
            , HH.div
                [ HP.class_ (HH.ClassName "action-row") ]
                (map (renderWordCountButton state.mnemonicWordCount) mnemonicWordCounts)
            , HH.div
                [ HP.class_ (HH.ClassName "action-row") ]
                [ HH.button
                    [ HP.class_ (HH.ClassName "primary-btn")
                    , HE.onClick \_ -> GenerateMnemonic
                    ]
                    [ HH.text "Generate phrase" ]
                , HH.button
                    [ HP.class_ (HH.ClassName "secondary-btn")
                    , HE.onClick \_ -> ToggleRestorePhraseVisibility
                    ]
                    [ HH.text (if state.showRestorePhrase then "Hide phrase" else "Show phrase") ]
                , HH.button
                    [ HP.class_ (HH.ClassName "secondary-btn")
                    , HE.onClick \_ -> CopyMnemonic
                    ]
                    [ HH.text "Copy phrase" ]
                ]
            , renderMnemonicResult state.showRestorePhrase state.derivationInput
            ]
        , renderDerivationInput state
        , HH.div
            [ HP.class_ (HH.ClassName "derivation-controls") ]
            [ HH.label
                [ HP.class_ (HH.ClassName "field-group") ]
                [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Account index" ]
                , HH.input
                    [ HP.class_ (HH.ClassName "inline-input")
                    , HP.type_ HP.InputNumber
                    , HP.min 0.0
                    , HP.value state.accountIndexInput
                    , HE.onValueInput SetAccountIndexInput
                    ]
                ]
            , HH.label
                [ HP.class_ (HH.ClassName "field-group") ]
                [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Address index" ]
                , HH.input
                    [ HP.class_ (HH.ClassName "inline-input")
                    , HP.type_ HP.InputNumber
                    , HP.min 0.0
                    , HP.value state.addressIndexInput
                    , HE.onValueInput SetAddressIndexInput
                    ]
                ]
            ]
        , if familyUsesRole state.restoreFamily then
            HH.div
              [ HP.class_ (HH.ClassName "action-row") ]
              (map (renderRoleButton state.derivationRole) (rolesForFamily state.restoreFamily))
          else
            HH.text ""
        , if familyUsesNetwork state.restoreFamily then
            HH.div
              [ HP.class_ (HH.ClassName "action-row") ]
              (map (renderLegacyNetworkButton state.legacyNetwork) legacyNetworks)
          else
            HH.text ""
        , if familyUsesNetwork state.restoreFamily then
            HH.div
              [ HP.class_ (HH.ClassName "action-row") ]
              [ renderLegacyCustomNetworkButton state.legacyNetwork ]
          else
            HH.text ""
        , if familyUsesCustomNetwork state then
            HH.label
              [ HP.class_ (HH.ClassName "field-group") ]
              [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Protocol magic" ]
              , HH.input
                  [ HP.class_ (HH.ClassName "inline-input")
                  , HP.type_ HP.InputNumber
                  , HP.placeholder "4242"
                  , HP.value state.legacyCustomMagicInput
                  , HE.onValueInput SetLegacyCustomMagicInput
                  ]
              ]
          else
            HH.text ""
        , keyValue "Family" (restoreFamilyLabel state.restoreFamily)
        , keyValue "Mode" (restoreModeSummary state.restoreFamily)
        , keyValue "Path" (restorePathSummary state)
        ]
    , sectionCard
        (restoreOutputTitle state.restoreFamily)
        [ case state.restoreFamily of
            RestoreShelley ->
              renderDerivationResult state.showDerivedKeys state.previousDerivedKeys state.derivationResult
            _ ->
              renderFamilyRestoreResult state.familyRestoreResult
        ]
    ]

renderLegacyPage :: forall w. State -> HH.HTML w Action
renderLegacyPage state =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Manual bootstrap construction"
        [ HH.p_
            [ HH.text "Expert mode: construct bootstrap addresses directly from explicit xpub material. The default restore flow now starts from the mnemonic on the Restore page." ]
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            (map (renderLegacyStyleButton state.legacyStyle) legacyStyles)
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            (map (renderLegacyNetworkButton state.legacyNetwork) legacyNetworks)
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            [ renderLegacyCustomNetworkButton state.legacyNetwork ]
        , if isLegacyCustomSelected state then
            HH.label
              [ HP.class_ (HH.ClassName "field-group") ]
              [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Protocol magic" ]
              , HH.input
                  [ HP.class_ (HH.ClassName "inline-input")
                  , HP.type_ HP.InputNumber
                  , HP.placeholder "4242"
                  , HP.value state.legacyCustomMagicInput
                  , HE.onValueInput SetLegacyCustomMagicInput
                  ]
              ]
          else
            HH.text ""
        , HH.label
            [ HP.class_ (HH.ClassName "field-group") ]
            [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Address xpub" ]
            , HH.textarea
                [ HP.class_ (HH.ClassName "text-input inspector-input")
                , HP.rows 4
                , HP.placeholder "addr_xvk1..."
                , HP.value state.legacyAddressXPubInput
                , HE.onValueInput SetLegacyAddressXPubInput
                ]
            ]
        , if state.legacyStyle == Bootstrap.LegacyByron then
            HH.div
              [ HP.class_ (HH.ClassName "legacy-extra-fields") ]
              [ HH.label
                  [ HP.class_ (HH.ClassName "field-group") ]
                  [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Root xpub" ]
                  , HH.textarea
                      [ HP.class_ (HH.ClassName "text-input inspector-input")
                      , HP.rows 4
                      , HP.placeholder "root_xvk1..."
                      , HP.value state.legacyRootXPubInput
                      , HE.onValueInput SetLegacyRootXPubInput
                      ]
                  ]
              , HH.label
                  [ HP.class_ (HH.ClassName "field-group") ]
                  [ HH.span [ HP.class_ (HH.ClassName "field-label") ] [ HH.text "Byron path" ]
                  , HH.input
                      [ HP.class_ (HH.ClassName "inline-input")
                      , HP.placeholder "0H/0"
                      , HP.value state.legacyDerivationPathInput
                      , HE.onValueInput SetLegacyDerivationPathInput
                      ]
                  ]
              ]
          else
            HH.text ""
        , keyValue "Network" (legacyNetworkSummary state)
        , keyValue "Style" (legacyStyleLabel state.legacyStyle)
        ]
    , sectionCard
        "Bootstrap address"
        [ renderLegacyResult state.legacyResult ]
    ]

renderDerivationInput :: forall w. State -> HH.HTML w Action
renderDerivationInput state =
  if not state.showRestorePhrase then
    HH.div_
      [ HH.input
          [ HP.class_ (HH.ClassName "text-input derivation-secret-input")
          , HP.type_ HP.InputPassword
          , HP.placeholder "abandon abandon ... or use the generated phrase"
          , HP.value state.derivationInput
          , HE.onValueInput SetDerivationInput
          ]
      , HH.div
          [ HP.class_ (HH.ClassName "privacy-note") ]
          [ HH.p_ [ HH.text "This card is hidden while keeping paste and derivation available." ] ]
      ]
  else
    HH.div_
      [ HH.textarea
          [ HP.class_ (HH.ClassName "text-input derivation-input")
          , HP.rows 6
          , HP.placeholder "abandon abandon ... or use the generated phrase"
          , HP.value state.derivationInput
          , HE.onValueInput SetDerivationInput
          ]
      ]

renderScriptsPage :: forall w. State -> HH.HTML w Action
renderScriptsPage state =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Native script tools"
        [ HH.p_
            [ HH.text "Author native scripts as canonical JSON or paste existing CBOR preimages. The browser reserializes the script, computes the ledger hash, and validates the result locally." ]
        , HH.div
            [ HP.class_ (HH.ClassName "action-row") ]
            [ renderScriptModeButton state.scriptInputMode ScriptInputCbor "CBOR hex"
            , renderScriptModeButton state.scriptInputMode ScriptInputJson "JSON"
            , renderScriptModeButton state.scriptInputMode ScriptInputTemplate "Template JSON"
            ]
        , HH.textarea
            [ HP.class_ (HH.ClassName "text-input script-input")
            , HP.rows 6
            , HP.placeholder (scriptInputPlaceholder state.scriptInputMode)
            , HP.value state.scriptInput
            , HE.onValueInput SetScriptInput
            ]
        , keyValue "Accepted input" (scriptInputModeLabel state.scriptInputMode)
        , keyValue "Output" (scriptOutputLabel state.scriptInputMode)
        ]
    , sectionCard
        "Script analysis"
        [ case state.scriptInputMode of
            ScriptInputTemplate -> renderScriptTemplateAnalysisResult state.scriptTemplateAnalysisResult
            _ -> renderScriptAnalysisResult state.scriptAnalysisResult
        ]
    ]

renderLibraryPage :: forall w. HH.HTML w Action
renderLibraryPage =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Exported today"
        [ keyValue "Address prefix" Prefixes.addr
        , keyValue "Stake prefix" Prefixes.stake
        , keyValue "Address type" "opaque Uint8Array wrapper"
        ]
    , sectionCard
        "Useful imports"
        [ codeBlock "import Cardano.Address (bech32, fromBech32, base58, fromBase58)"
        , codeBlock "import Cardano.Address.Hash (hashCredentialHex)"
        , codeBlock "import Cardano.Address.Bech32 as Bech32"
        ]
    ]

renderStatePanel :: forall w. State -> HH.HTML w Action
renderStatePanel state =
  if state.showStatePanel then
    HH.section
      [ HP.class_ (HH.ClassName "card state-card") ]
      [ HH.h3 [ HP.class_ (HH.ClassName "card-title") ] [ HH.text "App state" ]
      , HH.div
          [ HP.class_ (HH.ClassName "result-grid") ]
          [ keyValue "Active page" (pageTitle state.activePage)
          , keyValue "Inspect input length" (show (String.length state.inspectInput))
          , keyValue "Inspect result" (inspectStatus state.inspectResult)
          , keyValue "Mnemonic word count" (show state.mnemonicWordCount)
          , keyValue "Mnemonic phrase" (mnemonicStatus state.showRestorePhrase state.derivationInput)
          , keyValue "Restore family" (restoreFamilyLabel state.restoreFamily)
          , keyValue "Derivation role" (Derivation.roleLabel state.derivationRole)
          , keyValue "Restore path" (restorePathSummary state)
          , keyValue "Derivation result" (derivationStatus state.derivationResult)
          , keyValue "Family restore result" (familyRestoreStatus state.familyRestoreResult)
          ]
      ]
  else
    HH.text ""

heroCard :: forall w. String -> String -> Array String -> HH.HTML w Action
heroCard title body bullets =
  HH.section
    [ HP.class_ (HH.ClassName "card card-hero") ]
    [ HH.h3 [ HP.class_ (HH.ClassName "card-title") ] [ HH.text title ]
    , HH.p [ HP.class_ (HH.ClassName "card-copy") ] [ HH.text body ]
    , HH.ul [ HP.class_ (HH.ClassName "bullet-list") ] (map renderBullet bullets)
    ]

sectionCard :: forall w. String -> Array (HH.HTML w Action) -> HH.HTML w Action
sectionCard title contents =
  HH.section
    [ HP.class_ (HH.ClassName "card") ]
    ([ HH.h3 [ HP.class_ (HH.ClassName "card-title") ] [ HH.text title ] ] <> contents)

renderNavItem :: forall w. Page -> NavItem -> HH.HTML w Action
renderNavItem activePage item =
  HH.button
    [ HP.class_
        (HH.ClassName ("nav-item" <> if activePage == item.page then " active" else ""))
    , HE.onClick \_ -> SelectPage item.page
    ]
    [ HH.span [ HP.class_ (HH.ClassName "nav-label") ] [ HH.text item.label ]
    , HH.span [ HP.class_ (HH.ClassName "nav-note") ] [ HH.text item.note ]
    ]

renderBullet :: forall w. String -> HH.HTML w Action
renderBullet value =
  HH.li_ [ HH.text value ]

roadmapStep :: forall w. String -> String -> String -> HH.HTML w Action
roadmapStep number title body =
  HH.div
    [ HP.class_ (HH.ClassName "roadmap-step") ]
    [ HH.div [ HP.class_ (HH.ClassName "roadmap-number") ] [ HH.text number ]
    , HH.div_
        [ HH.h4 [ HP.class_ (HH.ClassName "roadmap-title") ] [ HH.text title ]
        , HH.p [ HP.class_ (HH.ClassName "roadmap-copy") ] [ HH.text body ]
        ]
    ]

keyValue :: forall w. String -> String -> HH.HTML w Action
keyValue label value =
  HH.div
    [ HP.class_ (HH.ClassName "kv-row") ]
    [ HH.span [ HP.class_ (HH.ClassName "kv-label") ] [ HH.text label ]
    , HH.code [ HP.class_ (HH.ClassName "kv-value") ] [ HH.text value ]
    ]

codeBlock :: forall w. String -> HH.HTML w Action
codeBlock value =
  HH.pre
    [ HP.class_ (HH.ClassName "code-block") ]
    [ HH.code_ [ HH.text value ] ]

badge :: forall w. String -> HH.HTML w Action
badge value =
  HH.span [ HP.class_ (HH.ClassName "badge") ] [ HH.text value ]

statTile :: forall w. String -> String -> HH.HTML w Action
statTile label value =
  HH.div
    [ HP.class_ (HH.ClassName "stat-tile") ]
    [ HH.p [ HP.class_ (HH.ClassName "stat-label") ] [ HH.text label ]
    , HH.p [ HP.class_ (HH.ClassName "stat-value") ] [ HH.text value ]
    ]

renderInspectResult :: forall w. Maybe (Either String Inspect.AddressInfo) -> HH.HTML w Action
renderInspectResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "No address inspected yet. Supported today: Shelley bech32 plus Byron and Icarus base58 inspection." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right info) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-grid") ]
      ( [ keyValue "Style" info.addressStyle
        , keyValue "Header type" info.addressTypeLabel
        , keyValue "Header type code" (show info.addressType)
        , keyValue "Network" info.networkTagLabel
        , keyValue "Network tag" (networkTagValue info.networkTag)
        , keyValue "Stake reference" info.stakeReference
        , maybeRow "Spending key hash" info.spendingKeyHash
        , maybeRow "Spending script hash" info.spendingScriptHash
        , maybeRow "Stake key hash" info.stakeKeyHash
        , maybeRow "Stake script hash" info.stakeScriptHash
        ]
          <> map renderDetailRow info.extraDetails
      )

renderDetailRow :: forall w. Inspect.DetailRow -> HH.HTML w Action
renderDetailRow detail =
  keyValue detail.label detail.value

networkTagValue :: Int -> String
networkTagValue tag
  | tag < 0 = "-"
networkTagValue tag = show tag

maybeRow :: forall w. String -> Maybe String -> HH.HTML w Action
maybeRow label value =
  keyValue label case value of
    Just content -> content
    Nothing -> "-"

renderWordCountButton :: forall w. Int -> Int -> HH.HTML w Action
renderWordCountButton activeCount wordCount =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeCount == wordCount then " active" else ""))
    , HE.onClick \_ -> SetMnemonicWordCount wordCount
    ]
    [ HH.text (show wordCount <> " words") ]

renderRoleButton :: forall w. Derivation.Role -> Derivation.Role -> HH.HTML w Action
renderRoleButton activeRole role =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeRole == role then " active" else ""))
    , HE.onClick \_ -> SetDerivationRole role
    ]
    [ HH.text (Derivation.roleLabel role) ]

renderRestoreFamilyButton :: forall w. RestoreFamily -> RestoreFamily -> HH.HTML w Action
renderRestoreFamilyButton activeFamily family =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeFamily == family then " active" else ""))
    , HE.onClick \_ -> SetRestoreFamily family
    ]
    [ HH.text (restoreFamilyLabel family) ]

renderLegacyStyleButton :: forall w. Bootstrap.LegacyStyle -> Bootstrap.LegacyStyle -> HH.HTML w Action
renderLegacyStyleButton activeStyle style =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeStyle == style then " active" else ""))
    , HE.onClick \_ -> SetLegacyStyle style
    ]
    [ HH.text (legacyStyleLabel style) ]

renderLegacyNetworkButton :: forall w. Bootstrap.LegacyNetwork -> Bootstrap.LegacyNetwork -> HH.HTML w Action
renderLegacyNetworkButton activeNetwork network =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeNetwork == network then " active" else ""))
    , HE.onClick \_ -> SetLegacyNetwork network
    ]
    [ HH.text (legacyNetworkShortLabel network) ]

renderLegacyCustomNetworkButton :: forall w. Bootstrap.LegacyNetwork -> HH.HTML w Action
renderLegacyCustomNetworkButton activeNetwork =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if isLegacyCustomNetwork activeNetwork then " active" else ""))
    , HE.onClick \_ -> SelectLegacyCustomNetwork
    ]
    [ HH.text "Custom" ]

renderScriptModeButton :: forall w. ScriptInputMode -> ScriptInputMode -> String -> HH.HTML w Action
renderScriptModeButton activeMode mode label =
  HH.button
    [ HP.class_
        (HH.ClassName ("secondary-btn" <> if activeMode == mode then " active" else ""))
    , HE.onClick \_ -> SetScriptInputMode mode
    ]
    [ HH.text label ]

renderMnemonicResult :: forall w. Boolean -> String -> HH.HTML w Action
renderMnemonicResult isVisible derivationInput =
  let
    words = normalizeMnemonicInput derivationInput
  in
    if length words == 0 then
      HH.div
        [ HP.class_ (HH.ClassName "empty-state") ]
        [ HH.p_
            [ HH.text "No recovery phrase loaded yet. Generate one here or paste one below." ]
        ]
    else
      HH.div
        [ HP.class_ (HH.ClassName "mnemonic-result") ]
        [ if not isVisible then
            HH.div
              [ HP.class_ (HH.ClassName "privacy-note") ]
              [ HH.p_
                  [ HH.text ("Phrase hidden. " <> show (length words) <> " words are available for clipboard copy.") ]
              ]
          else
            HH.div
              [ HP.class_ (HH.ClassName "mnemonic-grid") ]
              (map renderMnemonicWord (zipWithIndex words))
        ]

renderMnemonicWord :: forall w. { index :: Int, word :: String } -> HH.HTML w Action
renderMnemonicWord item =
  HH.div
    [ HP.class_ (HH.ClassName "mnemonic-word") ]
    [ HH.span [ HP.class_ (HH.ClassName "mnemonic-index") ] [ HH.text (show item.index <> ".") ]
    , HH.code [ HP.class_ (HH.ClassName "mnemonic-value") ] [ HH.text item.word ]
    ]

zipWithIndex :: Array String -> Array { index :: Int, word :: String }
zipWithIndex = mapWithIndex \index word -> { index: index + 1, word }

mnemonicWordCounts :: Array Int
mnemonicWordCounts = [ 12, 15, 18, 21, 24 ]

derivationRoles :: Array Derivation.Role
derivationRoles = [ Derivation.UTxOExternal, Derivation.UTxOInternal, Derivation.Stake ]

legacyStyles :: Array Bootstrap.LegacyStyle
legacyStyles = [ Bootstrap.LegacyIcarus, Bootstrap.LegacyByron ]

legacyNetworks :: Array Bootstrap.LegacyNetwork
legacyNetworks =
  [ Bootstrap.LegacyMainnet
  , Bootstrap.LegacyStaging
  , Bootstrap.LegacyTestnet
  , Bootstrap.LegacyPreview
  , Bootstrap.LegacyPreprod
  ]

isLegacyCustomNetwork :: Bootstrap.LegacyNetwork -> Boolean
isLegacyCustomNetwork = case _ of
  Bootstrap.LegacyCustom _ -> true
  _ -> false

isLegacyCustomSelected :: State -> Boolean
isLegacyCustomSelected state = isLegacyCustomNetwork state.legacyNetwork

parseLegacyCustomMagic :: String -> Either String Int
parseLegacyCustomMagic rawValue =
  let
    trimmed = String.trim rawValue
  in
    if trimmed == "" then
      Left "Enter a custom protocol magic."
    else case Int.fromString trimmed of
      Just magic | magic >= 0 -> Right magic
      _ -> Left "Enter a non-negative integer for the custom protocol magic."

resolveLegacyNetwork :: State -> Either String Bootstrap.LegacyNetwork
resolveLegacyNetwork state = case state.legacyNetwork of
  Bootstrap.LegacyCustom _ -> Bootstrap.LegacyCustom <$> parseLegacyCustomMagic state.legacyCustomMagicInput
  network -> Right network

legacyNetworkSummary :: State -> String
legacyNetworkSummary state = case resolveLegacyNetwork state of
  Right network -> Bootstrap.legacyNetworkLabel network
  Left err -> "Custom (" <> err <> ")"

inspectStatus :: Maybe (Either String Inspect.AddressInfo) -> String
inspectStatus = case _ of
  Nothing -> "idle"
  Just (Left _) -> "error"
  Just (Right info) -> "decoded: " <> info.addressStyle

derivationStatus :: Maybe (Either String Derivation.DerivedKeys) -> String
derivationStatus = case _ of
  Nothing -> "idle"
  Just (Left _) -> "error"
  Just (Right _) -> "derived"

invalidMnemonicResult :: RestoreFamily -> Maybe (Either String Derivation.DerivedKeys)
invalidMnemonicResult = case _ of
  RestoreShelley -> Just (Left "Mnemonic is invalid. Check the word list and checksum.")
  _ -> Nothing

invalidMnemonicAddressResult :: RestoreFamily -> Maybe (Either String String)
invalidMnemonicAddressResult = case _ of
  RestoreShelley -> Nothing
  _ -> Just (Left "Mnemonic is invalid. Check the word list and checksum.")

familyRestoreStatus :: Maybe (Either String String) -> String
familyRestoreStatus = case _ of
  Nothing -> "idle"
  Just (Left _) -> "error"
  Just (Right _) -> "derived"

mnemonicStatus :: Boolean -> String -> String
mnemonicStatus isVisible derivationInput =
  let
    words = normalizeMnemonicInput derivationInput
  in
    if length words == 0 then
      "empty"
    else if not isVisible then
      show (length words) <> " words loaded, hidden"
    else
      show (length words) <> " words loaded"

restoreFamilyLabel :: RestoreFamily -> String
restoreFamilyLabel = case _ of
  RestoreShelley -> "Shelley"
  RestoreIcarus -> "Icarus"
  RestoreByron -> "Byron"

restoreModeSummary :: RestoreFamily -> String
restoreModeSummary = case _ of
  RestoreShelley -> "Derive keys from mnemonic using the Shelley sequential path"
  RestoreIcarus -> "Build a bootstrap address from mnemonic using Icarus semantics"
  RestoreByron -> "Build a bootstrap address from mnemonic using Byron semantics"

scriptInputModeLabel :: ScriptInputMode -> String
scriptInputModeLabel = case _ of
  ScriptInputCbor -> "Native script CBOR hex"
  ScriptInputJson -> "Native script JSON"
  ScriptInputTemplate -> "ScriptTemplate JSON"

scriptInputPlaceholder :: ScriptInputMode -> String
scriptInputPlaceholder = case _ of
  ScriptInputCbor -> "8200581c..."
  ScriptInputJson -> "{\"all\":[\"addr_vkh1...\",{\"active_from\":120}]}"
  ScriptInputTemplate -> "{\"cosigners\":{\"cosigner#0\":\"<xpub-hex>\"},\"template\":\"cosigner#0\"}"

scriptOutputLabel :: ScriptInputMode -> String
scriptOutputLabel = case _ of
  ScriptInputTemplate -> "Template validation, canonical template JSON, and derived script details"
  _ -> "Hash, validation status, canonical JSON, and script preimage CBOR"

legacyStyleLabel :: Bootstrap.LegacyStyle -> String
legacyStyleLabel = case _ of
  Bootstrap.LegacyIcarus -> "Icarus"
  Bootstrap.LegacyByron -> "Byron"

legacyNetworkShortLabel :: Bootstrap.LegacyNetwork -> String
legacyNetworkShortLabel = case _ of
  Bootstrap.LegacyMainnet -> "Mainnet"
  Bootstrap.LegacyStaging -> "Staging"
  Bootstrap.LegacyTestnet -> "Testnet"
  Bootstrap.LegacyPreview -> "Preview"
  Bootstrap.LegacyPreprod -> "Preprod"
  Bootstrap.LegacyCustom magic -> "Custom " <> show magic

derivationPathSummary :: State -> String
derivationPathSummary state =
  "m / 1852' / 1815' / " <> state.accountIndexInput <> "' / "
    <> rolePathSegment state.derivationRole
    <> " / "
    <> state.addressIndexInput

restorePathSummary :: State -> String
restorePathSummary state = case state.restoreFamily of
  RestoreShelley -> derivationPathSummary state
  RestoreIcarus ->
    "m / 44' / 1815' / " <> state.accountIndexInput <> "' / "
      <> rolePathSegment (normalizeRoleForFamily RestoreIcarus state.derivationRole)
      <> " / "
      <> state.addressIndexInput
  RestoreByron ->
    "m / " <> state.accountIndexInput <> "' / " <> state.addressIndexInput

restoreOutputTitle :: RestoreFamily -> String
restoreOutputTitle = case _ of
  RestoreShelley -> "Derived keys"
  _ -> "Derived address"

familyUsesRole :: RestoreFamily -> Boolean
familyUsesRole = case _ of
  RestoreShelley -> true
  RestoreIcarus -> true
  RestoreByron -> false

familyUsesNetwork :: RestoreFamily -> Boolean
familyUsesNetwork = case _ of
  RestoreShelley -> false
  _ -> true

familyUsesCustomNetwork :: State -> Boolean
familyUsesCustomNetwork state =
  familyUsesNetwork state.restoreFamily && isLegacyCustomSelected state

rolesForFamily :: RestoreFamily -> Array Derivation.Role
rolesForFamily = case _ of
  RestoreShelley -> derivationRoles
  RestoreIcarus -> [ Derivation.UTxOExternal, Derivation.UTxOInternal ]
  RestoreByron -> []

normalizeRoleForFamily :: RestoreFamily -> Derivation.Role -> Derivation.Role
normalizeRoleForFamily family role = case family of
  RestoreShelley -> role
  RestoreIcarus -> case role of
    Derivation.Stake -> Derivation.UTxOExternal
    other -> other
  RestoreByron -> Derivation.UTxOExternal

icarusRoleFor :: Derivation.Role -> Bootstrap.IcarusRole
icarusRoleFor role = case normalizeRoleForFamily RestoreIcarus role of
  Derivation.UTxOExternal -> Bootstrap.IcarusExternal
  Derivation.UTxOInternal -> Bootstrap.IcarusInternal
  Derivation.Stake -> Bootstrap.IcarusExternal

rolePathSegment :: Derivation.Role -> String
rolePathSegment = case _ of
  Derivation.UTxOExternal -> "0"
  Derivation.UTxOInternal -> "1"
  Derivation.Stake -> "2"

normalizeIndexInput :: String -> String
normalizeIndexInput value = show (parseIndexInput value)

renderDerivationResult
  :: forall w
   . Boolean
  -> Maybe Derivation.DerivedKeys
  -> Maybe (Either String Derivation.DerivedKeys)
  -> HH.HTML w Action
renderDerivationResult isVisible previousKeys = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "No derivation run yet. Paste a mnemonic or reuse the generated phrase, then derive the pipeline." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right keys) ->
    HH.div
      [ HP.class_ (HH.ClassName "derivation-result") ]
      [ HH.div
          [ HP.class_ (HH.ClassName "action-row") ]
          [ HH.button
              [ HP.class_ (HH.ClassName "secondary-btn")
              , HE.onClick \_ -> ToggleDerivedKeysVisibility
              ]
              [ HH.text (if isVisible then "Hide private keys" else "Show private keys") ]
          ]
      , renderDerivedSecretValue isVisible (hasChanged previousKeys _.rootKeyBech32 keys) "Root private key" keys.rootKeyBech32
      , renderDerivedSecretValue isVisible (hasChanged previousKeys _.accountKeyBech32 keys) "Account private key" keys.accountKeyBech32
      , renderDerivedSecretValue isVisible (hasChanged previousKeys _.addressKeyBech32 keys) "Address private key" keys.addressKeyBech32
      , renderDerivedPublicValue (hasChanged previousKeys _.addressPublicKeyBech32 keys) "Address public key" keys.addressPublicKeyBech32
      , renderDerivedSecretValue isVisible (hasChanged previousKeys _.stakeKeyBech32 keys) "Stake private key" keys.stakeKeyBech32
      , renderDerivedPublicValue (hasChanged previousKeys _.stakePublicKeyBech32 keys) "Stake public key" keys.stakePublicKeyBech32
      ]

hasChanged
  :: Maybe Derivation.DerivedKeys
  -> (Derivation.DerivedKeys -> String)
  -> Derivation.DerivedKeys
  -> Boolean
hasChanged previousKeys project currentKeys = case previousKeys of
  Nothing -> false
  Just oldKeys -> project oldKeys /= project currentKeys

renderDerivedSecretValue :: forall w. Boolean -> Boolean -> String -> String -> HH.HTML w Action
renderDerivedSecretValue isVisible changed label value =
  HH.div
    [ HP.class_ (HH.ClassName ("output-card" <> if changed then " changed" else "")) ]
    [ HH.div
        [ HP.class_ (HH.ClassName "output-meta") ]
        [ HH.h4 [ HP.class_ (HH.ClassName "roadmap-title") ] [ HH.text label ]
        , HH.div
            [ HP.class_ (HH.ClassName "output-actions") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "secondary-btn")
                , HE.onClick \_ -> CopyValue value
                ]
                [ HH.text "Copy" ]
            ]
        ]
    , if not isVisible then
        HH.div
          [ HP.class_ (HH.ClassName "privacy-note") ]
          [ HH.p_ [ HH.text "Private key hidden for this card. Use Show or Copy." ] ]
      else
        HH.div
          [ HP.class_ (HH.ClassName "output-value")
          , HP.title value
          ]
          [ HH.text value ]
    ]

renderDerivedPublicValue :: forall w. Boolean -> String -> String -> HH.HTML w Action
renderDerivedPublicValue changed label value =
  HH.div
    [ HP.class_ (HH.ClassName ("output-card" <> if changed then " changed" else "")) ]
    [ HH.div
        [ HP.class_ (HH.ClassName "output-meta") ]
        [ HH.h4 [ HP.class_ (HH.ClassName "roadmap-title") ] [ HH.text label ]
        , HH.div
            [ HP.class_ (HH.ClassName "output-actions") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "secondary-btn")
                , HE.onClick \_ -> CopyValue value
                ]
                [ HH.text "Copy" ]
            ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "output-value")
        , HP.title value
        ]
        [ HH.text value ]
    ]

renderFamilyRestoreResult :: forall w. Maybe (Either String String) -> HH.HTML w Action
renderFamilyRestoreResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "Choose a family, paste a recovery phrase, and the browser will derive the matching address locally." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right address) ->
    HH.div
      [ HP.class_ (HH.ClassName "derivation-result") ]
      [ HH.div
          [ HP.class_ (HH.ClassName "output-card") ]
          [ HH.div
              [ HP.class_ (HH.ClassName "output-meta") ]
              [ HH.h4 [ HP.class_ (HH.ClassName "roadmap-title") ] [ HH.text "Base58 address" ]
              , HH.div
                  [ HP.class_ (HH.ClassName "output-actions") ]
                  [ HH.button
                      [ HP.class_ (HH.ClassName "secondary-btn")
                      , HE.onClick \_ -> CopyValue address
                      ]
                      [ HH.text "Copy" ]
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "output-value")
              , HP.title address
              ]
              [ HH.text address ]
          ]
      ]

renderScriptAnalysisResult :: forall w. Maybe (Either String Script.ScriptAnalysis) -> HH.HTML w Action
renderScriptAnalysisResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "Paste native script CBOR or JSON to see the derived policy hash, canonical JSON, and script preimage." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right result) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-grid") ]
      ( [ keyValue "Script type" result.scriptType
        , keyValue "Validation" result.validationStatus
        , keyValue "Hash hex" result.hashHex
        , keyValue "Hash bech32" result.hashBech32
        , keyValue "Canonical JSON" result.canonicalJson
        , keyValue "Script preimage (CBOR hex)" result.canonicalCborHex
        ]
          <> map renderScriptIssue result.issues
      )

renderScriptIssue :: forall w. Script.ValidationIssue -> HH.HTML w Action
renderScriptIssue issue =
  keyValue
    ("Issue (" <> issue.level <> " / " <> issue.code <> ")")
    issue.message

renderScriptTemplateAnalysisResult :: forall w. Maybe (Either String Script.ScriptTemplateAnalysis) -> HH.HTML w Action
renderScriptTemplateAnalysisResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "Paste ScriptTemplate JSON to validate cosigners, normalize the template, and derive the underlying native script." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right result) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-grid") ]
      ( [ keyValue "Template validation" result.templateValidationStatus
        , keyValue "Canonical template JSON" result.canonicalTemplateJson
        ]
          <> map renderScriptIssue result.templateIssues
          <>
            if result.hasDerivedScript then
              [ keyValue "Derived script type" result.derivedScript.scriptType
              , keyValue "Derived validation" result.derivedScript.validationStatus
              , keyValue "Derived hash hex" result.derivedScript.hashHex
              , keyValue "Derived hash bech32" result.derivedScript.hashBech32
              , keyValue "Derived canonical JSON" result.derivedScript.canonicalJson
              , keyValue "Derived script preimage (CBOR hex)" result.derivedScript.canonicalCborHex
              ]
                <> map renderScriptIssue result.derivedScript.issues
            else
              [ keyValue "Derived script" "Unavailable until the template validates." ]
      )

renderLegacyResult :: forall w. Maybe (Either String String) -> HH.HTML w Action
renderLegacyResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "Paste an addr_xvk to start. Byron additionally needs a root_xvk and a path like 0H/14." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right address) ->
    HH.div
      [ HP.class_ (HH.ClassName "derivation-result") ]
      [ HH.div
          [ HP.class_ (HH.ClassName "output-card") ]
          [ HH.div
              [ HP.class_ (HH.ClassName "output-meta") ]
              [ HH.h4 [ HP.class_ (HH.ClassName "roadmap-title") ] [ HH.text "Base58 bootstrap address" ]
              , HH.div
                  [ HP.class_ (HH.ClassName "output-actions") ]
                  [ HH.button
                      [ HP.class_ (HH.ClassName "secondary-btn")
                      , HE.onClick \_ -> CopyValue address
                      ]
                      [ HH.text "Copy" ]
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "output-value")
              , HP.title address
              ]
              [ HH.text address ]
          ]
      ]

type NavItem =
  { page :: Page
  , label :: String
  , note :: String
  }

navItems :: Array NavItem
navItems =
  [ { page: Overview, label: "Overview", note: "Workspace health" }
  , { page: Inspect, label: "Inspect", note: "Decode addresses" }
  , { page: Derivation, label: "Restore", note: "Choose family first" }
  , { page: Legacy, label: "Expert", note: "Manual bootstrap xpubs" }
  , { page: Scripts, label: "Scripts", note: "Hash native scripts" }
  , { page: Library, label: "Library", note: "Reusable exports" }
  ]

pageTitle :: Page -> String
pageTitle = case _ of
  Overview -> "Project Overview"
  Inspect -> "Address Inspection"
  Mnemonic -> "Restore And Build"
  Derivation -> "Restore And Build"
  Legacy -> "Manual Bootstrap Construction"
  Scripts -> "Native Scripts"
  Library -> "Library Surface"
