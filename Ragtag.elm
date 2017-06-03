module Main exposing (..)

import Css exposing (absolute, left, position, px)
import Css.Colors
import Html exposing (div, span, table, td, text, th, tr)
import Html.Attributes exposing (class, colspan)
import Html.Events exposing (defaultOptions)
import Json.Decode
import Regex
import String.Extra


longTextColumnWidth =
    300


shortTextColumnWidth =
    100


numberColumnWidth =
    50


noAction : ButtonAction
noAction model row colDef word =
    model


type WordCase
    = LowerCase
    | UpperCase
    | TitleCase


wordCase word =
    if String.toLower word == word then
        LowerCase
    else if String.length word > 1 && String.toUpper word == word then
        UpperCase
    else
        TitleCase


wordCaseUp word =
    if wordCase word == LowerCase then
        String.Extra.toSentenceCase word
    else
        String.toUpper word


wordCaseDown word =
    if wordCase word == UpperCase then
        String.Extra.toSentenceCase (String.toLower word)
    else
        String.toLower word


wordCaseUpAction : ButtonAction
wordCaseUpAction =
    applyToWord wordCaseUp


wordCaseDownAction : ButtonAction
wordCaseDownAction =
    applyToWord wordCaseDown


type alias ButtonAction =
    Model -> Int -> ColumnDef -> Int -> Model


type Mode
    = Mode { title : String, help : String, leftButtonAction : ButtonAction, rightButtonAction : ButtonAction }


rowMode =
    Mode
        { title = "Row"
        , help = "Drag to change order. Right-click to remove from editor."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }


wordCaseMode =
    Mode
        { title = "Word Case"
        , help = "Left-click to uppercase word. Right-click to lowercase."
        , leftButtonAction = wordCaseUpAction
        , rightButtonAction = wordCaseDownAction
        }


