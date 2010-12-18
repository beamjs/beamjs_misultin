-module(beamjs_misultin).
-export([exports/0,init/1]).

%% TODO: do something about it, it is a copy from erlv8
-record(erlv8_fun_invocation, {
		  is_construct_call = false,
		  holder,
		  this,
		  ref,
		  vm
		 }).

init(_VM) ->
	ok.

exports() ->
	erlv8_object:new([{"createServer", fun create_server/2}]).

create_server(#erlv8_fun_invocation{} = _Invocation, [Fun]) ->
	erlv8_object:new([{"_callback", Fun},{"listen", fun listen/2}]).

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
	F = This:get_value("_callback"),
	F:call([req_object(Req),resp_object(Req)]).

req_object(Req) ->
	erlv8_object:new([
					  {"method",Req:get(method)},
					  {"url",Req:get(uri)},
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
						   
