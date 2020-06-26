- [ ] 微服务注册中心
- [ ] Nacos: Dynamic Naming and Configuration Service

-  https://github.com/alibaba/nacos

- [ ]  Eureka is a REST (Representational State Transfer) based service that is primarily used in the AWS cloud for locating services for the purpose of load balancing and failover of middle-tier servers.
-  eureka是一个基于Java语言实现的费用与服务发现与注册的组件，包含服务端和客户端两部分。
-  https://github.com/Netflix/eureka
- [ ] Istio    star 22.8K
    - [ ] An open platform to connect, manage, and secure microservices.

- [ ] 监控系统
    - [ ] 对于监控系统软件，开源的解决方案有流量监控（MRTG、Cacti、Smokeping、Graphite 等）和性能告警（Nagios、Zabbix、Zenoss Core、Ganglia、OpenTSDB 等）
    - [ ] Prometheus 作为新一代的云原生监控系统，目前 GitHub 上已超过 2 万颗星。超过 650 多位贡献者参与到 Prometheus 的研发工作上，并且有 120 多项的第三方集成。从 2012 年 11 月开始至今，Prometheus 持续成为监控领域的热点。

    - [ ] Thanos（没错，就是灭霸）可以帮我们简化分布式 Prometheus 的部署与管理，并提供了一些的高级特性：全局视图，长期存储，高可用

    - [ ] Thanos is a set of components that can be composed into a highly available metric system with unlimited storage capacity, which can be added seamlessly on top of existing Prometheus deployments.

    - [ ] Thanos is a CNCF Sandbox project.

    - [ ] Thanos leverages the Prometheus 2.0 storage format to cost-efficiently store historical metric data in any object storage while retaining fast query latencies. Additionally, it provides a global query view across all Prometheus installations and can merge data from Prometheus HA pairs on the fly.

    - [ ] Concretely the aims of the project are:

    - [ ] Global query view of metrics.
    - [ ] Unlimited retention of metrics.
    - [ ] High availability of components, including Prometheus.



    
- [ ] 分布式事务框架  
    - [ ]  seata start 16.8k  
    - Seata is an easy-to-use, high-performance, open source distributed transaction solution. https://seata.io

- [ ] 分布式锁
    - [ ] 基于数据库的实现方式的核心思想是：在数据库中创建一个表，表中包含方法名等字段，并在方法名字段上创建唯一索引，想要执行某个方法，就使用这个方法名向表中插入数据，成功插入则获取锁，执行完成后删除对应的行数据释放锁。
    - [ ] 基于Redis的实现方式:可以通过setnx或redlock。 Redis 分布式锁，一般就是用 Redisson 框架就好了，非常的简便易用
    - [ ] 基于ZooKeeper的实现方式：ZooKeeper是一个为分布式应用提供一致性服务的开源组件，它内部是一个分层的文件系统目录树结构，规定同一个目录下只能有一个唯一文件名。Curator 这个开源框架，对 ZooKeeper（以下简称 ZK）分布式锁的实现

- [ ] 缓存框架
- 缓存框架的必备需求   
> 1. 并发   
> 2. 内存限制(限制最大的可使用空间)   
> 3. 在多核和多goroutines之间更好的扩展   
> 4. 在非随机密钥的情况下，很好地扩展(eg. Zipf)   
> 5. 更高的缓存命中率    

- [ ]           
    - [ ] caffeine    start 7.8k
    - 特点：满足以上5点缓存特性   
    - [ ] bigcache  start 4k   
    - 综合评分略优于groupcache   
    - [ ] groupcache  start 8.8k   
    
- [ ] 压测工具
    - [ ] wrk    start 25k
    - Modern HTTP benchmarking tool.  https://github.com/wg/wrk      
    
- [ ] json编码
    - [ ] json-iterator/go    start 7.8k    
    - 特点：编码性能高于easyjson
    
- [ ] CUI 命令行用户交互工具
    - [ ] go-prompt: A library for building powerful interactive prompts inspired by python-prompt-toolkit, making it easier to build cross-platform command line tools using Go. https://github.com/c-bata/go-prompt 
    - [ ] gocui: Minimalist Go package aimed at creating Console User Interfaces. https://github.com/jroimartin/gocui
    
- [ ] CLI 命令行工具
    - [ ] cobra: Cobra is both a library for creating powerful modern CLI applications as well as a program to generate applications and command files. https://github.com/spf13/cobra
    - [ ] cli: is a simple, fast, and fun package for building command line apps in Go. The goal is to enable developers to write fast and distributable command line applications in an expressive way. https://github.com/urfave/cli
