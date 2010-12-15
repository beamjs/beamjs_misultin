-module(beamjs_misultin).
-export([exports/0]).

%% TODO: do something about it, it is a copy from erlv8
-record(erlv8_fun_invocation, {
		  is_construct_call = false,
		  holder,
		  this
		 }).

exports() ->
	[{"createServer", fun create_server/3}].

create_server(_Script, #erlv8_fun_invocation{} = _Invocation, Fun) ->
	[{"_callback", Fun},{"listen", fun listen/3}].

listen(_Script, #erlv8_fun_invocation{ this = This } = _Invocation, Port) ->
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
	[{port, Port}].

handle_http(This,Req) ->
	F = proplists:get_value("_callback",This),
	F:call([Req,resp_object(Req)]).

resp_object(Req) ->
	[
	 {"writeHead", fun (_Script,#erlv8_fun_invocation{ this = _This } = _Invocation, Code, Headers) ->
						   Req:stream(head, Code, Headers),
						   undefined
				   end},
	 {"end", fun (_Script,#erlv8_fun_invocation{ this = _This } = _Invocation, String) ->
					 Req:stream(String),
					 Req:stream(close),
					 undefined
				   end}
	 ].
						   
