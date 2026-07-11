module Main where

import Prelude

import App as App
import Data.Maybe (maybe)
import Effect (Effect)
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.DOM.ParentNode (QuerySelector(..))

main :: Effect Unit
main = HA.runHalogenAff do
  HA.awaitLoad
  mRoot <- HA.selectElement (QuerySelector "#app-root")
  root <- maybe HA.awaitBody pure mRoot
  runUI App.component unit root
