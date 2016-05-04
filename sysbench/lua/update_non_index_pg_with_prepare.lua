pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   local table_name
   set_vars()
   table_name = "sbtest".. (thread_id+1)
   db_query("PREPARE testplan (text, int) AS UPDATE ".. table_name .." SET c=$1 WHERE id=$2")
end

function event(thread_id)
   local c_val
   local query
   c_val = sb_rand_str("###########-###########-###########-###########-###########-###########-###########-###########-###########-###########")
   query = "EXECUTE testplan('" .. c_val .. "'," .. sb_rand(1, oltp_table_size) ..')'
   db_query("BEGIN")
   db_query(query)
   db_query("COMMIT")
end
