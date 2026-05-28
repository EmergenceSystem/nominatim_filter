%%%-------------------------------------------------------------------
%%% @doc nominatim_filter supervisor.
%%%
%%% Supervises the nominatim_filter_server gen_server.
%%% @end
%%%-------------------------------------------------------------------
-module(nominatim_filter_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ServerSpec = #{
        id      => nominatim_filter_server,
        start   => {nominatim_filter_server, start_link, []},
        restart => permanent,
        type    => worker
    },
    {ok, {#{strategy => one_for_one, intensity => 3, period => 10},
          [ServerSpec]}}.
