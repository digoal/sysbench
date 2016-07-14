# 新增的lua

oltp_pg_simple.lua   
    不使用绑定变量，新增至19条SQL, 包括键值查询，IN查询，范围查询，sum和distinct范围查询,   非键值查询，键值更新，非键值更新，删除，插入。     
oltp_pg.lua   
    使用PostgreSQL 服务端绑定变量, 执行SQL与oltp_pg_simple.lua一致。 可以对比是否使用绑定变量的性能差异。    
oltp_pg_udf.lua   
    与oltp_pg.lua执行的SQL一致，但是使用postgresql函数处理19条SQL， 与oltp_pg.lua对比，可以用来判断网络RT问题。      
parallel_init_pg.lua   
    支持并行COPY生成测试数据。     
parallel_init_pg_bytbs.lua    
    与parallel_init_pg.lua功能一致，但是支持表空间。     
 
## 测试rds pg

步骤  
购买RDS PG数据库实例  
创建数据库用户  
购买同机房，与RDS PG同VPC网络ECS或者同经典网络的ECS  
在ECS端安装PostgreSQL客户端  
```
useradd digoal  
su - digoal  

wget https://ftp.postgresql.org/pub/source/v9.5.2/postgresql-9.5.2.tar.bz2  
tar -jxvf postgresql-9.5.2.tar.bz2  
cd postgresql-9.5.2  
./configure --prefix=/home/digoal/pgsql9.5  
gmake world -j 16  
gmake install-world -j 16  

vi ~/env_pg.sh  
export PS1="$USER@`/bin/hostname -s`-> "  
export PGPORT=1921  
export LANG=en_US.utf8  
export PGHOME=/home/digoal/pgsql9.5  
export LD_LIBRARY_PATH=$PGHOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH  
export DATE=`date +"%Y%m%d%H%M"`  
export PATH=$PGHOME/bin:$PATH:.  
export MANPATH=$PGHOME/share/man:$MANPATH  
export PGHOST=$PGDATA  
export PGUSER=postgres  
export PGDATABASE=postgres  
alias rm='rm -i'  
alias ll='ls -lh'  
unalias vi  

. ~/env_pg.sh  
```
安装sysbench(from github)  
```
cd ~  

git clone https://github.com/digoal/sysbench.git  
```

并行初始化测试数据  
```
./sysbench_pg --test=lua/parallel_init_pg.lua \  
  --db-driver=pgsql \  
  --pgsql-host=xxx.xxx.xxx.xxx \  
  --pgsql-port=3432 \  
  --pgsql-user=digoal \  
  --pgsql-password=pwd \  
  --pgsql-db=postgres \  
  --oltp-tables-count=16 \  
  --oltp-table-size=1000000 \  
  --num-threads=16 \  
  cleanup  


./sysbench_pg --test=lua/parallel_init_pg.lua \  
  --db-driver=pgsql \  
  --pgsql-host=xxx.xxx.xxx.xxx \  
  --pgsql-port=3432 \  
  --pgsql-user=digoal \  
  --pgsql-password=pwd \  
  --pgsql-db=postgres \  
  --oltp-tables-count=16 \  
  --oltp-table-size=1000000 \  
  --num-threads=16 \  
  run  
```
测试oltp_pg.lua的内容，包含SQL如下，其中第一条SQL循环10次 ：  
```
   -- select c from tbl where id = $1;  
   -- select id,k,c,pad from tbl where id in ($1,...$n);  
   -- select c from tbl where id between $1 and $2;  
   -- select sum(k) from tbl where id between $1 and $2;  
   -- select c from tbl where id between $1 and $2 order by c;  
   -- select distinct c from tbl where id between $1 and $2 order by c;  
   -- update tbl set k=k+1 where id = $1;  
   -- update tbl set c=$2 where id = $1;  
   -- delete from tbl where id = $1;  
   -- insert into tbl(id, k, c, pad) values ($1,$2,$3,$4);  
```
一个事务执行19条SQL  
```
./sysbench_pg --test=lua/oltp_pg.lua \  
  --db-driver=pgsql \  
  --pgsql-host=xxx.xxx.xxx.xxx \  
  --pgsql-port=3432 \  
  --pgsql-user=digoal \  
  --pgsql-password=pwd \  
  --pgsql-db=postgres \  
  --oltp-tables-count=16 \  
  --oltp-table-size=1000000 \  
  --num-threads=16 \  
  --max-time=120  \  
  --max-requests=0 \  
  --report-interval=1 \  
  run  

OLTP test statistics:  
    queries performed:  
        read:                            0  
        write:                           0  
        other:                           566572  
        total:                           566572  
    transactions:                        26972  (224.62 per sec.)  
    deadlocks:                           0      (0.00 per sec.)  
    read/write requests:                 0      (0.00 per sec.)  
    other operations:                    566572 (4718.32 per sec.)  

General statistics:  
    total time:                          120.0791s  
    total number of events:              26972  
    total time taken by event execution: 1919.7217s  
    response time:  
         min:                                 39.35ms  
         avg:                                 71.17ms  
         max:                               3159.62ms  
         approx.  95 percentile:             124.54ms  

Threads fairness:  
    events (avg/stddev):           1685.7500/85.94  
    execution time (avg/stddev):   119.9826/0.02  
```
  
## 测试自建PostgreSQL  
  
创建表空间，可以在每个块设备对应的文件系统中创建一个表空间，均分IO  
表空间命名规则tbs0,tbs1,...  
修改lua/parallel_init_pg_bytbs.lua, 设置一致的表空间数目  
```
vi lua/parallel_init_pg_bytbs.lua  

tbs=3  
```
并行初始化测试数据  
```
./sysbench_pg --test=lua/parallel_init_pg_bytbs.lua \  
  --db-driver=pgsql \  
  --pgsql-host=xxx.xxx.xxx.xxx \  
  --pgsql-port=3432 \  
  --pgsql-user=digoal \  
  --pgsql-password=pwd \  
  --pgsql-db=postgres \  
  --oltp-tables-count=16 \  
  --oltp-table-size=1000000 \  
  --num-threads=16 \  
  cleanup  


./sysbench_pg --test=lua/parallel_init_pg_bytbs.lua \  
  --db-driver=pgsql \  
  --pgsql-host=xxx.xxx.xxx.xxx \  
  --pgsql-port=3432 \  
  --pgsql-user=digoal \  
  --pgsql-password=pwd \  
  --pgsql-db=postgres \  
  --oltp-tables-count=16 \  
  --oltp-table-size=1000000 \  
  --num-threads=16 \  
  run  
```
其他测试方法与测试rds pg一致。  
  
## 自定义lua脚本建议  
  
建议使用run调用, init单个线程只调用一次，event多次调用。  
cleanup根据提供的线程和表的数量DROP表.  

