port module Main exposing (Model, Msg(..), ensureTrailingNewline, init, main, toJs, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Parser
import Html.Parser.Util exposing (toVirtualDom)
import Http exposing (Error(..))
import Json.Decode as Decode
import Json.Encode as Enc
import Parser exposing (deadEndsToString)
import String exposing (endsWith)



-- ---------------------------
-- PORTS
-- ---------------------------


port toJs : String -> Cmd msg



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { plaintextScreenplay : String
    , renderedScreenplay : String
    , serverMessage : String
    }


init : String -> ( Model, Cmd Msg )
init flags =
    ( { plaintextScreenplay = flags, serverMessage = "", renderedScreenplay = exampleHTML }, Cmd.none )



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = ChangeScreenplay String
    | RenderBtnPress
    | RenderResponse (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        ChangeScreenplay s ->
            ( { model | plaintextScreenplay = s }, Cmd.none )

        RenderBtnPress ->
            ( model, postScreenplay model.plaintextScreenplay )

        RenderResponse res ->
            case res of
                Ok r ->
                    ( { model | renderedScreenplay = r }, Cmd.none )

                Err err ->
                    ( { model | serverMessage = "Error: " ++ httpErrorToString err }, Cmd.none )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        BadUrl _ ->
            "BadUrl"

        Timeout ->
            "Timeout"

        NetworkError ->
            "NetworkError"

        BadStatus _ ->
            "BadStatus"

        BadBody s ->
            "BadBody: " ++ s



-- ---------------------------
-- HTTP
-- ---------------------------


postScreenplay : String -> Cmd Msg
postScreenplay s =
    -- Send HTTP request to the tunnel HTTP API, expect response to just be a string
    Http.post
        { url = "https://adamchalmers.com/fountain"
        , body =
            Http.jsonBody <|
                Enc.object
                    [ ( "screenplay", Enc.string <| ensureTrailingNewline s )
                    ]
        , expect = Http.expectString RenderResponse
        }


ensureTrailingNewline s =
    if endsWith "\n" s then
        s

    else
        s ++ "\n"



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ header []
            [ h1 [] [ text "Fountain Screenplay Editor" ]
            , renderBtn
            ]
        , div [ class "editor editor-in" ]
            [ userTextInput model
            , br [] []
            ]
        , div [ class "editor editor-out" ]
            (outputPane model)
        , footerDiv
        ]


footerDiv =
    footer []
        [ p []
            [ text "Made by "
            , link "https://twitter.com/adam_chal" "@adam_chal"
            , text ". Parsing done in Rust via my "
            , a [ href "https://crates.io/crates/fountain", target "_blank" ] [ text "Fountain" ]
            , text " crate, which is compiled into WebAssembly and run in the browser via "
            , a [ href "https://blog.cloudflare.com/introducing-wrangler-cli/" ] [ text "Cloudflare Workers" ]
            , text "."
            , br [] []
            , text "Frontend written in Elm. Functionality also available via "
            , a [ href "https://github.com/adamchalmers/fountain-rs", target "_blank" ] [ text "CLI" ]
            ]
        ]


link to txt =
    a [ href to ] [ text txt ]


renderBtn =
    button
        [ class "pure-button pure-button-primary", onClick RenderBtnPress ]
        [ text "Render screenplay" ]


userTextInput model =
    -- Users type their plaintext here
    textarea
        [ onInput ChangeScreenplay
        , rows 40
        , cols 40
        ]
        [ text model.plaintextScreenplay ]


outputPane model =
    -- Displays the rendered screenplay or errors.
    if model.serverMessage == "" then
        case Html.Parser.run model.renderedScreenplay of
            Ok html ->
                toVirtualDom html

            Err errs ->
                [ text <| deadEndsToString errs ]

    else
        [ text <| model.serverMessage ]



-- ---------------------------
-- MAIN
-- ---------------------------


main : Program String Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Elm 0.19 starter"
                , body = [ view m ]
                }
        , subscriptions = \_ -> Sub.none
        }


exampleHTML =
    """<h1 class='titlepage'>Alien</h1>
<h3 class='titlepage'>By Dan O'Bannon</h3>

<p class='page-break'></p>

<p class='scene'>INT. MESS</p>
<p class='action'>The entire crew is seated. Hungrily swallowing huge portions of artificial food. The cat eats from a dish on the table.</p>
<p class='speaker'>KANE</p>
<p class='dialogue'>First thing I'm going to do when we get back is eat some decent food.</p>
"""
