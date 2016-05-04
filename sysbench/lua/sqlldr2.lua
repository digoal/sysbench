pathtest = string.match(test, "(.*/)") or ""

dofile(pathtest .. "common.lua")

function sqlload(table_id)
  local ctl
  local f
  local i
  local c_val
  local pad_val
  local content
  local query

  query = [[
CREATE TABLE sbtest]] .. table_id .. [[ (
id INTEGER NOT NULL,
k INTEGER,
c CHAR(120) DEFAULT '' NOT NULL,
pad CHAR(60) DEFAULT '' NOT NULL,
PRIMARY KEY (id)
) ]]

  db_query(query)

  content = [[
unrecoverable
load   data
infile   'sbtest]] .. table_id .. [[.dat'
append   into   table   sbtest]]..table_id..[[
 fields terminated by ","
(id,k,c,pad)
]]

  f = assert(io.open('sbtest'..table_id .. '.ctl', 'w'))
  f:write(content)
  f:close()
  os.execute('mknod sbtest'..table_id..'.dat p')
  os.execute ('./gendata ' .. oltp_table_size .. ' >> sbtest'..table_id ..'.dat &')
  os.execute ('sqlldr -skip_unusable_indexes userid='..oracle_user.. '/'..oracle_password .. ' control=sbtest'..table_id ..'.ctl direct=true')
end

function create_index_and_seq(table_id)
  db_query("CREATE SEQUENCE sbtest" .. table_id .. "_seq CACHE 10 START WITH ".. (oltp_table_size+1) )
  db_query([[CREATE TRIGGER sbtest]] .. table_id .. [[_trig BEFORE INSERT ON sbtest]] .. table_id .. [[
         FOR EACH ROW BEGIN SELECT sbtest]] .. table_id .. [[_seq.nextval INTO :new.id FROM DUAL; END;]])
  db_query("COMMIT")
  db_query("CREATE INDEX k_" .. table_id .. " on sbtest" .. table_id .. "(k)")
end


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
     sqlload(i)
     create_index_and_seq(i)
   end
end

function event(thread_id)
   os.exit()
end
