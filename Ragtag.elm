module Main exposing (..)

import Css exposing (absolute, left, pct, position, px)
import Css.Colors
import Html exposing (div, input, span, table, td, text, th, tr)
import Html.Attributes exposing (class, colspan, value)
import Html.Events exposing (defaultOptions)
import Http
import Json.Decode as Json
import Json.Decode.Pipeline as Jp
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


wordCaseColor wordCase =
    case wordCase of
        LowerCase ->
            Css.Colors.black

        UpperCase ->
            Css.Colors.blue

        TitleCase ->
            Css.Colors.green


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
    = Mode
        { title : String
        , help : String
        , trackTr : Int -> Track -> Html.Html Msg
        , leftButtonAction : ButtonAction
        , rightButtonAction : ButtonAction
        }


editMode =
    Mode
        { title = "Edit"
        , help = "Free-text editing"
        , trackTr = editableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }


rowMode =
    Mode
        { title = "Row"
        , help = "Drag to change order. Right-click to remove from editor."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }


wordCaseMode =
    Mode
        { title = "Word Case"
        , help = "Left-click to uppercase word. Right-click to lowercase."
        , trackTr = clickableTrackTr
        , leftButtonAction = wordCaseUpAction
        , rightButtonAction = wordCaseDownAction
        }


modes =
    [ editMode
    , rowMode
    , Mode
        { title = "Col Swap"
        , help = "Left-click to select column. Right-click to swap with another for all rows."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Swap"
        , help = "Left-click to select cell. Right-click to swap with selected."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Copy Paste"
        , help = "Left-click to copy cell text. Right-click to replace cell text with last copied text."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Numbering"
        , help = "Left-click to select first number. Right-click to set number relative to first."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , wordCaseMode
    , Mode
        { title = "Word/Punct Zap"
        , help = "Left-click to delete word. Right-click to delete punctuation."
        , trackTr = clickableTrackTr
        , leftButtonAction = noAction
        , rightButtonAction = noAction
        }
    , Mode
        { title = "Cell Zap"
        , help = "Left-click to empty cell contents."
        , trackTr = clickableTrackTr
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


init : ( Model, Cmd Msg )
init =
    ( { tracks = haneTracks, mode = wordCaseMode }
    , getTracksInRootDirectory
    )


type alias Track =
    { artist : String, year : String, album : String, trackNumber : String, trackTitle : String, genre : String }


trackDecoder : Json.Decoder Track
trackDecoder =
    Jp.decode Track
        |> Jp.required "Artist" Json.string
        |> Jp.required "Year" Json.string
        |> Jp.required "Album" Json.string
        |> Jp.required "TrackNumber" Json.string
        |> Jp.required "TrackTitle" Json.string
        |> Jp.required "Genre" Json.string


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
    | SetCellValue { row : Int, column : ColumnDef, newValue : String }
    | ReceiveTracks (Result Http.Error (List Track))


getTracksInRootDirectory : Cmd Msg
getTracksInRootDirectory =
    Http.send ReceiveTracks (Http.get "/tracks" (Json.field "Tracks" (Json.list trackDecoder)))


subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model.mode of
        Mode { leftButtonAction, rightButtonAction } ->
            case msg of
                SetActiveMode { newMode } ->
                    ( { model | mode = newMode }
                    , Cmd.none
                    )

                ClickOnWord { button, row, column, word } ->
                    ( (case button of
                        LeftMouseButton ->
                            leftButtonAction

                        RightMouseButton ->
                            rightButtonAction
                      )
                        model
                        row
                        column
                        word
                    , Cmd.none
                    )

                SetCellValue { row, column, newValue } ->
                    ( { model | tracks = modifyNth (column.setter newValue) row model.tracks }
                    , Cmd.none
                    )

                ReceiveTracks (Ok tracks) ->
                    ( { model | tracks = tracks }, Cmd.none )

                ReceiveTracks (Err _) ->
                    ( model, Cmd.none )


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
    Html.Events.onWithOptions "contextmenu" { defaultOptions | preventDefault = True } (Json.succeed msg)


onBlurWithTargetValue : (String -> msg) -> Html.Attribute msg
onBlurWithTargetValue tagger =
    Html.Events.on "blur" (Json.map tagger Html.Events.targetValue)


wordSpans row column s =
    List.intersperse (text " ")
        (List.indexedMap
            (\w word ->
                let
                    cow =
                        \button -> ClickOnWord { button = button, row = row, column = column, word = w }
                in
                span
                    [ styles [ Css.color (wordCaseColor (wordCase word)) ]
                    , Html.Events.onClick (cow LeftMouseButton)
                    , onContextMenu (cow RightMouseButton)
                    ]
                    [ text word ]
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


clickableTrackTr t track =
    tr []
        (List.indexedMap (\c colDef -> td [ styles tableStyles ] (wordSpans t colDef (colDef.getter track)))
            columnDefs
        )


editableTrackTr t track =
    tr []
        (List.indexedMap
            (\c colDef ->
                td [ styles tableStyles ]
                    [ input
                        [ value (colDef.getter track)
                        , styles
                            [ Css.width (pct 100)
                            , Css.boxSizing Css.borderBox
                            ]
                        , onBlurWithTargetValue
                            (\newValue ->
                                SetCellValue
                                    { row = t
                                    , column = colDef
                                    , newValue = newValue
                                    }
                            )
                        ]
                        []
                    ]
            )
            columnDefs
        )


trackTable trackTr model =
    table [ styles tableStyles ]
        (List.append
            [ tr []
                (List.map (\colDef -> th [ styles (List.append tableStyles [ Css.minWidth (px (toFloat colDef.width)) ]) ] [ text colDef.heading ])
                    columnDefs
                )
            ]
            (List.indexedMap trackTr model.tracks)
        )


view : Model -> Html.Html Msg
view model =
    case model.mode of
        Mode { trackTr } ->
            div [ styles [ Css.fontFamily Css.sansSerif ] ]
                [ modeSelector model, trackTable trackTr model ]


main =
    Html.program { init = init, view = view, update = update, subscriptions = subscriptions }
