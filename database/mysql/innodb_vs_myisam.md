Innodb VS Myisam
=============

    MariaDB [test]> status
    --------------
    mysql  Ver 15.1 Distrib 5.5.47-MariaDB, for Linux (x86_64) using readline 5.1
    
    Connection id:		2
    Current database:	test
    Current user:		root@localhost
    SSL:			Not in use
    Current pager:		less
    Using outfile:		''
    Using delimiter:	;
    Server:			MariaDB
    Server version:		5.5.47-MariaDB MariaDB Server
    Protocol version:	10
    Connection:		Localhost via UNIX socket
    Server characterset:	latin1
    Db     characterset:	latin1
    Client characterset:	utf8
    Conn.  characterset:	utf8
    UNIX socket:		/var/lib/mysql/mysql.sock
    Uptime:			41 min 14 sec
    
    Threads: 1  Questions: 60  Slow queries: 0  Opens: 11  Flush tables: 2  Open tables: 37  Queries per second avg: 0.024
    --------------



## 1.  测试 Innodb 引擎

### 1.1 默认配置下 Innodb 引擎

    MariaDB [test]> show create table table_bench\G;
    *************************** 1. row ***************************
           Table: table_bench
    Create Table: CREATE TABLE `table_bench` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `title` varchar(30) NOT NULL DEFAULT '',
      `value` varchar(100) NOT NULL DEFAULT '',
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1000000 DEFAULT CHARSET=utf8
    1 row in set (0.00 sec)
    
    ERROR: No query specified
    
    MariaDB [test]> SHOW CREATE PROCEDURE pt_bench;
    +-----------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    | Procedure | sql_mode | Create Procedure                                                                                                                                                                                                                        | character_set_client | collation_connection | Database Collation |
    +-----------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    | pt_bench  |          | CREATE DEFINER=`root`@`localhost` PROCEDURE `pt_bench`(IN lt INT)
    BEGIN DECLARE i INT; SET i = 1; WHILE( i < lt ) do INSERT INTO table_bench values(i, CONCAT('title_test', i), CONCAT('value_test', i)); SET i = i + 1; END WHILE; END | utf8                 | utf8_general_ci      | latin1_swedish_ci  |
    +-----------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    1 row in set (0.00 sec)
    
    MariaDB [test]> truncate table table_bench;
    Query OK, 0 rows affected (0.05 sec)
    
    MariaDB [test]> select * from table_bench;
    Empty set (0.00 sec)
    
    MariaDB [test]> call pt_bench(100000);
    Query OK, 1 row affected (21 min 15.65 sec)
    
    MariaDB [test]> select count(*) from table_bench;
    +----------+
    | count(*) |
    +----------+
    |    99999 |
    +----------+
    1 row in set (0.03 sec)

    从上面可以看出Innodb在默认配置下，插入数据几乎慢到不可用。 ~78/s
 
 ### 1.2 优化配置参数后 Innodb引擎
 
    优化：需要修改几个重要配置参数


> 1. innodb_buffer_pool_size  
> 这是InnoDB最重要的设置，对InnoDB性能有决定性的影响。默认的设置只有8M，所以默认的数据库设置下面InnoDB性能很差。在只有 InnoDB存储引擎的数据库服务器上面，可以设置60-80%的内存。更精确一点，在内存容量允许的情况下面设置比InnoDB tablespaces大10%的内存大小。

> 2. innodb_log_buffer_size
> 磁盘速度是很慢的，直接将log写道磁盘会影响InnoDB的性能，该参数设定了log buffer的大小，一般4M。如果有大的blob操作，可以适当增大。

> 3. innodb_flush_log_at_trx_commit
> 该参数设定了事务提交时内存中log信息的处理。
> >  1) =1时，在每个事务提交时，日志缓冲被写到日志文件，对日志文件做到磁盘操作的刷新。Truly ACID。速度慢。
> >  2) =2时，在每个事务提交时，日志缓冲被写到文件，但不对日志文件做到磁盘操作的刷新。只有操作系统崩溃或掉电才会删除最后一秒的事务，不然不会丢失事务。
> >  3) =0时， 日志缓冲每秒一次地被写到日志文件，并且对日志文件做到磁盘操作的刷新。任何mysqld进程的崩溃会删除崩溃前最后一秒的事务

优化后再次测试Innodb:

我的配置选项参数为以下:

> - innodb_buffer_pool_size=8192M
> - innodb_log_buffer_size=16M
> - innodb_flush_log_at_trx_commit=2


    MariaDB [test]> truncate table_bench;
    ERROR 2006 (HY000): MySQL server has gone away
    No connection. Trying to reconnect...
    Connection id:    2
    Current database: test
    
    Query OK, 0 rows affected (0.05 sec)
    
    MariaDB [test]> select count(*) from table_bench;
    +----------+
    | count(*) |
    +----------+
    |        0 |
    +----------+
    1 row in set (0.00 sec)
    
    
    MariaDB [test]> select count(*) from table_bench;
    +----------+
    | count(*) |
    +----------+
    |        0 |
    +----------+
    1 row in set (0.00 sec)
    
    MariaDB [test]> call pt_bench(100000);
    Query OK, 1 row affected (5.22 sec)
    
    
    MariaDB [test]> select count(*) from table_bench;
    +----------+
    | count(*) |
    +----------+
    |    99999 |
    +----------+
    1 row in set (0.03 sec)

优化后Innodb速度: ~20000/s

Innodb测试总结，如果使用Innodb引擎作为存储引擎，如果不对默认配置做优化，就是扯淡。必须要优化配置参数后才可用。

##   2. 测试myisam引擎


    MariaDB [test]> show create table table_bench_myisam\G;
    *************************** 1. row ***************************
           Table: table_bench_myisam
    Create Table: CREATE TABLE `table_bench_myisam` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `title` varchar(15) NOT NULL DEFAULT '',
      `value` varchar(100) NOT NULL DEFAULT '',
      PRIMARY KEY (`id`)
    ) ENGINE=MyISAM AUTO_INCREMENT=100000 DEFAULT CHARSET=utf8
    1 row in set (0.00 sec)
    
    ERROR: No query specified
    
    MariaDB [test]> SHOW CREATE PROCEDURE pt_bench_myisam;
    +-----------------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    | Procedure       | sql_mode | Create Procedure                                                                                                                                                                                                                              | character_set_client | collation_connection | Database Collation |
    +-----------------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    | pt_bench_myisam |          | CREATE DEFINER=`root`@`localhost` PROCEDURE `pt_bench_myisam`(IN lt INT)
    BEGIN DECLARE i INT; SET i=1; WHILE(i < lt) DO INSERT INTO table_bench_myisam VALUES(i, CONCAT('title_test:',i), CONCAT('value_test:',i)); SET i=i+1; END WHILE; END | utf8                 | utf8_general_ci      | latin1_swedish_ci  |
    +-----------------+----------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------+----------------------+--------------------+
    1 row in set (0.00 sec)
    
        
    
    MariaDB [test]> truncate table table_bench_myisam;
    Query OK, 0 rows affected (0.00 sec)
    
    MariaDB [test]> select * from table_bench_myisam;
    Empty set (0.00 sec)
    
    MariaDB [test]> call pt_bench_myisam(100000);
    Query OK, 1 row affected, 1 warning (2.35 sec)
    
    MariaDB [test]> select count(*) from table_bench_myisam;
    +----------+
    | count(*) |
    +----------+
    |    99999 |
    +----------+
    1 row in set (0.00 sec)

从上面可以看出，Myisam引擎默认配置下插入速度远超Innodb , ~50000/s

