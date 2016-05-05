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
--    --test=lua/oltp_pg_udf.lua   \
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

   begin_query = "BEGIN"
   commit_query = "COMMIT"

   table_name = "sbtest" .. (thread_id+1)

   local query
   local tmp

query = 
"create or replace function fun_" .. table_name .. [[  
(
  rand int[],
  rand_range int[],
  rand_c_val text[],
  rand_pad_val text
) returns void as $$
declare  
begin  
]]

  -- select c from tbl where id = $1; 
  for i=1,oltp_point_selects do
    tmp = " perform c from " .. table_name .. " WHERE id=rand[" .. i .. "];  "
    query = query .. tmp
  end

   -- select id,k,c,pad from tbl where id in ($1,...$n);
   tmp = " "
   for i=oltp_point_selects+1, oltp_point_selects+random_points do
     tmp = tmp .. "rand[" .. i .. "], "
   end
   tmp = string.sub(tmp, 1, string.len(tmp) - 2)
   query = query .. " perform id,k,c,pad from " .. table_name .. " WHERE id in ( " .. tmp .. " ); "

   -- select c from tbl where id between $1 and $2;
   for i=1, 2*oltp_simple_ranges, 2 do
      tmp = " perform c FROM " .. table_name .. " WHERE id BETWEEN rand_range[" .. i .. "] and " .. " rand_range[" .. i+1 .. "]; "
      query = query .. tmp
   end

   -- select sum(k) from tbl where id between $1 and $2;
   for i=2*oltp_simple_ranges+1, 2*(oltp_simple_ranges+oltp_sum_ranges), 2 do
      tmp = " perform sum(k) FROM " .. table_name .. " WHERE id BETWEEN rand_range[" .. i .. "] and " .. " rand_range[" .. i+1 .. "]; "
      query = query .. tmp
   end

   -- select c from tbl where id between $1 and $2 order by c;
   for i=2*(oltp_simple_ranges+oltp_sum_ranges)+1, 2*(oltp_simple_ranges+oltp_sum_ranges+oltp_order_ranges), 2 do
      tmp = " perform c FROM " .. table_name .. " WHERE id BETWEEN rand_range[" .. i .. "] and " .. " rand_range[" .. i+1 .. "] order by c; "
      query = query .. tmp
   end

   -- select distinct c from tbl where id between $1 and $2 order by c;
   for i=2*(oltp_simple_ranges+oltp_sum_ranges+oltp_order_ranges)+1, 2*(oltp_simple_ranges+oltp_sum_ranges+oltp_order_ranges+oltp_distinct_ranges), 2 do
      tmp = " perform distinct c FROM " .. table_name .. " WHERE id BETWEEN rand_range[" .. i .. "] and " .. " rand_range[" .. i+1 .. "] order by c; "
      query = query .. tmp
   end

   if not oltp_read_only then
     -- update tbl set k=k+1 where id = $1;
     for i=oltp_point_selects+random_points+1, oltp_point_selects+random_points+oltp_index_updates do
        tmp = " update " .. table_name .. " set k=k+1 where id = rand[" .. i .. "]; "
        query = query .. tmp
     end

     -- update tbl set c=$2 where id = $1;
     for i=oltp_point_selects+random_points+oltp_index_updates+1, oltp_point_selects+random_points+oltp_index_updates+oltp_non_index_updates do
        tmp = " update " .. table_name .. " set c=rand_c_val[" .. i-oltp_point_selects-random_points-oltp_index_updates .. "] where id = rand[" .. i .. "]; "
        query = query .. tmp
     end

     -- delete from tbl where id = $1;
     tmp = "delete from " .. table_name .. " where id = rand[" .. oltp_point_selects+random_points+oltp_index_updates+oltp_non_index_updates+1 .. "] ; "
     query = query .. tmp
     -- insert into tbl(id, k, c, pad) values ($1,$2,$3,$4);
     tmp = "insert into " .. table_name .. "(id, k, c, pad) values (rand[" .. oltp_point_selects+random_points+oltp_index_updates+oltp_non_index_updates+1 .. "], rand[" .. oltp_point_selects+random_points+oltp_index_updates+oltp_non_index_updates+2 .. "], rand_c_val[" .. oltp_non_index_updates+1 .. "], rand_pad_val); "
     query = query .. tmp
   end

   tmp = [[ return;  end;  $$ language plpgsql strict; ]]
   query = query .. tmp

   db_query(query)

   -- select fun_table_name($1,...$4);
   db_query("prepare p1(int[],int[],text[],text) as SELECT fun_" .. table_name .. "($1,$2,$3,$4)")

end

function event(thread_id)
   local rand_cnt = oltp_point_selects+random_points+oltp_index_updates+oltp_non_index_updates+2
   local rand_cnt_range = 2*(oltp_simple_ranges+oltp_sum_ranges+oltp_order_ranges+oltp_distinct_ranges)
   local rand_cnt_c_val = oltp_non_index_updates+1
   local rand="array["
   local rand_range="array["
   local range_val
   local rand_c_val="array['"
   local rand_pad_val

   for i=1,rand_cnt do
     rand = rand .. sb_rand(1, oltp_table_size) .. ", "
   end
   rand= string.sub(rand, 1, string.len(rand) - 2) .. "]"
   
   for i=1,rand_cnt,2 do
     range_val = sb_rand(1, oltp_table_size)
     rand_range = rand_range .. range_val .. ", " .. range_val+oltp_range_size-1 .. ", "
   end
   rand_range= string.sub(rand_range, 1, string.len(rand_range) - 2) .. "]"

   for i=1,rand_cnt_c_val do
     rand_c_val = rand_c_val .. sb_rand_str("###########-###########-###########-###########-###########-###########-###########-###########-###########-###########") .. "', '"
   end
   rand_c_val= string.sub(rand_c_val, 1, string.len(rand_c_val) - 3) .. "]"

   rand_pad_val = sb_rand_str("###########-###########-###########-###########-###########")

   db_query(begin_query)

   db_query( "execute p1(" .. rand .. "," ..  rand_range  .. "," ..  rand_c_val  .. ",'" ..  rand_pad_val .. "')" )

   db_query(commit_query)

end
