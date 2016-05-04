-- use case

--     ./sysbench_pg --test=lua/parallel_init_pg.lua \
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

--     ./sysbench_pg --test=lua/parallel_init_pg.lua \
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

--    ./sysbench_pg   \
--    --test=lua/oltp_pg.lua   \
--    --db-driver=pgsql   \
--    --pgsql-host=$PGDATA   \
--    --pgsql-port=1921   \
--    --pgsql-user=postgres   \
--    --pgsql-password=postgres   \
--    --pgsql-db=postgres   \
--    --oltp-tables-count=64   \
--    --oltp-table-size=1000000   \
--    --num-threads=64  \
--    --max-time=120  \
--    --max-requests=0 \
--    --report-interval=1 \
--    run

pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function thread_init(thread_id)
   set_vars()

   oltp_point_selects = 10  -- query 10 times
   random_points = 10       -- query id in (10 vars)
   oltp_simple_ranges = 1   --  query 1 times
   oltp_sum_ranges = 1      --  query 1 times
   oltp_order_ranges = 1    --  query 1 times
   oltp_distinct_ranges = 1   --  query 1 times
   oltp_index_updates = 1     --  query 1 times
   oltp_non_index_updates = 1   --  query 1 times
   oltp_range_size = 100        --  query between $1 and $1+100-1
   oltp_read_only = false       -- query delete,update,insert also

   local table_name
   local pars
   local vars
   local i

   begin_query = "BEGIN"
   commit_query = "COMMIT"

   table_name = "sbtest" .. (thread_id+1)

   -- select c from tbl where id = $1;
   db_query("prepare p1(int) as select c from " .. table_name .. " WHERE id=$1")

   -- select id,k,c,pad from tbl where id in ($1,...$n);
   pars = ""
   vars = ""
   for i = 1,random_points do
      pars = pars .. "int, "
      vars = vars .. "$" .. i .. ", "
   end
   pars = string.sub(pars, 1, string.len(pars) - 2)
   vars = string.sub(vars, 1, string.len(vars) - 2)
   db_query("prepare p2(" .. pars .. ") as select id,k,c,pad from " .. table_name .. " WHERE id in (" .. vars .. ")")

   -- select c from tbl where id between $1 and $2;
   db_query("prepare p3(int,int) as SELECT c FROM " .. table_name .. " WHERE id BETWEEN $1 and $2")
  
   -- select sum(k) from tbl where id between $1 and $2;
   db_query("prepare p4(int,int) as SELECT sum(k) FROM " .. table_name .. " WHERE id BETWEEN $1 and $2")

   -- select c from tbl where id between $1 and $2 order by c;
   db_query("prepare p5(int,int) as SELECT c FROM " .. table_name .. " WHERE id BETWEEN $1 and $2 order by c")

   -- select distinct c from tbl where id between $1 and $2 order by c;
   db_query("prepare p6(int,int) as SELECT distinct c FROM " .. table_name .. " WHERE id BETWEEN $1 and $2 order by c")

   -- update tbl set k=k+1 where id = $1;
   db_query("prepare p7(int) as update " .. table_name .. " set k=k+1 where id = $1")

   -- update tbl set c=$2 where id = $1;
   db_query("prepare p8(int,text) as update " .. table_name .. " set c=$2 where id = $1")

   -- delete from tbl where id = $1;
   db_query("prepare p9(int) as delete from " .. table_name .. " where id = $1")

   -- insert into tbl(id, k, c, pad) values ($1,$2,$3,$4);
   db_query("prepare p10(int,int,text,text) as insert into " .. table_name .. "(id, k, c, pad) values ($1,$2,$3,$4)")
end

function event(thread_id)
   local i
   local evars
   local range_start
   local c_val
   local pad_val

   db_query(begin_query)

   for i=1, oltp_point_selects do
     db_query("execute p1(" .. sb_rand(1, oltp_table_size) .. ")")
   end

   evars = ""
   for i = 1,random_points do
     evars = evars .. sb_rand(1, oltp_table_size) .. ", "
   end
   evars = string.sub(evars, 1, string.len(evars) - 2)
   db_query("execute p2(" .. evars .. ")")

   for i=1, oltp_simple_ranges do
      range_start = sb_rand(1, oltp_table_size)
      db_query("execute p3(" .. range_start .. "," .. (range_start + oltp_range_size - 1) .. ")")
   end
  
   for i=1, oltp_sum_ranges do
      range_start = sb_rand(1, oltp_table_size)
      db_query("execute p4(" .. range_start .. "," .. (range_start + oltp_range_size - 1) .. ")")
   end
   
   for i=1, oltp_order_ranges do
      range_start = sb_rand(1, oltp_table_size)
      db_query("execute p5(" .. range_start .. "," .. (range_start + oltp_range_size - 1) .. ")")
   end

   for i=1, oltp_distinct_ranges do
      range_start = sb_rand(1, oltp_table_size)
      db_query("execute p6(" .. range_start .. "," .. (range_start + oltp_range_size - 1) .. ")")
   end

   if not oltp_read_only then

     for i=1, oltp_index_updates do
        db_query("execute p7(" .. sb_rand(1, oltp_table_size) .. ")")
     end

     for i=1, oltp_non_index_updates do
        c_val = sb_rand_str("###########-###########-###########-###########-###########-###########-###########-###########-###########-###########")
        db_query("execute p8(" .. sb_rand(1, oltp_table_size) .. ", '" .. c_val .. "')")
     end

     -- delete then insert
     i = sb_rand(1, oltp_table_size)
     c_val = sb_rand_str([[
###########-###########-###########-###########-###########-###########-###########-###########-###########-###########]])
     pad_val = sb_rand_str([[
###########-###########-###########-###########-###########]])

     db_query("execute p9(" .. i .. ")")
     db_query("execute p10" .. string.format("(%d, %d, '%s', '%s')",i, sb_rand(1, oltp_table_size) , c_val, pad_val) )

   end -- oltp_read_only

   db_query(commit_query)

end
