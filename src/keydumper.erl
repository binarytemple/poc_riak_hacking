%%%-------------------------------------------------------------------
%%% @author bryanhunt
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. Jun 2015 11:18
%%%-------------------------------------------------------------------
-module(keydumper).
-author("bryanhunt").

%% API
-export([list_cask/2, list_all/1]).


list_cask(Vnode, OutFile) ->
  Fold_data = fun(Handle) ->
    FoldFun = fun(Bytes, X, Y, {ok, Acc}) ->
      io:format(OutFile, "~p",[Handle]),
      case Bytes of
        <<1:7, 0:1,Sz:16/integer,Bucket:Sz/bytes, Key/binary>> ->
          io:format(OutFile, "~s/~s~n", [binary_to_list(Bucket),binary_to_list(Key)]), {ok, Acc + 1};
        <<1:7, 1:1,Sz:16/integer, Type:Sz/bytes, BSz:16/integer,Bucket:BSz/bytes,Key/binary>> ->
          io:format(OutFile, "~s/~s/~s~n", [binary_to_list(Type), binary_to_list(Bucket),binary_to_list(Key)]), {ok, Acc + 1};
        Other ->
          io:format(OutFile, "unknown type - ~5000p.~n", [{Other,X,Y}]), {ok, Acc + 1}
      end
    end,
    try bitcask_fileops:fold_keys(Handle, FoldFun, {ok, 0}, datafile) of
      {ok, A} -> A;
      {error, E} -> {error, E}
    catch
      _Error ->
%%         {error, io_lib:format("~s~s~n", ["Corrupted datafile: ", bitcask_fileops:datafile_name(Handle)])}
        {error, io_lib:format("~s~s~n", ["Corrupted datafile: ", Handle])}
    end
  end,

  Test_data = fun(Datafile) ->
    case catch bitcask_fileops:open_file(Datafile) of
      {ok, Handle} ->
        KeyCount = Fold_data(Handle),
        bitcask_fileops:close(Handle),
        {ok, KeyCount};
      {error, Reason} ->
        {error, io_lib:format("Couldn't open bitcask data file ~s with reason ~p~n", [Datafile, Reason])};
      _Error ->
        {error, io_lib:format("Couldn't open bitcask data file ~s~n", [Datafile])}
    end
  end,

  List_bitcask = fun(Dir) ->
    case file:list_dir(Dir) of
      {ok, Files} ->
        [Test_data(filename:absname(F, Dir)) || F <- Files,
          filename:extension(F) == ".data"];
      {error, Reason} ->
        {error, io_lib:format("Error listing directory ~s: ~s", [Dir, Reason])};
      Dirlist -> {error, Dirlist}
    end
  end,


  {ok, Dpath} = application:get_env(bitcask, data_root),
  case List_bitcask(filename:absname(Vnode, Dpath)) of
    {error, Reason} ->
      io:format("Error: ~s~n", [Reason]);
    Rawlist ->
      try lists:flatten(Rawlist) of
        A -> A
      catch
        A -> {error, A}
      end
  end

.

list_all(OutFileName) ->
  {ok, Fhandle} = file:open(OutFileName, [write]),
  Rawcounts = [list_cask(io_lib:format("~B", [P]), Fhandle) || {riak_kv_vnode, P, _Pid} <- riak_core_vnode_manager:all_vnodes()],
  file:close(Fhandle),
  {KeyCount, Errors} = lists:foldl(fun(Count, {Total, Errors}) -> case Count of {ok, C} -> {Total + C, Errors}; _ ->
    {Total, [Count | Errors]} end end, {0, []}, lists:flatten(Rawcounts)),
  io:format("Listed ~B keys to file ~s~n", [KeyCount, OutFileName]),
  [io:format("Error: ~p~n", [Err]) || Err <- Errors],
  ok
.