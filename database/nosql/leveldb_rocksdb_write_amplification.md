# leveldb和rocksdb在大value场景下的一些问题

### Table of Contents  
> 1   问题  
> 1.1   compaction不可控.  
> 1.2   写放大  
> 1.3   其它问题  
> 2   小结  

Leveldb 2011年7月开源, 到现在有3年了, 原理上已经有很多文章介绍了, 我们就不多说.  
其中最好的是淘宝那岩写的 leveldb 实现解析 和 TokuMX作者写的那个300页ppt: A Comparison of Fractal Trees toLog-Structured Merge (LSM) Trees (这个PPT 对读放大写放大分析很好, 值得再读一次)   
最近基于LevelDB, RocksDB 做了一点东西, 我们的目标场景是存储平均50K大小的value, 遇到一些问题, 总结一下:   

## 1   问题   
#### 1.1   compaction不可控.   
当L0文件达到12个, 而compaction来不及的时候, 写入完全阻塞, 这个阻塞时间可能长达10s.   
LevelDB实现上是L0达到4个时开始触发compaction, 8个时开始减慢写入, 12个时完全停止写入. 具体配置是写死的, 不过可以在编译时修改:   
    // Level-0 compaction is started when we hit this many files.
    static const int kL0_CompactionTrigger = 4;
    
    // Soft limit on number of level-0 files.  We slow down writes at this point.
    static const int kL0_SlowdownWritesTrigger = 8;
    
    // Maximum number of level-0 files.  We stop writes at this point.
    static const int kL0_StopWritesTrigger = 12;
    
RocksDB这几个数字都可以通过参数设置, 相对来说好一些:    
    options.level0_slowdown_writes_trigger
    options.level0_stop_writes_trigger
    
但是   
一旦写入速度>compaction速度, 不论这几个阈值设置多大, L0都迟早会满的.    
阈值调大会导致数据都堆积在L0, 而L0的每个文件key范围是重叠的, 意味着一次查询要到L0的每个文件中都查一下, 如果L0文件有100个的话，这大约就是100次IO, 读性能会急剧降低.   
实际上, RocksDB的 Universal Style 就是把所有的数据都放在L0, 不再做compaction, 这样显然没有写放大了,   
但是读的速度就更慢了, 所以限制单个DB大小小于100G, 而且最好在内存.   
#### 1.2   写放大   
基准数据100G的情况下, 50K的value, 用200qps写入, 磁盘带宽达到100MB/s 以上.   
真实写入数据大约只有50K*200=10MB/s, 但是磁盘上看到的写大约是10-20倍, 这些写都是compaction在写,   
此时的性能瓶颈已经不是CPU或者是LevelDB代码层，而是磁盘带宽了, 所以这个性能很难提上去,   
而且HDD和SSD在顺序写上性能差别不大, 所以换SSD后性能依然很差.   
其它同学发现的issue:   
https://github.com/facebook/rocksdb/issues/210 提到的case, 12MB/s的写入, 磁盘IO大约100MB/s   
https://github.com/facebook/rocksdb/issues/182 发现100G基础数据时, 写1K的value性能也比较差.    
Hbase也有这个问题 http://www.infoq.com/cn/articles/hbase-casestudy-facebook-messages: Compaction操作就是读取小的HFile到内存merge-sorting成大的HFile然后输出，加速HBase读操作。Compaction操作导致写被放大17倍以上，   
不过HBase社区很少关注这个问题.      
猜测原因可能是HBase是一种批处理思路, 数据都是批量写入进去, 写进去后再一次性做一个Compaction.    
#### 1.3   其它问题  
这几个问题只针对LevelDB, RocksDB已经解决了:   
每个mmtable太小(2M), 存在如下问题:     
如果写入200G数据, 在db目录下就会有20w个文件, 需要频繁打开/关闭文件, 一个目录里面20w个文件的性能会很差(当然btrfs之类好些)    
对于50K的value, 一个文件只能放40个key-value对, 效率很低   
Write Ahead Log 不能禁掉.      
对于大value来说, 一个写请求, leveldb会写2份, write-ahead-log和真实数据, 浪费.    
不能自定义compaction函数, 如果可以自定义, 则可以在compaction的时候做ttl功能.    
compaction不能限速.     
读触发compaction (allowed_seeks), 在某些场景不合适.      
#### 2   小结  
leveldb 适用于小的kv库(value小(<1K), 总size小(<100G)), 比如chrome客户端 或者小的cache(比如某些模块自带的cache)     
由于LevelDB把key和value都放在同一个文件里面, compaction的时候必须key和value一起读写, 所以写放大显得更为明显. 其实我们只需要保证key有序, compaction只需对key做就行了，key和value分开来存放也许一个不错的优化思路.     
在程序里面, 可以把leveldb/rocksdb当做一个 自动扩容, 持久化 的hash表来用.    
