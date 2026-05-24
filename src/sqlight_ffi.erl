-module(sqlight_ffi).

-export([
    status/0, query/3, exec/2, enable_load_extension/2, auto_extension/1,
    coerce_value/1, coerce_blob/1, null/0, open/1, close/1
]).

open(Name) ->
    case esqlite3:open(unicode:characters_to_list(Name)) of
        {ok, Connection} -> {ok, Connection};
        {error, Code} -> 
            Code1 = sqlight:error_code_from_int(Code),
            {error, {sqlight_error, Code1, <<>>, -1}}
    end.

close(Connection) ->
    case esqlite3:close(Connection) of
        ok -> {ok, nil};
        {error, Code} -> to_error(Connection, Code)
    end.

query(Sql, Connection, Arguments) when is_binary(Sql) ->
    case esqlite3:q(Connection, Sql, Arguments) of
        {error, Code} -> to_error(Connection, Code);
        Rows -> {ok, lists:map(fun erlang:list_to_tuple/1, Rows)}
    end.

exec(Sql, Connection) ->
    case esqlite3:exec(Connection, Sql) of
        {error, Code} -> to_error(Connection, Code);
        ok -> {ok, nil}
    end.

enable_load_extension(Connection, Enabled) ->
    case esqlite3:enable_load_extension(Connection, Enabled) of
        {error, Code} when is_integer(Code) -> to_error(Connection, Code);
        {error, Reason} -> extension_error(Reason);
        ok -> {ok, nil}
    end.

auto_extension(Extension) ->
    case esqlite3:auto_extension(Extension) of
        {error, Code} when is_integer(Code) -> extension_error(Code);
        {error, Reason} -> extension_error(Reason);
        ok -> {ok, nil}
    end.

stats(#{used := Used, highwater := Highwater}) ->
    {stats, Used, Highwater}.

status() ->
    #{
        memory_used := MemoryUsed,
        pagecache_used := PagecacheUsed,
        pagecache_overflow := PagecacheOverflow,
        malloc_size := MallocSize,
        parser_stack := ParserStack,
        pagecache_size := PagecacheSize,
        malloc_count := MallocCount
    } = esqlite3:status(),
    {status_info,
        stats(MemoryUsed),
        stats(PagecacheUsed),
        stats(PagecacheOverflow),
        stats(MallocSize),
        stats(ParserStack),
        stats(PagecacheSize),
        stats(MallocCount)
    }.

coerce_value(X) -> X.
coerce_blob(Bin) -> {blob, Bin}.
null() -> undefined.

to_error(Connection = {esqlite3, _}, Code) when is_integer(Code) ->
    #{errmsg := Message, error_offset := Offset} = esqlite3:error_info(Connection),
    Error = {sqlight_error, sqlight:error_code_from_int(Code), Message, Offset},
    {error, Error}.

extension_error(Code) when is_integer(Code) ->
    Error = {sqlight_error, sqlight:error_code_from_int(Code), <<"SQLite extension API failed">>, -1},
    {error, Error};
extension_error(Reason) when is_atom(Reason) ->
    Error = {sqlight_error, sqlight:error_code_from_int(1), atom_to_binary(Reason, utf8), -1},
    {error, Error}.
