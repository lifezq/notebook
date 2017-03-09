百度如何能实时检索到15分钟前新生成的网页？
===============

## 一、缘起               
[《深入浅出搜索架构（上篇）》](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_01.md)详细介绍了前三章：               
（1）全网搜索引擎架构与流程               
（2）站内搜索引擎架构与流程               
（3）搜索原理与核心数据结构               
 
[《深入浅出搜索架构（中篇）》](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_02.md)介绍了：               
（4）流量数据量由小到大，常见搜索方案与架构变迁               
（5）数据量、并发量、扩展性架构方案               
 
本篇将讨论：               
（6）百度为何能实时检索出15分钟之前新出的新闻？58同城为何能实时检索出1秒钟之前发布的帖子？搜索引擎的实时性架构，是本文将要讨论的问题。               
 
## 二、实时搜索引擎架构               
大数据量、高并发量情况下的搜索引擎为了保证实时性，架构设计上的两个要点：               
（1）索引分级               
（2）dump&merge               
 
索引分级               
[《深入浅出搜索架构（上篇）》](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_01.md)介绍了搜索引擎的底层原理，在数据量非常大的情况下，为了保证倒排索引的高效检索效率，任何对数据的更新，并不会实时修改索引，一旦产生碎片，会大大降低检索效率。               
 
既然索引数据不能实时修改，如何保证最新的网页能够被索引到呢？               
索引分为全量库、日增量库、小时增量库。               
 
如下图所述：               
（1）300亿数据在全量索引库中               
（2）1000万1天内修改过的数据在天库中               
（3）50万1小时内修改过的数据在小时库中               
 
![img01](http://mmbiz.qpic.cn/mmbiz_png/YrezxckhYOwhuoibfs1AFibjpNyniaOu5ia4WFtMSOuoBeX511zv2nhJVkEoicqlBhlsKWxg4fZBdtH16k0iaFTsUk2w/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1)  

当有修改请求发生时，只会操作最低级别的索引，例如小时库。               
 
 
 ![img02](http://mmbiz.qpic.cn/mmbiz_png/YrezxckhYOwhuoibfs1AFibjpNyniaOu5ia4PyuuwPmmlPcicYFaia7XXmCdXuhbsnWNSgbXYUGTrSxrjJxunPMJxMKQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1)   
 
当有查询请求发生时，会同时查询各个级别的索引，将结果合并，得到最新的数据：               
（1）全量库是紧密存储的索引，无碎片，速度快               
（2）天库是紧密存储，速度快               
（3）小时库数据量小，速度也快               
 
数据的写入和读取都是实时的，所以58同城能够检索到1秒钟之前发布的帖子，即使全量库有300亿的数据。               
 
新的问题来了：小时库数据何时反映到天库中，天库中的数据何时反映到全量库中呢？               
 
dump&merge               
这是由两个异步的工具完成的：               

![img03](http://mmbiz.qpic.cn/mmbiz_png/YrezxckhYOwhuoibfs1AFibjpNyniaOu5ia4s94oicR4geq4C5oc3mHPMj3FXkiaLjFIFMwDq9xgoNsILS4ibcxtczL5A/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1)    

dumper：将在线的数据导出               
merger：将离线的数据合并到高一级别的索引中去               
 
小时库，一小时一次，合并到天库中去；               
天库，一天一次，合并到全量库中去；               
这样就保证了小时库和天库的数据量都不会特别大；               
如果数据量和并发量更大，还能增加星期库，月库来缓冲。               
 
## 三、总结               
超大数据量，超高并发量，实时搜索引擎的两个架构要点：               
（1）索引分级               
（2）dump&merge               
 
如[《深入浅出搜索架构（上篇）》](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_01.md)中所述，全网搜索引擎分为Spider, Search&Index, Rank三个部分。本文描述的是Search&Index如何实时修改和检索，Spider子系统如何能实时找到全网新生成的网页，又是另外一个问题，未来撰文讲述。               
 
希望大家有收获，帮转哟。               
==【完】==               
相关文章：               
[如何快速实现高并发短文检索](http://mp.weixin.qq.com/s?__biz=MjM5ODYxMDA5OQ==&mid=2651959451&idx=1&sn=991d9c3737d7db50a8351d50cdf6419d&scene=21#wechat_redirect)                
[深入浅出搜索引擎架构、方案、细节](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_01.md)               
[就是这么迅猛的实现搜索需求](https://github.com/lifezq/notebook/blob/master/search_engine/a_simple_search_engine_arch_02.md)               
