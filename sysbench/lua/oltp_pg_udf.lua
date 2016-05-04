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
   oltp_read_only = "false"       -- query delete,update,insert also

   begin_query = "BEGIN"
   commit_query = "COMMIT"

   table_name = "sbtest" .. (thread_id+1)

query = 
"create or replace function fun_" .. table_name .. [[(
   oltp_point_selects int,
   random_points int,
   oltp_simple_ranges int,
   oltp_sum_ranges int,
   oltp_order_ranges int,
   oltp_distinct_ranges int,
   oltp_index_updates int,
   oltp_non_index_updates int,
   oltp_range_size int,
   oltp_read_only boolean,
   oltp_table_size int,
   c_val text,
   pad_val text
) returns void as $$
declare
  i int;
  vk int;
  rand int;
begin
  -- select c from tbl where id = $1;
  for i in 1..oltp_point_selects loop
    rand := abs(trunc(random()*oltp_table_size))::int;
    perform c from ]] .. table_name .. [[ WHERE id=rand;
  end loop;

   -- select id,k,c,pad from tbl where id in ($1,...$n);
   perform id,k,c,pad from ]] .. table_name .. [[ WHERE id in (select abs(trunc(random()*oltp_table_size))::int from generate_series(1, random_points) );

   -- select c from tbl where id between $1 and $2;
   for i in 1..oltp_simple_ranges loop
      rand := abs(trunc(random()*oltp_table_size))::int;
      perform c FROM ]] .. table_name .. [[ WHERE id BETWEEN rand and (rand + oltp_range_size - 1);
   end loop;

   -- select sum(k) from tbl where id between $1 and $2;
   for i in 1..oltp_sum_ranges loop
      rand := abs(trunc(random()*oltp_table_size))::int;
      perform sum(k) FROM ]] .. table_name .. [[ WHERE id BETWEEN rand and (rand + oltp_range_size - 1);
   end loop;

   -- select c from tbl where id between $1 and $2 order by c;
   for i in 1..oltp_order_ranges loop
      rand := abs(trunc(random()*oltp_table_size))::int;
      perform c FROM ]] .. table_name .. [[ WHERE id BETWEEN rand and (rand + oltp_range_size - 1) order by c;
   end loop;

   -- select distinct c from tbl where id between $1 and $2 order by c;
   for i in 1..oltp_distinct_ranges loop
      rand := abs(trunc(random()*oltp_table_size))::int;
      perform distinct c FROM ]] .. table_name .. [[ WHERE id BETWEEN rand and (rand + oltp_range_size - 1) order by c;
   end loop;

   if oltp_read_only then
     return;
   else

     -- update tbl set k=k+1 where id = $1;
     for i in 1..oltp_index_updates loop
        rand := abs(trunc(random()*oltp_table_size))::int;
        update ]] .. table_name .. [[ set k=k+1 where id = rand;
     end loop;

     -- update tbl set c=$2 where id = $1;
     for i in 1..oltp_non_index_updates loop
        rand := abs(trunc(random()*oltp_table_size))::int;
	update ]] .. table_name .. [[ set c=c_val where id = rand;
     end loop;

     -- delete then insert
     i := abs(trunc(random()*oltp_table_size))::int;
     vk := abs(trunc(random()*oltp_table_size))::int;

     -- delete from tbl where id = $1;
     delete from ]] .. table_name .. [[ where id = i;
     -- insert into tbl(id, k, c, pad) values ($1,$2,$3,$4);
     insert into ]] .. table_name .. [[(id, k, c, pad) values (i,vk,c_val,pad_val);

   end if; -- oltp_read_only
   return;
end;
$$ language plpgsql strict;
]]

   db_query(query)

   -- select fun_table_name($1,...$13);
   db_query("prepare p1(int,int,int,int,int,int,int,int,int,boolean,int,text,text) as SELECT fun_" .. table_name .. "($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)")

end

function event(thread_id)
   local c_val
   local pad_val

   c_val = sb_rand_str("###########-###########-###########-###########-###########-###########-###########-###########-###########-###########")
   pad_val = sb_rand_str("###########-###########-###########-###########-###########")

   db_query(begin_query)

   db_query( "execute p1(" .. oltp_point_selects .. "," ..  random_points  .. "," ..  oltp_simple_ranges  .. "," ..  oltp_sum_ranges  .. "," ..  oltp_order_ranges  .. "," ..  oltp_distinct_ranges  .. "," ..  oltp_index_updates  .. "," ..  oltp_non_index_updates  .. "," ..  oltp_range_size  .. ",'" ..  oltp_read_only  .. "'," ..  oltp_table_size  .. ",'" ..  c_val  .. "','" ..  pad_val .. "')" )

   db_query(commit_query)

end
