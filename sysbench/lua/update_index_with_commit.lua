pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   set_vars()
end

function event(thread_id)
   local table_name
   table_name = "sbtest".. sb_rand_uniform(1, oltp_tables_count)
   db_query("BEGIN")
   rs = db_query("UPDATE ".. table_name .." SET k=k+1 WHERE id=" .. sb_rand(1, oltp_table_size))
   db_query("COMMIT")
end
