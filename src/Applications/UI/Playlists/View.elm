module UI.Playlists.View exposing (view)

import Chunky exposing (..)
import Color exposing (Color)
import Color.Ext as Color
import Common
import Css.Classes as C
import Html exposing (Html, text)
import Html.Attributes exposing (href, placeholder, style, value)
import Html.Events exposing (onInput, onSubmit)
import List.Extra as List
import Material.Icons as Icons
import Material.Icons.Types exposing (Coloring(..))
import Playlists exposing (..)
import UI.Kit exposing (ButtonType(..))
import UI.List
import UI.Navigation exposing (..)
import UI.Page as Page
import UI.Playlists.Page exposing (..)
import UI.Types exposing (..)
import Url



-- 🗺


view : Page -> List Playlist -> Maybe Playlist -> Maybe { oldName : String, newName : String } -> Maybe Color -> Html Msg
view page playlists selectedPlaylist editContext bgColor =
    UI.Kit.receptacle
        { scrolling = True }
        (case page of
            Edit encodedName ->
                let
                    filtered =
                        List.filter
                            (.autoGenerated >> (==) False)
                            playlists
                in
                encodedName
                    |> Url.percentDecode
                    |> Maybe.andThen (\n -> List.find (.name >> (==) n) filtered)
                    |> Maybe.map (edit editContext)
                    |> Maybe.withDefault [ nothing ]

            Index ->
                index playlists selectedPlaylist bgColor

            New ->
                new
        )



-- INDEX


index : List Playlist -> Maybe Playlist -> Maybe Color -> List (Html Msg)
index playlists selectedPlaylist bgColor =
    let
        selectedPlaylistName =
            Maybe.map .name selectedPlaylist

        customPlaylists =
            playlists
                |> List.filterNot .autoGenerated
                |> List.sortBy .name

        customPlaylistListItem playlist =
            if selectedPlaylistName == Just playlist.name then
                selectedPlaylistListItem playlist bgColor

            else
                { label = text playlist.name
                , actions =
                    [ { icon = Icons.more_vert
                      , msg = Just (ShowPlaylistListMenu playlist)
                      , title = "Menu"
                      }
                    ]
                , msg = Just (ActivatePlaylist playlist)
                , isSelected = False
                }

        directoryPlaylists =
            playlists
                |> List.filter .autoGenerated
                |> List.sortBy .name

        directoryPlaylistListItem playlist =
            if selectedPlaylistName == Just playlist.name then
                selectedPlaylistListItem playlist bgColor

            else
                { label = text playlist.name
                , actions = []
                , msg = Just (ActivatePlaylist playlist)
                , isSelected = False
                }
    in
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label Common.backToIndex Hidden
          , NavigateToPage Page.Index
          )
        , ( Icon Icons.add
          , Label "Create a new playlist" Shown
          , NavigateToPage (Page.Playlists New)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , if List.isEmpty playlists then
        chunk
            [ C.relative ]
            [ chunk
                [ C.absolute, C.left_0, C.top_0 ]
                [ UI.Kit.canister [ UI.Kit.h1 "Playlists" ] ]
            ]

      else
        UI.Kit.canister
            [ UI.Kit.h1 "Playlists"

            -- Intro
            --------
            , intro

            -- Custom Playlists
            -------------------
            , if List.isEmpty customPlaylists then
                nothing

              else
                raw
                    [ category "Your Playlists"
                    , UI.List.view
                        UI.List.Normal
                        (List.map customPlaylistListItem customPlaylists)
                    ]

            -- Directory Playlists
            ----------------------
            , if List.isEmpty directoryPlaylists then
                nothing

              else
                raw
                    [ category "Autogenerated Directory Playlists"
                    , UI.List.view
                        UI.List.Normal
                        (List.map directoryPlaylistListItem directoryPlaylists)
                    ]
            ]

    --
    , if List.isEmpty playlists then
        UI.Kit.centeredContent
            [ slab
                Html.a
                [ href (Page.toString <| Page.Playlists New) ]
                [ C.block
                , C.opacity_30
                , C.text_inherit
                ]
                [ Icons.waves 64 Inherit ]
            , slab
                Html.a
                [ href (Page.toString <| Page.Playlists New) ]
                [ C.block
                , C.leading_normal
                , C.mt_2
                , C.opacity_40
                , C.text_center
                , C.text_inherit
                ]
                [ text "No playlists found, create one"
                , lineBreak
                , text "or enable directory playlists."
                ]
            ]

      else
        nothing
    ]


