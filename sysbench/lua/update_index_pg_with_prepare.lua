pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   local table_name
   set_vars()
   table_name = "sbtest".. ((thread_id % oltp_tables_count) +1 )
   db_query("PREPARE testplan (int) AS UPDATE ".. table_name .." SET k=k+1 WHERE id=$1")
end

function event(thread_id)
   local c_val
   local query
   query = "EXECUTE testplan(" .. sb_rand(1, oltp_table_size) .. ")"
   db_query("BEGIN")
   db_query(query)
   db_query("COMMIT")
end
