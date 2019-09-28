-module(mod_filter_msg).
-author('Hivedevs~drey').

-behaviour(gen_mod).

-export(
  [
    start/2,
    init/2,
    stop/1,
    on_filter_packet/1,
    now_z/0,
    get_timestamp/0
  ]
).

-define(PROCNAME, ?MODULE).

-define(RtoM(Name, Record), lists:foldl(fun({I, E}, Acc) -> Acc#{E => element(I, Record) } end, #{}, lists:zip(lists:seq(2, (record_info(size, Name))), (record_info(fields, Name))))).


% -include("ejabberd.hrl").
-include("xmpp.hrl").
-include("logger.hrl").
-include("mod_muc_room.hrl").

start(Host, Opts) ->

    register(?PROCNAME,spawn(?MODULE, init, [Host, Opts])),
    ok.


init(Host, _Opts) ->
    inets:start(),
    ssl:start(),
    ejabberd_hooks:add(filter_packet, global, ?MODULE, on_filter_packet, 0),
    ok.

stop(Host) ->
    ejabberd_hooks:delete(filter_packet, global, ?MODULE, on_filter_packet, 0),
    ok.


fetchmsgs(MsgId, MsgTo, MsgFrom, MsgBody, MsgResource, MsgType, MsgTS, ExtraParams) ->
	MsgFromWithResource = MsgFrom ++ "/" ++ MsgResource,

	JsonListBody = [
		{<<"msgId">>, valueToBinary(MsgId)},
		{<<"msgTo">>, valueToBinary(MsgTo)},
		{<<"msgFrom">>, valueToBinary(MsgFromWithResource)},
		{<<"msgBody">>, valueToBinary(MsgBody)},
		{<<"msgType">>, valueToBinary(MsgType)},
		{<<"msgResource">>, valueToBinary(MsgResource)},
		{<<"msgTimestamp">>, valueToBinary(MsgTS)},
		{<<"extraParams">>, ExtraParams}
	],
  
  	JsonBody = jsone:encode(JsonListBody),

	Method = post,
	URL = "http://localhost:3000/fetchmsg",
	Header = [],
	RequestType = "application/json",
	HTTPOptions = [],
	Options = [],
	sendHttpRequest(Method, {URL, Header, RequestType, JsonBody}, HTTPOptions, Options),
ok.

now_to_microseconds({Mega, Sec, Micro}) ->
    %%Epoch time in milliseconds from 1 Jan 1970
    ?INFO_MSG("now_to_milliseconds Mega ~p Sec ~p Micro ~p~n", [Mega, Sec, Micro]),
    (Mega*1000000 + Sec)*1000000 + Micro.


get_timestamp() ->
	{Mega, Sec, Micro} = os:timestamp(),
	(Mega*1000000 + Sec)*1000 + round(Micro/1000).


now_z() ->
  TS = os:timestamp(),
    {{Year,Month,Day},{Hour,Minute,Second}} =
      calendar:now_to_universal_time(TS),
    io_lib:format("~4w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ",
      [Year,Month,Day,Hour,Minute,Second]).


extraParamsToList(EXP) when is_list(EXP)->
	EP1 = lists:nth(1,EXP),
	EP = getextraparams(0,length(EXP),EXP,[]),
	% error
	if
	(tuple_size(EP) == 4) ->
		{_,X,_,EPL} = EP,
	ok;
	true ->
		X = <<"">>,
		EPL = <<"">>,
	ok
	end,
	if
	(X == <<"extraParams">>) ->
		LTP = looptolist(0,length(EPL),EPL,[]);
	true ->
		LTP = []
	end,
	LTP;
extraParamsToList(EXP) when true->
  [].


getextraparams(0,0,_,_) ->
	{};
getextraparams(S,E,List,Param) when S < E ->
	EP = lists:nth(S+1,List),
	if
	(tuple_size(EP) == 4) ->
		{_,X,_,EPL} = EP,
	ok;
	true ->
		X = <<"">>,
		EPL = <<"">>,
	ok
	end,
	if
	(X == <<"extraParams">>) ->
		getextraparams(length(List),length(List),List,EP);
	true ->
		getextraparams(S+1,length(List),List,EP)
	end;
getextraparams(S,E,List, Param) when S == E ->
	Param.



looptolist(0,0,_,_) ->
	[];
looptolist(S,E,List,Param) when S < E ->
	{_,Key,[],ValTemp} = lists:nth(S+1,List),
	Val = if
		(length(ValTemp) == 0) -> <<"">>;
		true -> [{_,Y}] = ValTemp,Y
	end,
	WE  = {Key, Val},
	Param2 = lists:append(Param, [WE]),
	looptolist(S+1,E,List,Param2);
looptolist(S,E,List, Param) when S == E ->
	Param.


%------------------------------------------------------------------------------------%
% for filter packet from ejabberd hook event, all types of messages will filter here %
%------------------------------------------------------------------------------------%
on_filter_packet(Stanza) when (element(1, Stanza) == message) ->

	%% for checking only 
	StanzaString=lists:flatten(io_lib:format("~p", [Stanza])),
	MessageType = Stanza#message.type,

	if
      (MessageType /= error) ->
      	MessageId = Stanza#message.id,
		TimeStamp = now_to_microseconds(erlang:now()),
		BodySection = element(8,Stanza),
		MessageLang = Stanza#message.lang,

		From = element(5,Stanza),
		To = element(6,Stanza),

		FromString = ctl(From#jid.luser) ++ "@" ++ ctl(From#jid.lserver),
		ToString = ctl(To#jid.luser) ++ "@" ++ ctl(To#jid.lserver),
		ServerHost = From#jid.lserver,
		FromResource = ctl(From#jid.resource),

		Data10 = element(10,Stanza),

    	if
    	  (MessageType == groupchat) ->
			[{_,_,TupleBodyMsg}] = BodySection,

			ExtraParamsToListGet = extraParamsToList(Data10),
			ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

			fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, ExtraParamsToJsonGet),

    	  ok;
    	  (MessageType == chat) ->
    	    [{_,_,TupleBodyMsg}] = BodySection,

    	    ExtraParamsToListGet = extraParamsToList(Data10),
			ExtraParamsToJsonGet = jsone:encode(ExtraParamsToListGet),

			fetchmsgs(MessageId, ToString, FromString, TupleBodyMsg, FromResource, MessageType, TimeStamp, ExtraParamsToJsonGet),
    	  ok;
    	  true ->
    	  ok
    	end,
	
	ok;
    true ->
    ok
  end,

Stanza;

on_filter_packet(Stanza) ->
Stanza.


sendHttpRequest(Method, Request, HTTPOptions, Options)->
	R = httpc:request(Method, Request, HTTPOptions, Options),
ok.


%---------------------------------------------------------------------------------%
% CTL or Convert to List function, from binary to list i.e. <<2,1>> becomes [2,1] %
%	from atom to list i.e. atom1 becomes "atom1"								  %
%---------------------------------------------------------------------------------%
ctl(BinaryInput) when is_binary(BinaryInput)->
	binary_to_list(BinaryInput);
ctl(BinaryInput) when is_atom(BinaryInput)->
	atom_to_list(BinaryInput);
ctl(BinaryInput) when true->
	BinaryInput.

%---------------------------------------------------------------------------------%
% value to Binary, convert some values for list, atom & tuple to binary.          %
%---------------------------------------------------------------------------------%

valueToBinary(P) when is_list(P)->
	list_to_binary(P);
valueToBinary(P) when is_atom(P)->
	X = atom_to_list(P),
	valueToBinary(X);
valueToBinary(P) when is_tuple(P)->
	X = tuple_to_list(P),
	valueToBinary(X);
valueToBinary(P) when true->
	P.



