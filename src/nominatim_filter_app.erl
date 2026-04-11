%%%-------------------------------------------------------------------
%%% @doc OpenStreetMap Nominatim geocoding agent.
%%%
%%% Converts a place name or address to geographic coordinates and
%%% returns embryos with location data (lat, lon, display_name).
%%%
%%% Deduplication by URL is handled upstream by the Emquest pipeline.
%%%
%%% === Capability cascade ===
%%%
%%%   base_capabilities/0 extends em_filter:base_capabilities().
%%%
%%% Handler contract: handle/2 (Body, Memory) -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(nominatim_filter_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([handle/2, base_capabilities/0]).

-define(SEARCH_URL,
    "https://nominatim.openstreetmap.org/search"
    "?format=json&limit=10&addressdetails=0&q=").

%%====================================================================
%% Capability cascade
%%====================================================================

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"nominatim">>, <<"geocoding">>,
                                      <<"openstreetmap">>, <<"geo">>,
                                      <<"location">>].

%%====================================================================
%% Application behaviour
%%====================================================================

start(_Type, _Args) ->
    em_filter:start_agent(nominatim_filter, ?MODULE, #{
        capabilities => base_capabilities()
    }),
    {ok, self()}.

stop(_State) ->
    em_filter:stop_agent(nominatim_filter).

%%====================================================================
%% Agent handler
%%====================================================================

handle(Body, Memory) when is_binary(Body) ->
    {generate_embryo_list(Body), Memory};
handle(_Body, Memory) ->
    {[], Memory}.

%%====================================================================
%% Geocoding
%%====================================================================

generate_embryo_list(JsonBinary) ->
    {Query, Timeout} = extract_params(JsonBinary),
    fetch_results(Query, Timeout).

extract_params(JsonBinary) ->
    try json:decode(JsonBinary) of
        Map when is_map(Map) ->
            Query   = binary_to_list(maps:get(<<"value">>, Map,
                          maps:get(<<"query">>, Map,
                          maps:get(<<"address">>, Map, <<"">>)))),
            Timeout = case maps:get(<<"timeout">>, Map, undefined) of
                undefined            -> 10;
                T when is_integer(T) -> T;
                T when is_binary(T)  -> binary_to_integer(T)
            end,
            {Query, Timeout};
        _ ->
            {binary_to_list(JsonBinary), 10}
    catch
        _:_ -> {binary_to_list(JsonBinary), 10}
    end.

fetch_results("", _) -> [];
fetch_results(Query, Timeout) ->
    Url = lists:flatten(io_lib:format("~s~s", [?SEARCH_URL, uri_string:quote(Query)])),
    Headers = [{"User-Agent", "nominatim_filter/1.0 (EmergenceSystem)"},
               {"Accept-Language", "en"}],
    case httpc:request(get, {Url, Headers},
                       [{timeout, Timeout * 1000},
                        {ssl, [{verify, verify_none}]}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} ->
            parse_results(Body);
        _ ->
            []
    end.

parse_results(JsonBin) ->
    try json:decode(JsonBin) of
        Results when is_list(Results) ->
            lists:filtermap(fun build_embryo/1, Results);
        _ ->
            []
    catch
        _:_ -> []
    end.

build_embryo(#{<<"display_name">> := Name, <<"lat">> := Lat, <<"lon">> := Lon}) ->
    OsmUrl = lists:flatten(io_lib:format(
        "https://www.openstreetmap.org/search?query=~s",
        [uri_string:quote(binary_to_list(Name))])),
    {true, #{
        <<"properties">> => #{
            <<"url">>          => list_to_binary(OsmUrl),
            <<"resume">>       => Name,
            <<"latitude">>     => Lat,
            <<"longitude">>    => Lon,
            <<"source">>       => <<"nominatim.openstreetmap.org">>
        }
    }};
build_embryo(_) ->
    false.
