-module(erlflow_xpdl_parser).
-include("/opt/local/lib/erlang/lib/xmerl-1.1.8/include/xmerl.hrl").

-export([start/0,process/1,net_sender_xpdl/2]).

start() ->
    register(net_sender_xpdl, spawn(erlflow_xpdl_parser, net_sender_xpdl, [[],[]])).

process(FName) -> 
    {R,_} = xmerl_scan:file(FName),
	io:format("reading XPDL file~n"),
    extract(R, [])
.

net_sender_xpdl(Id, Name) ->
	receive
        {setup_net, _Id, _Name} ->
            io:format("setting up net ~s~n", [_Id]),
            netsuper ! {add_net, _Id, _Name},
            net_sender_xpdl(_Id, _Name);
        {send_msg, Msg} ->
            io:format("sending a message to ~p network~n~n", [Id]),
            %io:format("sending message ~w to ~s network~n~n", [Msg,[Id]]),
            Id ! Msg,
            net_sender_xpdl(Id, Name);
        _else ->
            io:format("net_sender_xpdl Received:~p~n", [_else]),
            net_sender_xpdl(Id, Name)
 	end.
            

extract(R, L) when is_record(R, xmlElement) ->
    case R#xmlElement.name of
        'Package' ->
            io:format("reading Package~n"),
            lists:foldl(fun extract/2, L, R#xmlElement.content);
        
        'WorkflowProcesses' ->
            io:format("reading WorkflowProcesses~n"),
            lists:foldl(fun extract/2, L, R#xmlElement.content);
        
        'WorkflowProcess' ->
            io:format("reading WorkflowProcess~n"),
            FFunc = fun(X) -> X#xmlAttribute.name == 'Id' end,
            io:format("~p~n",[R#xmlElement.attributes]),
            I = hd(lists:filter(FFunc, R#xmlElement.attributes)),
            FFunc2 = fun(X) -> X#xmlAttribute.name == 'Name' end,
            V = hd(lists:filter(FFunc2, R#xmlElement.attributes)),
            Id = I#xmlAttribute.value,
            Name = V#xmlAttribute.value,
 			net_sender_xpdl ! {setup_net, list_to_atom(Id), Name},
            lists:foldl(fun extract/2, L, R#xmlElement.content);
        
        'Activities' ->
            lists:foldl(fun extract/2, L, R#xmlElement.content);
        
        'Activity' ->
            io:format("reading Activity~n"),
            FFuncId = fun(X) -> X#xmlAttribute.name == 'Id' end,
            io:format("~p~n",[R#xmlElement.attributes]),
            I = hd(lists:filter(FFuncId, R#xmlElement.attributes)),
            FFuncName = fun(X) -> X#xmlAttribute.name == 'Name' end,
            _V = lists:filter(FFuncName, R#xmlElement.attributes),
            _Vlength = lists:flatlength(_V),
            NetId = list_to_atom(I#xmlAttribute.value),
            if 
                _Vlength > 0 ->
            		V = hd(_V),
                    Msg = {add_place, NetId, V#xmlAttribute.value};
				_Vlength == 0 ->
                    Msg = {add_place, NetId, []}
			end,
            io:format("***net_sender_xpdl:~p~n", [{send_msg, Msg}]),
            net_sender_xpdl ! {send_msg, Msg},
            io:format("***net_sender_xpdl: done.~n"),
            io:format("***lists:foldl call.~n"),
            lists:foldl(fun extract/2, L, R#xmlElement.content);
        
        'Transition' ->
            io:format("reading Transition~n"),
            FFuncId = fun(X) -> X#xmlAttribute.name == 'Id' end,
            io:format("~p~n",[R#xmlElement.attributes]),
            I = hd(lists:filter(FFuncId, R#xmlElement.attributes)),
            FFuncName = fun(X) -> X#xmlAttribute.name == 'Name' end,
            V = lists:filter(FFuncName, R#xmlElement.attributes),
            Vlength = lists:flatlength(V),
            NetId = list_to_atom(I#xmlAttribute.value),
            if 
                Vlength > 0 ->
            		_V = hd(V),
                    Msg = {add_transition, NetId, _V#xmlAttribute.value};
				Vlength == 0 ->
                    Msg = {add_transition, NetId, []}
			end,
            io:format("***net_sender_xpdl:~p~n", [{send_msg, Msg}]),
            net_sender_xpdl ! {send_msg, Msg},
            io:format("***net_sender_xpdl: done.~n"),
            io:format("***lists:foldl call.~n"),
            
            FFuncFrom = fun(X) -> X#xmlAttribute.name == 'From' end,
            F = hd(lists:filter(FFuncFrom, R#xmlElement.attributes)),
            From = list_to_atom(F#xmlAttribute.value),
            
            FFuncTo = fun(X) -> X#xmlAttribute.name == 'To' end,
            T = hd(lists:filter(FFuncTo, R#xmlElement.attributes)),
            To = list_to_atom(T#xmlAttribute.value),
            
            From ! {output, NetId},
            NetId ! {input, From},
            NetId ! {output, To},
            To ! {input, NetId},
            
            lists:foldl(fun extract/2, L, R#xmlElement.content);

        
        %item ->
        %    ItemData = lists:foldl(fun extract/2, [], R#xmlElement.content),
        %    [ ItemData | L ];
        
        _ -> 
            io:format("reading element: ~s~n", [R#xmlElement.name]),
            lists:foldl(fun extract/2, L, R#xmlElement.content)
    end;

extract(#xmlText{parents=[{title,_},{channel,2},_], value=V}, L) ->
    [{channel, V}|L]; 

extract(#xmlText{parents=[{title,_},{item,_},_,_], value=V}, L) ->
    [{title, V}|L]; 

extract(#xmlText{parents=[{link,_},{item,_},_,_], value=V}, L) ->
    [{link, V}|L]; 

extract(#xmlText{parents=[{pubDate,_},{item,_},_,_], value=V}, L) ->
    [{pubDate, V}|L]; 

extract(#xmlText{parents=[{'dc:date',_},{item,_},_,_], value=V}, L) ->
    [{pubDate, V}|L];

extract(#xmlText{}, L) -> L.  

