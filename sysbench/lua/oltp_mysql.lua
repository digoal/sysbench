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

--     ./sysbench_mysql --test=lua/oltp_mysql.lua \
--       --db-driver=mysql \
--       --mysql-host=ip \
--       --mysql-port=1921 \
--       --mysql-user=mysql \
--       --mysql-password=mysql \
--       --mysql-db=mysql \
--       --oltp-tables-count=64 \
--       --oltp-table-size=1000000 \
--       --num-threads=64 \
--       --max-time=120  \
--       --max-requests=0 \
--       --report-interval=1 \
--       run

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

   table_name = "sbtest" .. (thread_id+1)

   if (db_driver == "mysql" and mysql_table_engine == "myisam") then
      begin_query = "LOCK TABLES sbtest WRITE"
      commit_query = "UNLOCK TABLES"
   else
      begin_query = "BEGIN"
      commit_query = "COMMIT"
   end

   --  p1 : select c from tbl where id = ?;
   p1 = db_prepare("select c from " .. table_name .. " WHERE id=?")
   params = {}
   params[1] = 1
   db_bind_param(p1, params)

   --  p2 : select id,k,c,pad from tbl where id in (?, ....);
   points = ""
   for i = 1,random_points do
      points = points .. "?, "
   end

   -- Get rid of last comma and space.
   points = string.sub(points, 1, string.len(points) - 2)

   p2 = db_prepare( "select id,k,c,pad from " .. table_name .. " where id in (" .. points .. ")" )
   params = {}
   for j = 1,random_points do
      params[j] = 1
   end
   db_bind_param(p2, params)

   --  p3 : select c from tbl where id between ? and ?;
   p3 = db_prepare("SELECT c FROM " .. table_name .. " WHERE id BETWEEN ? and ?")
   params = {}
   params[1] = 1
   params[2] = 2
   db_bind_param(p3, params)

   --  p4 : select sum(k) from tbl where id between ? and ?;
   p4 = db_prepare("SELECT sum(k) FROM " .. table_name .. " WHERE id BETWEEN ? and ?")
   params = {}
   params[1] = 1
   params[2] = 2
   db_bind_param(p4, params)

   --  p5 : select c from tbl where id between ? and ? order by c;
   p5 = db_prepare("SELECT c FROM " .. table_name .. " WHERE id BETWEEN ? and ? order by c")
   params = {}
   params[1] = 1
   params[2] = 2
   db_bind_param(p5, params)

   --  p6 : select distinct c from tbl where id between ? and ? order by c;
   p6 = db_prepare("SELECT distinct c FROM " .. table_name .. " WHERE id BETWEEN ? and ? order by c")
   params = {}
   params[1] = 1
   params[2] = 2
   db_bind_param(p6, params)

   --  p7 : update tbl set k=k+1 where id = ?;
   p7 = db_prepare("UPDATE " .. table_name .. " set k=k+1 where id = ?")
   params = {}
   params[1] = 1
   db_bind_param(p7, params)

   --  p8 : update tbl set c=? where id = ?;
   p8 = db_prepare("UPDATE " .. table_name .. " set c = ? where id = ?")
   params = {}
   params[1] = 'test'
   params[2] = 1
   db_bind_param(p8, params)

   --  p9 : delete from tbl where id = ?;
   p9 = db_prepare("UPDATE " .. table_name .. " set k=k+1 where id = ?")
   params = {}
   params[1] = 1
   db_bind_param(p9, params)

   --  p10 : insert into tbl(id, k, c, pad) values (?,?,?,?);
   p10 = db_prepare("insert into " .. table_name .. "(id, k, c, pad) values (?,?,?,?)")
   params = {}
   params[1] = 1
   params[2] = 1
   params[3] = 'test'
   params[4] = 'test'
   db_bind_param(p10, params)

end

function event(thread_id)
   local i
   local table_name
   local range_start
   local c_val
   local pad_val
   local query

   db_query(begin_query)

   for i=1, oltp_point_selects do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      db_execute(p1, params)
   end

   params = {}
   for i = 1,random_points do
      params[i] = sb_rand(oltp_table_size / num_threads * thread_id, oltp_table_size / num_threads * (thread_id + 1))
   end
   db_execute(p2, params)

   for i=1, oltp_simple_ranges do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      params[2] = ( params[1] + oltp_range_size - 1 )
      db_execute(p3, params)
   end
  
   for i=1, oltp_sum_ranges do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      params[2] = ( params[1] + oltp_range_size - 1 )
      db_execute(p4, params)
   end
   
   for i=1, oltp_order_ranges do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      params[2] = ( params[1] + oltp_range_size - 1 )
      db_execute(p5, params)
   end

   for i=1, oltp_distinct_ranges do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      params[2] = ( params[1] + oltp_range_size - 1 )
      db_execute(p6, params)
   end

   if not oltp_read_only then

   for i=1, oltp_index_updates do
      params = {}
      params[1] = sb_rand(1, oltp_table_size)
      db_execute(p7, params)
   end

   for i=1, oltp_non_index_updates do
      params = {}
      params[1] = sb_rand_str("###########-###########-###########-###########-###########-###########-###########-###########-###########-###########")
      params[2] = sb_rand(1, oltp_table_size)
      db_execute(p8, params)
   end

   -- delete then insert
   i = sb_rand(1, oltp_table_size)
   params = {}
   params[1] = i
   db_execute(p9, params)
   
   c_val = sb_rand_str([[
###########-###########-###########-###########-###########-###########-###########-###########-###########-###########]])
   pad_val = sb_rand_str([[
###########-###########-###########-###########-###########]])

   params[2] = sb_rand(1, oltp_table_size)
   params[3] = c_val
   params[4] = pad_val
   db_execute(p10, params)

   end -- oltp_read_only

   db_query(commit_query)

end
