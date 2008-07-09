-module(efappmod).
-author('klacke@bluetail.com').

-include("/opt/local/lib/yaws/include/yaws_api.hrl").
-include("erlflow_db.hrl").

-compile(export_all).
-record(myopaque, {userid}).

out(A) ->	
    H = A#arg.headers,
    C = H#headers.cookie,
    case yaws_api:find_cookie_val("erlflow", C) of
        [] ->
            M = #myopaque{},
            Cookie = yaws_api:new_cookie_session(M),
            CO = yaws_api:setcookie("erlflow",Cookie,"/"),
            [{content, "text/plain",  prepare_response({A#arg.appmoddata, A#arg.querydata, Cookie})}, CO];
        Cookie	 ->
            {content, "text/plain",  prepare_response({A#arg.appmoddata, A#arg.querydata, Cookie})} 
    end.

prepare_response({Path, QueryStr, Cookie}) ->
    PathParts = string:tokens(Path,"/"),
    First = lists:flatten(lists:sublist(PathParts,1,1)),
    io:format("~p~n", [Cookie]),
    case yaws_api:cookieval_to_opaque(Cookie) of
        {ok, OP} -> 
            case OP#myopaque.userid of
                undefined ->
                    case First of
                        "user" ->
                            PartsCount = length(PathParts) - 1,
                            io:format("PartsCount:~w~n", [PartsCount]),
                            case PartsCount of
                                0 ->
                                    "invalid request";
                                1 ->
                                    UserId = lists:flatten(lists:sublist(PathParts,2,1)),
                                    Password = lookup_qsvalue(password, QueryStr),
                                    io:format("QueryStr=~p~n", [QueryStr]),
                                    io:format("UserId=~p~n", [UserId]),
                                    io:format("Password=~p~n", [Password]),
                                    {ok, {obj, RUser}} = ecouch:doc_get("users", UserId),
                                    PwdSearch = lists:keysearch("password", 1, RUser),
                                    Role = lists:keysearch("roles", 1, RUser),
                                    io:format("User=~p~n", [RUser]),
                                    case PwdSearch of
                                        {value,{"password",PWD}} ->
                                            SEq = string:equal(Password, erlang:binary_to_list(PWD)),
                                            if
                                                SEq ->
                                                    OP2 = OP#myopaque{userid = UserId},
                                                    yaws_api:replace_cookie_session(Cookie, OP2),
                                                    "login accepted";
                                                true ->
                                                    "access denied"
                                            end;
                                    	false ->
                    						"access denied"
                                    end;
                                _Other ->  "invalid request"
                            end;  
                        _Other -> "access denied"
                    end;
                UserId ->
                    case First of
                        "nets" ->
                            netsuper ! {get_status, self()},
                            receive Networks -> Net = Networks end,
                            NetworksList = [{networks, prepare_json([Net])}],
                            ktuo_json:encode(NetworksList);
                        "net" ->
                            PartsCount = length(PathParts) - 1,
                            io:format("PartsCount:~w~n", [PartsCount]),
                            case PartsCount of
                                0 ->
                                    "invalid request";
                                1 ->
                                    Network =  list_to_atom(lists:flatten(lists:sublist(PathParts,2,1))),
                                    NetworkPid = whereis(Network),
                                    if 
                                        is_pid(NetworkPid) ->
                                            io:format("~w~n",[NetworkPid]),
                                            NetworkPid !  {get_status, self()},
                                            receive Response -> [Info, Places, Transitions, Participants] = Response end,
                                            NetworkList = [{info, prepare_json2(Info)}, {places, prepare_json(Places)},{transitions,prepare_json(Transitions)},{participants,prepare_json(Participants)}],
                                            ktuo_json:encode(NetworkList);
                                        true -> io_lib:format("invalid request: network doesn't exists. ID=~p~n",[Network])
                                    end;
                                _Other -> "invalid request"
                            end;
                        "activity" ->
                            PartsCount = length(PathParts) - 1,
                            io:format("PartsCount:~w~n", [PartsCount]),
                            case PartsCount of
                                0 ->
                                    "invalid request";
                                1 ->
                                    Activity =  list_to_atom(lists:flatten(lists:sublist(PathParts,2,1))),
                                    ActivityPid = whereis(Activity),
                                    if 
                                        is_pid(ActivityPid) ->
                                            io:format("~w~n",[ActivityPid]),
                                            ActivityPid !  {get_status, self()},
                                            receive Response -> {status, [ID, Name, Inputs, Outputs, Tokens, Info, FormFields]} = Response end,
                                            ReponseList = [{id, {string, ID}}, {name, {string, Name}}, {info, prepare_json(Info)}, {fields, [prepare_json3(FormFields)]}],
                                            io:format("~p~n", [ReponseList]),
                                            ktuo_json:encode(ReponseList);
                                        true -> io_lib:format("invalid request: activity doesn't exists. ID=~p~n",[Activity])
                                    end;
                                _Other -> "invalid request"
                            end;
                        "performer" ->
                            PartsCount = length(PathParts) - 1,
                            io:format("PartsCount:~w~n", [PartsCount]),
                            case PartsCount of
                                0 ->
                                    "invalid request";
                                1 ->
                                    Performer =  list_to_atom(lists:flatten(lists:sublist(PathParts,2,1))),
                                    PerformerPid = whereis(Performer),
                                    if 
                                        is_pid(PerformerPid) ->
                                            io:format("~w~n",[PerformerPid]),
                                            PerformerPid !  {get_activity, self()},
                                            receive Response -> {activities,  Activities} = Response end,
                                            ReponseList = [{activities, [prepare_json2(Activities)]}],
                                            io:format("~p~n", [ReponseList]),
                                            ktuo_json:encode(ReponseList);
                                        true -> io_lib:format("invalid request: activity doesn't exists. ID=~p~n",[Performer])
                                    end;
                                _Other -> "invalid request"
                            end;
                        _Other -> "invalid request"
                    end
            end;
        {error, Message} ->
            io_lib:format("session invalid: ~s~n", [Message])
    end.

prepare_json({Key, Value}) ->
    [{id, {string, Key}},{name,{string, Value}}];
prepare_json([Head | Tail]) ->
    lists:merge([prepare_json(Head)],prepare_json(Tail));
prepare_json([]) -> [].

prepare_json2({Key, Value}) ->
    {Key, {string, Value}};
prepare_json2([Head | Tail]) ->
    lists:merge([prepare_json2(Head)],prepare_json2(Tail));
prepare_json2([]) -> [].

prepare_json3({FieldId,FieldName,[{length,Length}]}) ->
    [{id,{string, FieldId}},{name,{string,FieldName}},{length,{string,Length}}];
prepare_json3([Head | Tail]) ->
    lists:merge(prepare_json3(Head),prepare_json3(Tail));
prepare_json3([]) -> [].

lookup_qsvalue(Key, QueryStr) when is_atom(Key) ->
    lookup_qsvalue(atom_to_list(Key), QueryStr);
lookup_qsvalue(Key, QueryStr) ->
    ValueKeyPairs = string:tokens(QueryStr, "&"),
    lookup_qskeyvalue(Key, ValueKeyPairs).
lookup_qskeyvalue(Key, [Head | Tail]) ->
    [_Key | _Value] = string:tokens(Head, "="),
    SEq = string:equal(Key, _Key),
    if
        SEq ->
            lists:flatten(_Value);
        true ->
            lookup_qskeyvalue(Key, Tail)
    end;
lookup_qskeyvalue(Key, []) -> Key, [].




