%%--------------------------------------------------------------------
%% Copyright (c) 2019-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_limiter_manager).

-behaviour(gen_server).

-include_lib("emqx/include/logger.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%% API
-export([ start_link/0, start_server/1, find_bucket/1
        , find_bucket/3, insert_bucket/2, insert_bucket/4
        , make_path/3, restart_server/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

-export_type([path/0]).

-type path() :: list(atom()).
-type limiter_type() :: emqx_limiter_schema:limiter_type().
-type zone_name() :: emqx_limiter_schema:zone_name().
-type bucket_name() :: emqx_limiter_schema:bucket_name().

%% counter record in ets table
-record(bucket, { path :: path()
                , bucket :: bucket_ref()
                }).

-type bucket_ref() :: emqx_limiter_bucket_ref:bucket_ref().

-define(TAB, emqx_limiter_counters).

%%--------------------------------------------------------------------
%%  API
%%--------------------------------------------------------------------
-spec start_server(limiter_type()) -> _.
start_server(Type) ->
    emqx_limiter_server_sup:start(Type).

-spec restart_server(limiter_type()) -> _.
restart_server(Type) ->
    emqx_limiter_server_sup:restart(Type).

-spec find_bucket(limiter_type(), zone_name(), bucket_name()) ->
          {ok, bucket_ref()} | undefined.
find_bucket(Type, Zone, BucketId) ->
    find_bucket(make_path(Type, Zone, BucketId)).

-spec find_bucket(path()) -> {ok, bucket_ref()} | undefined.
find_bucket(Path) ->
    case ets:lookup(?TAB, Path) of
        [#bucket{bucket = Bucket}] ->
            {ok, Bucket};
        _ ->
            undefined
    end.

-spec insert_bucket(limiter_type(),
                    zone_name(),
                    bucket_name(),
                    bucket_ref()) -> boolean().
insert_bucket(Type, Zone, BucketId, Bucket) ->
    inner_insert_bucket(make_path(Type, Zone, BucketId),
                        Bucket).


-spec insert_bucket(path(), bucket_ref()) -> true.
insert_bucket(Path, Bucket) ->
    inner_insert_bucket(Path, Bucket).

-spec make_path(limiter_type(), zone_name(), bucket_name()) -> path().
make_path(Type, Name, BucketId) ->
    [Type, Name, BucketId].

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
          {error, Error :: {already_started, pid()}} |
          {error, Error :: term()} |
          ignore.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%--------------------------------------------------------------------
%%  gen_server callbacks
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
          {ok, State :: term(), Timeout :: timeout()} |
          {ok, State :: term(), hibernate} |
          {stop, Reason :: term()} |
          ignore.
init([]) ->
    _ = ets:new(?TAB, [ set, public, named_table, {keypos, #bucket.path}
                      , {write_concurrency, true}, {read_concurrency, true}
                      , {heir, erlang:whereis(emqx_limiter_sup), none}
                      ]),
    {ok, #{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
          {reply, Reply :: term(), NewState :: term()} |
          {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
          {reply, Reply :: term(), NewState :: term(), hibernate} |
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
          {stop, Reason :: term(), NewState :: term()}.
handle_call(Req, _From, State) ->
    ?LOG(error, "Unexpected call: ~p", [Req]),
    {reply, ignore, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: term(), NewState :: term()}.
handle_cast(Req, State) ->
    ?LOG(error, "Unexpected cast: ~p", [Req]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
          {noreply, NewState :: term()} |
          {noreply, NewState :: term(), Timeout :: timeout()} |
          {noreply, NewState :: term(), hibernate} |
          {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(Info, State) ->
    ?LOG(error, "Unexpected info: ~p", [Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
                State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
                  State :: term(),
                  Extra :: term()) -> {ok, NewState :: term()} |
          {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
                    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%--------------------------------------------------------------------
%%  Internal functions
%%--------------------------------------------------------------------
-spec inner_insert_bucket(path(), bucket_ref()) -> true.
inner_insert_bucket(Path, Bucket) ->
    ets:insert(?TAB,
               #bucket{path = Path, bucket = Bucket}).
