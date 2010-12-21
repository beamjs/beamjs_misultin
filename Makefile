all: compile

deps:
	@./rebar get-deps

compile:
	@./rebar compile skip_deps=true

clean:
	@./rebar clean skip_deps=true