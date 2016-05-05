-- use case

--   must install postgresql first, and set PATH with psql.

--   you must create tablespace first, and set tbs= how many tablespace created . (like tbs0 tbs1 tbs2 ... in all testing file system)

--     ./sysbench_pg --test=lua/parallel_init_pg_bytbs.lua \
--       --db-driver=pgsql \
--       --pgsql-host=$PGDATA \
--       --pgsql-port=1921 \
--       --pgsql-user=postgres \
--       --pgsql-password=postgres \
--       --pgsql-db=postgres \
--       --oltp-tables-count=64 \
--       --oltp-table-size=1000000 \
--       --num-threads=64 \
--       cleanup

--     ./sysbench_pg --test=lua/parallel_init_pg_bytbs.lua \
--       --db-driver=pgsql \
--       --pgsql-host=$PGDATA \
--       --pgsql-port=1921 \
--       --pgsql-user=postgres \
--       --pgsql-password=postgres \
--       --pgsql-db=postgres \
--       --oltp-tables-count=64 \
--       --oltp-table-size=1000000 \
--       --num-threads=64 \
--       run

--  set how many tablespace you created, like 3 means you have created tbs0, tbs1, and tbs2. 
tbs=3

pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function copydata(table_id)
  local query

  query = [[
CREATE UNLOGGED TABLE sbtest]] .. table_id .. [[ (
id SERIAL NOT NULL,
k INTEGER,
c CHAR(120) DEFAULT '' NOT NULL,
pad CHAR(60) DEFAULT '' NOT NULL,
PRIMARY KEY (id)
) tablespace tbs]] .. (table_id%tbs)

  db_query(query)

  os.execute ('rm -f sbtest' .. table_id .. '.dat')
  os.execute ('mknod sbtest' .. table_id .. '.dat p')
  os.execute ('./gendata ' .. oltp_table_size .. ' >> sbtest'..table_id ..'.dat &')
  os.execute ('export PGPASSWORD=' .. pgsql_password .. '; cat sbtest' .. table_id .. '.dat | psql -h ' .. pgsql_host .. ' -p ' .. pgsql_port .. ' -U ' .. pgsql_user .. ' -d ' .. pgsql_db .. ' -c "copy sbtest' .. table_id .. ' from stdin with csv"')
  os.execute ('rm -f sbtest' .. table_id .. '.dat')
end

function create_index(table_id)
  db_query("select setval('sbtest" .. table_id .. "_id_seq', " .. (oltp_table_size+1) .. ")" )
  db_query("CREATE INDEX k_" .. table_id .. " on sbtest" .. table_id .. "(k) tablespace tbs" .. (table_id%tbs) )
end

function thread_init(thread_id)
   set_vars()
   local i

   print("thread prepare  " .. thread_id)

   for i=thread_id+1, oltp_tables_count, num_threads  do
     copydata(i)
     create_index(i)
   end
end

function event(thread_id)
   --  os.exit()
end
