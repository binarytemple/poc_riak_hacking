-module(myapp_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
  parsing_test:test_flattener(),
  ok.

stop(_State) ->
  ok.