intro : Html Msg
intro =
    [ text "Playlists are not tied to the sources of its tracks, "
    , text "same goes for favourites."
    , lineBreak
    , text "There's also directory playlists, which are playlists derived from root directories."
    ]
        |> raw
        |> UI.Kit.intro


category : String -> Html Msg
category cat =
    chunk
        [ C.antialiased
        , C.font_display
        , C.mb_3
        , C.mt_10
        , C.text_base05
        , C.text_xxs
        , C.truncate
        , C.uppercase

        -- Dark mode
        ------------
        , C.dark__text_base04
        ]
        [ UI.Kit.inlineIcon Icons.folder
        , inline [ C.font_bold, C.ml_2 ] [ text cat ]
        ]


selectedPlaylistListItem : Playlist -> Maybe Color -> UI.List.Item Msg
selectedPlaylistListItem playlist bgColor =
    let
        selectionColor =
            Maybe.withDefault UI.Kit.colors.selection bgColor
    in
    { label =
        brick
            [ selectionColor
                |> Color.toCssString
                |> style "color"
            ]
            []
            [ text playlist.name ]
    , actions =
        [ { icon = \size _ -> Icons.check size (Color selectionColor)
          , msg = Nothing
          , title = "Selected playlist"
          }
        ]
    , msg = Just DeactivatePlaylist
    , isSelected = False
    }



-- NEW


new : List (Html Msg)
new =
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label "Back to list" Hidden
          , NavigateToPage (Page.Playlists Index)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , [ UI.Kit.h2 "Name your playlist"

      --
      , [ onInput SetPlaylistCreationContext
        , placeholder "The Classics"
        ]
            |> UI.Kit.textField
            |> chunky [ C.max_w_md, C.mx_auto ]

      -- Button
      ---------
      , chunk
            [ C.mt_10 ]
            [ UI.Kit.button
                Normal
                Bypass
                (text "Create playlist")
            ]
      ]
        |> UI.Kit.canisterForm
        |> List.singleton
        |> UI.Kit.centeredContent
        |> List.singleton
        |> slab
            Html.form
            [ onSubmit CreatePlaylist ]
            [ C.flex
            , C.flex_grow
            , C.text_center
            ]
    ]



-- EDIT


edit : Maybe { oldName : String, newName : String } -> Playlist -> List (Html Msg)
edit editContext playlist =
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.arrow_back
          , Label "Back to list" Hidden
          , NavigateToPage (Page.Playlists Index)
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , [ UI.Kit.h2 "Name your playlist"

      --
      , [ onInput (SetPlaylistModificationContext playlist.name)
        , placeholder "The Classics"

        --
        , case editContext of
            Just { oldName, newName } ->
                if playlist.name == oldName then
                    value newName

                else
                    value playlist.name

            Nothing ->
                value playlist.name
        ]
            |> UI.Kit.textField
            |> chunky [ C.max_w_md, C.mx_auto ]

      -- Button
      ---------
      , chunk
            [ C.mt_10 ]
            [ UI.Kit.button
                Normal
                Bypass
                (text "Save")
            ]
      ]
        |> UI.Kit.canisterForm
        |> List.singleton
        |> UI.Kit.centeredContent
        |> List.singleton
        |> slab
            Html.form
            [ onSubmit ModifyPlaylist ]
            [ C.flex
            , C.flex_grow
            , C.text_center
            ]
    ]
