module Pages.Pops exposing (Model, Msg, page)

import Color
import Dict exposing (Dict)
import Effect exposing (Effect)
import Element as E exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (..)
import Element.Font as Font
import Element.Input as Input
import Gen.Params.Pops exposing (Params)
import Page
import Request
import Shared
import Time
import UI
import View exposing (View)


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page shared req =
    Page.advanced
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type SimStatus
    = Running
    | Paused


type alias Model =
    { simStatus : SimStatus
    , currentTickType : TickType
    , world : World
    , polygons : Dict PolygonId Polygon
    , companies : Dict CompanyId Company
    }


type alias CompanyId =
    String


type alias Company =
    { id : CompanyId
    , applicantQueue : List PolygonId
    }


type alias RunConfig =
    { initialPopulationCount : Int
    , numTicks : Int
    }


type alias Year =
    Float


type alias World =
    { currentYear : Year
    }


type alias PolygonId =
    String


type alias Age =
    Float


type EmploymentStatus
    = Unemployed
    | Employed


type alias Polygon =
    { id : PolygonId
    , gender : Gender
    , employmentStatus : EmploymentStatus
    , color : Color
    , age : Age
    }


type Gender
    = Male
    | Female


type Color
    = Purple
    | Blue
    | Green
    | Pink
    | Gray


resetWorld : World
resetWorld =
    { currentYear = 0.0
    }


