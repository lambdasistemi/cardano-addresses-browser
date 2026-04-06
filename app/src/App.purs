module App where

import Prelude

import Cardano.Address.Inspect as Inspect
import Cardano.Codec.Bech32.Prefixes as Prefixes
import Cardano.Mnemonic as Mnemonic
import Data.Array (mapWithIndex)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String (joinWith)
import Effect (Effect)
import Effect.Class (class MonadEffect, liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

data Page
  = Overview
  | Inspect
  | Mnemonic
  | Derivation
  | Scripts
  | Library

derive instance eqPage :: Eq Page

data Action
  = SelectPage Page
  | SetInspectInput String
  | RunInspect
  | SetMnemonicWordCount Int
  | GenerateMnemonic
  | CopyMnemonic

type State =
  { activePage :: Page
  , inspectInput :: String
  , inspectResult :: Maybe (Either String Inspect.AddressInfo)
  , mnemonicWordCount :: Int
  , generatedMnemonic :: Maybe (Array String)
  }

initialState :: State
initialState =
  { activePage: Overview
  , inspectInput: ""
  , inspectResult: Nothing
  , mnemonicWordCount: 24
  , generatedMnemonic: Nothing
  }

component :: forall query input output monad. MonadEffect monad => H.Component query input output monad
component =
  H.mkComponent
    { initialState: const initialState
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

foreign import copyToClipboard :: String -> Effect Unit

handleAction :: forall output monad. MonadEffect monad => Action -> H.HalogenM State Action () output monad Unit
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
    H.modify_ _ { generatedMnemonic = Just words }
  CopyMnemonic -> do
    state <- H.get
    case state.generatedMnemonic of
      Nothing -> pure unit
      Just words ->
        liftEffect (copyToClipboard (joinWith " " words))

render :: forall monad. State -> H.ComponentHTML Action () monad
render state =
  HH.div
    [ HP.class_ (HH.ClassName "shell") ]
    [ renderSidebar state.activePage
    , HH.main
        [ HP.class_ (HH.ClassName "main-panel") ]
        [ renderTopbar state.activePage
        , renderActivePage state
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

renderTopbar :: forall w. Page -> HH.HTML w Action
renderTopbar activePage =
  HH.header
    [ HP.class_ (HH.ClassName "topbar") ]
    [ HH.div_
        [ HH.p [ HP.class_ (HH.ClassName "eyebrow") ] [ HH.text "Workspace status" ]
        , HH.h2 [ HP.class_ (HH.ClassName "page-title") ] [ HH.text (pageTitle activePage) ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "topbar-badges") ]
        [ badge "PureScript"
        , badge "Halogen"
        , badge "Offline-first"
        ]
    ]

renderActivePage :: forall w. State -> HH.HTML w Action
renderActivePage state = case state.activePage of
  Overview -> renderOverview
  Inspect -> renderInspectPage state
  Mnemonic -> renderMnemonicPage state
  Derivation -> renderDerivationPage
  Scripts -> renderScriptsPage
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
        [ renderMnemonicResult state.generatedMnemonic ]
    ]

renderDerivationPage :: forall w. HH.HTML w Action
renderDerivationPage =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Derivation pipeline"
        [ HH.p_
            [ HH.text "This panel will host the mnemonic -> root key -> account key -> role/index -> address key flow." ]
        , keyValue "Standard" "CIP-1852"
        , keyValue "Roles" "External, Internal, Stake"
        ]
    , sectionCard
        "State model"
        [ HH.p_
            [ HH.text "The app shell already separates navigation from content, so each pipeline step can become its own card without rewriting layout." ]
        ]
    ]

renderScriptsPage :: forall w. HH.HTML w Action
renderScriptsPage =
  HH.div
    [ HP.class_ (HH.ClassName "page-grid") ]
    [ sectionCard
        "Native script tools"
        [ HH.p_
            [ HH.text "Script parsing and hashing are still pending, but the final panel shape is reserved here." ]
        , keyValue "Planned features" "hash, preimage, validation"
        ]
    , sectionCard
        "Expression examples"
        [ codeBlock "all [vkh1..., vkh2...]"
        , codeBlock "some 2 [before 42, after 10, vkh1...]"
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
          [ HH.text "No address inspected yet. Supported today: Shelley bech32 with detailed decoding, Byron base58 with fallback classification." ]
      ]
  Just (Left err) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-error") ]
      [ HH.text err ]
  Just (Right info) ->
    HH.div
      [ HP.class_ (HH.ClassName "result-grid") ]
      [ keyValue "Style" info.addressStyle
      , keyValue "Header type" info.addressTypeLabel
      , keyValue "Header type code" (show info.addressType)
      , keyValue "Network" info.networkTagLabel
      , keyValue "Network tag" (show info.networkTag)
      , keyValue "Stake reference" info.stakeReference
      , maybeRow "Spending key hash" info.spendingKeyHash
      , maybeRow "Spending script hash" info.spendingScriptHash
      , maybeRow "Stake key hash" info.stakeKeyHash
      , maybeRow "Stake script hash" info.stakeScriptHash
      ]

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

renderMnemonicResult :: forall w. Maybe (Array String) -> HH.HTML w Action
renderMnemonicResult = case _ of
  Nothing ->
    HH.div
      [ HP.class_ (HH.ClassName "empty-state") ]
      [ HH.p_
          [ HH.text "No mnemonic generated yet. Choose a word count and generate a phrase." ]
      ]
  Just words ->
    HH.div
      [ HP.class_ (HH.ClassName "mnemonic-result") ]
      [ HH.div
          [ HP.class_ (HH.ClassName "action-row") ]
          [ HH.button
              [ HP.class_ (HH.ClassName "primary-btn")
              , HE.onClick \_ -> CopyMnemonic
              ]
              [ HH.text "Copy phrase" ]
          ]
      , HH.div
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

type NavItem =
  { page :: Page
  , label :: String
  , note :: String
  }

navItems :: Array NavItem
navItems =
  [ { page: Overview, label: "Overview", note: "Workspace health" }
  , { page: Inspect, label: "Inspect", note: "Decode addresses" }
  , { page: Mnemonic, label: "Mnemonic", note: "Generate recovery phrases" }
  , { page: Derivation, label: "Derivation", note: "Follow CIP-1852" }
  , { page: Scripts, label: "Scripts", note: "Hash native scripts" }
  , { page: Library, label: "Library", note: "Reusable exports" }
  ]

pageTitle :: Page -> String
pageTitle = case _ of
  Overview -> "Project Overview"
  Inspect -> "Address Inspection"
  Mnemonic -> "Mnemonic Generation"
  Derivation -> "Key Derivation"
  Scripts -> "Native Scripts"
  Library -> "Library Surface"