modes =
    [ rowMode
    , Mode
        { title = "Col Swap"
        , help = "Left-click to select column. Right-click to swap with another for all rows."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Swap"
        , help = "Left-click to select cell. Right-click to swap with selected."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Copy Paste"
        , help = "Left-click to copy cell text. Right-click to replace cell text with last copied text."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Numbering"
        , help = "Left-click to select first number. Right-click to set number relative to first."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , wordCaseMode
    , Mode
        { title = "Word/Punct Zap"
        , help = "Left-click to delete word. Right-click to delete punctuation."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Zap"
        , help = "Left-click to empty cell contents."
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    ]


modifyNth f n list =
    List.indexedMap
        (\i x ->
            if i == n then
                f x
            else
                x
        )
        list


haneTracks =
    List.indexedMap
        (\t title ->
            { artist = "Kotoko"
            , year = "2004"
            , album = "Hane"
            , trackNumber = toString (t + 1)
            , trackTitle = title
            , genre = "J-Pop"
            }
        )
        [ "Introduction"
        , "Asura"
        , "Fuyu No Shizuku (Droplets Of Winter)"
        , "Hayate Gumo (Whirlwind Clouds)"
        , "Gratitude - Ookina Kuri No Ki No Shitade (Under A Large Chestnut Tree)"
        , "Gen'ei (Illusion)"
        , "Itaiyo (It Hurts)"
        , "Hitorigoto (Soliloquy)"
        , "Koe Ga Todokunara (If My Voice Is To Be Heard)"
        , "Lament"
        , "Ashiato (Footprint)"
        , "Hane (Wings)"
        , "Kanariya (Canary) - SORMA No.3 Re-mix"
        ]


model : Model
model =
    { tracks = haneTracks, mode = wordCaseMode }


type alias Track =
    { artist : String, year : String, album : String, trackNumber : String, trackTitle : String, genre : String }


setArtist v track =
    { track | artist = v }


setYear v track =
    { track | year = v }


setAlbum v track =
    { track | album = v }


setTrackNumber v track =
    { track | trackNumber = v }


setTrackTitle v track =
    { track | trackTitle = v }


setGenre v track =
    { track | genre = v }


type alias ColumnDef =
    { heading : String, getter : Track -> String, setter : String -> Track -> Track, width : Int }


columnDefs : List ColumnDef
columnDefs =
    [ { heading = "Artist", getter = .artist, setter = setArtist, width = longTextColumnWidth }
    , { heading = "Year", getter = .year, setter = setYear, width = numberColumnWidth }
    , { heading = "Album", getter = .album, setter = setAlbum, width = longTextColumnWidth }
    , { heading = "Track#", getter = .trackNumber, setter = setTrackNumber, width = numberColumnWidth }
    , { heading = "Track Title", getter = .trackTitle, setter = setTrackTitle, width = longTextColumnWidth }
    , { heading = "Genre", getter = .genre, setter = setGenre, width = shortTextColumnWidth }
    ]


type alias Model =
    { tracks : List Track, mode : Mode }


type MouseButton
    = LeftMouseButton
    | RightMouseButton


type Msg
    = SetActiveMode { newMode : Mode }
    | ClickOnWord { button : MouseButton, row : Int, column : ColumnDef, word : Int }


update : Msg -> Model -> Model
update msg model =
    case model.mode of
        Mode { leftButtonAction, rightButtonAction } ->
            case msg of
                SetActiveMode { newMode } ->
                    { model | mode = newMode }

                ClickOnWord { button, row, column, word } ->
                    (case button of
                        LeftMouseButton ->
                            leftButtonAction

                        RightMouseButton ->
                            rightButtonAction
                    )
                        model
                        row
                        column
                        word


styles =
    Css.asPairs >> Html.Attributes.style


tableStyles =
    [ Css.border3 (px 1) Css.solid Css.Colors.black, Css.borderCollapse Css.collapse ]


words =
    Regex.split Regex.All (Regex.regex "\\s+")


modifyNthWord f n s =
    String.join " "
        (List.indexedMap
            (\w word ->
                if w == n then
                    f word
                else
                    word
            )
            (words s)
        )


applyToWord f model row colDef word =
    { model
        | tracks =
            modifyNth (\track -> colDef.setter (modifyNthWord f word (colDef.getter track)) track)
                row
                model.tracks
    }


onContextMenu msg =
    Html.Events.onWithOptions "contextmenu" { defaultOptions | preventDefault = True } (Json.Decode.succeed msg)


wordSpans row column s =
    List.intersperse (text " ")
        (List.indexedMap
            (\w word ->
                let
                    cow =
                        \button -> ClickOnWord { button = button, row = row, column = column, word = w }
                in
                span [ Html.Events.onClick (cow LeftMouseButton), onContextMenu (cow RightMouseButton) ] [ text word ]
            )
            (words s)
        )


modeSelector model =
    case model.mode of
        Mode { title, help } ->
            table [ styles tableStyles ]
                [ tr []
                    (List.map
                        (\mode ->
                            case mode of
                                Mode { title } ->
                                    td
                                        [ styles
                                            (List.append tableStyles
                                                (if model.mode == mode then
                                                    [ Css.backgroundColor Css.Colors.black, Css.color Css.Colors.silver ]
                                                 else
                                                    []
                                                )
                                            )
                                        , Html.Events.onClick (SetActiveMode { newMode = mode })
                                        ]
                                        [ text title ]
                        )
                        modes
                    )
                , tr [] [ td [ styles tableStyles, colspan (List.length modes) ] [ text help ] ]
                ]


trackTable model =
    table [ styles tableStyles ]
        (List.append
            [ tr []
                (List.map (\colDef -> th [ styles (List.append tableStyles [ Css.minWidth (px (toFloat colDef.width)) ]) ] [ text colDef.heading ])
                    columnDefs
                )
            ]
            (List.indexedMap
                (\t track ->
                    tr []
                        (List.indexedMap (\c colDef -> td [ styles tableStyles ] (wordSpans t colDef (colDef.getter track)))
                            columnDefs
                        )
                )
                model.tracks
            )
        )


view : Model -> Html.Html Msg
view model =
    div [ styles [ Css.fontFamily Css.sansSerif ] ]
        [ modeSelector model, trackTable model ]


main =
    Html.beginnerProgram { model = model, view = view, update = update }