init : ( Model, Effect Msg )
init =
    ( { simStatus = Paused
      , currentTickType = WorldUpdates
      , world = resetWorld
      , polygons =
            Dict.fromList
                [ ( "p1", { id = "p1", gender = Male, color = Purple, age = 0.0, employmentStatus = Unemployed } )
                , ( "p2", { id = "p2", gender = Male, color = Blue, age = 0.0, employmentStatus = Unemployed } )
                , ( "p3", { id = "p3", gender = Female, color = Green, age = 0.0, employmentStatus = Unemployed } )
                , ( "p4", { id = "p4", gender = Male, color = Purple, age = 0.0, employmentStatus = Unemployed } )
                , ( "p5", { id = "p5", gender = Female, color = Pink, age = 0.0, employmentStatus = Unemployed } )
                , ( "p6", { id = "p6", gender = Female, color = Blue, age = 0.0, employmentStatus = Unemployed } )
                , ( "p7", { id = "p7", gender = Female, color = Purple, age = 0.0, employmentStatus = Unemployed } )
                , ( "p8", { id = "p8", gender = Male, color = Pink, age = 0.0, employmentStatus = Unemployed } )
                , ( "p9", { id = "p9", gender = Female, color = Gray, age = 0.0, employmentStatus = Unemployed } )
                ]
      , companies = Dict.fromList [ ( "c1", { id = "c1", applicantQueue = [] } ) ]
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = ToggleSimStatus
    | ResetWorld
    | Tick Time.Posix


type TickType
    = WorldUpdates
    | PolygonUpdates
    | CompanyUpdates


nextTickType : TickType -> TickType
nextTickType tt =
    case tt of
        WorldUpdates ->
            PolygonUpdates

        PolygonUpdates ->
            CompanyUpdates

        CompanyUpdates ->
            WorldUpdates


applyToCompany : Polygon -> Company -> Company
applyToCompany p c =
    let
        newQueue =
            c.applicantQueue ++ [ p.id ]
    in
    { c | applicantQueue = newQueue }


dt : Float
dt =
    -- the number of years per tick
    1.0


updatePolygons : Model -> Dict PolygonId Polygon
updatePolygons model =
    let
        polygonsAge : PolygonId -> Polygon -> Polygon
        polygonsAge pid p =
            { p | age = p.age + dt }
    in
    Dict.map polygonsAge model.polygons


updateCompanies : Model -> Dict CompanyId Company
updateCompanies model =
    let
        -- TODO: more than 1 company
        theCompany : Maybe Company
        theCompany =
            Dict.get "c1" model.companies

        newCompanies : Dict CompanyId Company
        newCompanies =
            case theCompany of
                Just company ->
                    let
                        adultPolygonsApplyForWork : Polygon -> Maybe ( PolygonId, CompanyId )
                        adultPolygonsApplyForWork p =
                            case p.employmentStatus of
                                Unemployed ->
                                    -- TODO: Must apply to more than 1 company
                                    if p.age >= 18.0 then
                                        Just ( p.id, company.id )

                                    else
                                        Nothing

                                Employed ->
                                    Nothing

                        applicantList : List (Maybe ( PolygonId, CompanyId ))
                        applicantList =
                            List.map adultPolygonsApplyForWork (Dict.values model.polygons)

                        updateCompanyQueue : CompanyId -> Company -> Company
                        updateCompanyQueue _ c =
                            let
                                removeNothingFromList : List (Maybe a) -> List a
                                removeNothingFromList list =
                                    List.filterMap identity list

                                applicantList_ =
                                    removeNothingFromList applicantList

                                companyList : List PolygonId
                                companyList =
                                    List.map (\( pid, _ ) -> pid) <| List.filter (\( pid, cid ) -> c.id == cid) applicantList_
                            in
                            { c | applicantQueue = c.applicantQueue ++ companyList }
                    in
                    Dict.map updateCompanyQueue model.companies

                Nothing ->
                    model.companies
    in
    newCompanies


updateWorld : Model -> World
updateWorld model =
    let
        world =
            model.world
    in
    { world | currentYear = model.world.currentYear + dt }


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ToggleSimStatus ->
            let
                newStatus =
                    case model.simStatus of
                        Paused ->
                            Running

                        Running ->
                            Paused
            in
            ( { model | simStatus = newStatus }, Effect.none )

        Tick _ ->
            let
                ( newWorld, newCompanies, newPolygons ) =
                    case model.currentTickType of
                        WorldUpdates ->
                            ( updateWorld model, model.companies, model.polygons )

                        PolygonUpdates ->
                            ( model.world, model.companies, updatePolygons model )

                        CompanyUpdates ->
                            ( model.world, updateCompanies model, model.polygons )
            in
            ( { model
                | world = newWorld
                , companies = newCompanies
                , polygons = newPolygons
                , currentTickType = nextTickType model.currentTickType
              }
            , Effect.none
            )

        ResetWorld ->
            let
                newWorld =
                    resetWorld
            in
            ( { model | world = newWorld, simStatus = Paused }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.simStatus of
        Paused ->
            Sub.none

        Running ->
            Time.every 1 Tick



-- VIEW


view : Model -> View Msg
view model =
    { title = "Pops"
    , body =
        [ layout
            [ E.width E.fill
            , E.height E.fill
            ]
            (elements model)
        ]
    }


content : Model -> Element Msg
content model =
    let
        label =
            case model.simStatus of
                Running ->
                    "Pause Sim."

                Paused ->
                    "Resume Sim."

        playPauseButton =
            Input.button
                [ padding 5
                , alignRight
                , Border.width 2
                , Border.rounded 6
                , Border.color UI.palette.blue
                , Background.color UI.palette.lightBlue
                ]
                { onPress = Just ToggleSimStatus
                , label = text label
                }

        resetButton =
            Input.button
                [ padding 5
                , alignRight
                , Border.width 2
                , Border.rounded 6
                , Border.color UI.palette.blue
                , Background.color UI.palette.lightBlue
                ]
                { onPress = Just ResetWorld
                , label = text "Reset."
                }
    in
    row
        [ padding 10
        , spacing 5
        ]
        [ resetButton
        , playPauseButton
        ]


elements : Model -> Element Msg
elements model =
    let
        header : Element msg
        header =
            row
                [ E.width E.fill
                , padding 10
                , spacing 10
                , Background.color UI.palette.lightGrey
                ]
                [ logo
                , el [ alignRight ] <| text "Header"
                , el [ alignRight ] <| text "Stuff"
                , el [ alignRight ] <| text "Goes"
                , el [ alignRight ] <| text "Here"
                ]

        logo : Element msg
        logo =
            el
                [ E.width <| E.px 80
                , E.height <| E.px 40
                , Border.width 2
                , Border.rounded 6
                , Border.color UI.palette.blue
                ]
                (el
                    [ centerX
                    , centerY
                    ]
                 <|
                    text "LOGO"
                )

        footer : Element msg
        footer =
            row
                [ E.width E.fill
                , padding 5
                , Background.color UI.palette.lightGrey
                , Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 }
                , Border.color UI.palette.lightGrey
                ]
                [ row
                    [ alignLeft
                    ]
                    [ el [ alignLeft ] <| text "Footer stuff"
                    ]
                ]
    in
    E.column
        [ E.width E.fill
        , E.height E.fill
        , Background.color UI.palette.darkCharcoal
        , Font.size 12
        ]
        [ header
        , content model
        , footer
        ]
