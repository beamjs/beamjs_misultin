-module(beamjs_misultin).
-export([exports/1,init/1]).

-include_lib("erlv8/include/erlv8.hrl").

-define(TIMEOUT, 5000).

init(_VM) ->
	ok.

exports(_VM) ->
	erlv8_object:new([{"createServer", fun create_server/2}]).

create_server(#erlv8_fun_invocation{ vm = VM} = I, [Fun]) ->
	Obj = erlv8_vm:taint(VM, erlv8_object:new([{"listen", fun listen/2}])),

	Global = I:global(),
	Require = Global:get_value("require"),
	EventsMod = Require:call(["events"]),
	EventEmitterCtor = EventsMod:get_value("EventEmitter"),

	EventEmitterCtor:call(Obj,[]),

	Prototype = Obj:get_prototype(),
	Prototype:set_prototype(beamjs_mod_events:prototype_EventEmitter()), %% FIXME?

	On = Obj:get_value("on"),

	Fun1 = fun(#erlv8_fun_invocation{},[Self, Request, Response]) ->
				   Fun:call([Request, Response]),
				   Self ! ok
		   end,

	Obj:call(On,["request", Fun1]),
	Obj.

listen(#erlv8_fun_invocation{ this = This } = _Invocation, [Port]) ->
	case lists:keyfind(misultin,1,application:loaded_applications()) of
		{misultin, _, _} ->
			ignore;
		false ->
			ok = application:start(misultin)
	end,
	spawn(fun () ->
				  {ok, _Pid} = misultin:start_link([{port, Port}, {loop, fun(Req) -> handle_http(This,Req) end}]),
				  receive X -> X end
		  end),
	erlv8_object:new([{port, Port}]).

handle_http(This,Req) ->
	Emit = This:get_value("emit"),
	This:call(Emit,["request",self(),req_object(Req),resp_object(Req)]),
	receive
		ok ->
			ok
	after ?TIMEOUT ->
			Req:stream(close)
	end.



req_object(Req) ->
	{abs_path, Path} = Req:get(uri),
	erlv8_object:new([
					  {"method",Req:get(method)},
					  {"path",Path},
					  {"headers",Req:get(headers)}
					 ]).

resp_object(Req) ->
	erlv8_object:new(
	  [
	   {"writeHead", fun (#erlv8_fun_invocation{ this = _This } = _Invocation, [Code, Headers]) ->
							 Req:stream(head, Code, Headers:proplist()),
							 undefined
					 end},
	   {"write", fun (#erlv8_fun_invocation{ this = _This } = _Invocation, [String]) ->
						 Req:stream(String),
						 undefined
				 end},
	   {"end", fun (#erlv8_fun_invocation{ this = _This } = _Invocation, [String]) ->
					   Req:stream(String),
					   Req:stream(close),
					   undefined;
				   (#erlv8_fun_invocation{ this = _This } = _Invocation, []) ->
					   Req:stream(close),
					   undefined
			   end}
	  ]).
						   
