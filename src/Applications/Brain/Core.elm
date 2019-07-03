module Brain.Core exposing (Flags, Model, Msg(..))

import Alien
import Authentication
import Brain.Authentication as Authentication
import Brain.Sources.Processing.Common as Processing
import Brain.Tracks as Tracks
import Debouncer.Basic as Debouncer exposing (Debouncer)
import Json.Decode as Json
import Sources.Processing as Processing



-- ⛩


type alias Flags =
    {}



-- 🌳


type alias Model =
    { authentication : Authentication.Model
    , hypaethralUserData : Authentication.HypaethralUserData
    , notSoFast : Debouncer Msg Msg
    , processing : Processing.Model
    , tracks : Tracks.Model
    }



-- 📣


type Msg
    = Bypass
    | Initialize String
    | NotifyUI Alien.Event
    | NotSoFast (Debouncer.Msg Msg)
    | Process Processing.Arguments
    | ToCache Alien.Event
      -----------------------------------------
      -- Authentication
      -----------------------------------------
    | RedirectToBlockstackSignIn
      -----------------------------------------
      -- Children
      -----------------------------------------
    | AuthenticationMsg Authentication.Msg
    | ProcessingMsg Processing.Msg
    | TracksMsg Tracks.Msg
      -----------------------------------------
      -- User data
      -----------------------------------------
    | LoadHypaethralUserData Json.Value
    | RemoveTracksBySourceId String
    | SaveHypaethralData
    | SaveFavourites Json.Value
    | SavePlaylists Json.Value
    | SaveSettings Json.Value
    | SaveSources Json.Value
    | SaveTracks Json.Value
