-- use case

--     ./sysbench_mysql --test=lua/parallel_init_mysql.lua \
--       --db-driver=mysql \
--       --mysql-host=ip \
--       --mysql-port=1921 \
--       --mysql-user=mysql \
--       --mysql-password=mysql \
--       --mysql-db=mysql \
--       --oltp-tables-count=64 \
--       --oltp-table-size=1000000 \
--       --num-threads=64 \
--       cleanup

--     ./sysbench_mysql --test=lua/parallel_init_mysql.lua \
--       --db-driver=mysql \
--       --mysql-host=ip \
--       --mysql-port=1921 \
--       --mysql-user=mysql \
--       --mysql-password=mysql \
--       --mysql-db=mysql \
--       --oltp-tables-count=64 \
--       --oltp-table-size=1000000 \
--       --num-threads=64 \
--       run


pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   local index_name
   local i
   set_vars()
   
   print("thread prepare"..thread_id)

   if (oltp_secondary) then
     index_name = "KEY xid"
   else
     index_name = "PRIMARY KEY"
   end

   for i=thread_id+1, oltp_tables_count, num_threads  do
     table_name = "sbtest" .. (thread_id+1)
     print( "Creating table " .. table_name )

     query = [[
CREATE TABLE ]] .. table_name .. [[ (
id INTEGER UNSIGNED NOT NULL ]] ..
((oltp_auto_inc and "AUTO_INCREMENT") or "") .. [[,
k INTEGER UNSIGNED DEFAULT '0' NOT NULL,
c CHAR(120) DEFAULT '' NOT NULL,
pad CHAR(60) DEFAULT '' NOT NULL,
]] .. index_name .. [[ (id)
) /*! ENGINE = ]] .. mysql_table_engine ..
" MAX_ROWS = " .. myisam_max_rows .. " */"

     if (oltp_auto_inc) then
       db_bulk_insert_init("INSERT INTO " .. table_name .. "(k, c, pad) VALUES")
     else
       db_bulk_insert_init("INSERT INTO " .. table_name .. "(id, k, c, pad) VALUES")
     end

     for j = 1,oltp_table_size do
       c_val = sb_rand_str([[
###########-###########-###########-###########-###########-###########-###########-###########-###########-###########]])
       pad_val = sb_rand_str([[
###########-###########-###########-###########-###########]])

       if (oltp_auto_inc) then
         db_bulk_insert_next("(" .. sb_rand(1, oltp_table_size) .. ", '".. c_val .."', '" .. pad_val .. "')")
       else
         db_bulk_insert_next("("..j.."," .. sb_rand(1, oltp_table_size) .. ",'".. c_val .."', '" .. pad_val .. "'  )")
       end
     end
     db_bulk_insert_done()
   end
end

function event(thread_id)

end
