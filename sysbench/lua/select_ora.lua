pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   local table_name
   set_vars()
   table_name = "sbtest".. (thread_id+1)
   stmt = db_prepare("SELECT pad FROM ".. table_name .." WHERE id=to_number(:x) and 'a' = :y")
   params = {}
   params[1] = '444'
   params[2] = 'a'
   db_bind_param(stmt, params)
end

function event(thread_id)
   local table_name
   params[1] = string.format("%d", sb_rand(1, oltp_table_size))
   params[2] = 'a'
   db_execute(stmt)
end
