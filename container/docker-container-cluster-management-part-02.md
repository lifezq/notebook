Docker背后的容器集群管理——从Borg到Kubernetes（二）
============

在本系列的第一部分《Docker背后的容器集群管理——从Borg到Kubernetes（一）》中，我们对Borg系统进行了深入的剖析，并且同它的衍生项目Kubernetes进行了逐一地比较。这一部分对比包括了Borg和Kubernetes的各类核心概念、任务类型划分、资源管理和分配方式、配额和优先级机制，以及最关键的调度策略。这些分析涵盖了原论文前四章的主要内容。

从这些比较中我们不难发现，虽然Kubernetes与Borg有很多相似的地方，但是在很多关键特性上Kubernetes明显进行了重新设计。而Borg的作者之所以要这么做，最主要的原因是除了任务容器的编排调度和管理之外，Borg需要比Kubernetes更加关注这样一个事情：如何最大程度地提高集群的资源利用率？

注：本文作者张磊将在8月28日~29日的CNUT全球容器技术峰会上分享题为《从0到1：Kubernetes实战》的演讲，演讲中他将重点剖析Kubernetes的核心原理和实践经验，并分享大规模容器集群管理所面临的问题和解决思路。

## 1. 利用率

所以，本节讨论的集群利用率优化可以说是Borg的精华所在，也是Borg系统与其他类似项目相比最大的亮点之一。那么Borg的具体做法是怎样的呢？

如果用一句话来解释，Borg做了最主要工作就是来回收再利用任务的空闲资源，并且对不同的回收策略做出了科学的评估。

所以我们接下来先从这个评估方法入手。

### 1.1 利用率的评估方法

前面已经提到过，Borg中进行任务的调度既需要考虑机器的资源可用性（包括抢占），也要考虑任务本身的约束要求（比如"我需要SSD机器"），还需要考虑应对压力峰值所必需的空余量。而在本节，我们还要为调度再加上一条规则，那就是对于batch job来说，它们还需要能够利用从LRS任务上回收来的资源。这种情况下，调度过程中的资源抢占和回收机制带来了一个负面影响：Borg很难快速而精确地回答"某个机器/集群到底还有多少资源可用"这样的问题。

可是，为了能够评价不同的调度算法，Borg必须能够评估集群的资源使用情况。很多情况下，运维人员会计算一个一段时间内的集群"平均利用率"来作为评价指标，但是Borg则使用了一个叫 "压缩实验" 的方法。所谓压缩实验，即不断减少工作单元（Cell）中机器的数量（"压缩"），然后重调度某个指定的任务，直到该任务再也不能正常调度运行在这个集群上。这个过程不断进行的最终结果，得到就是这个任务运行所需的"最小工作单元"的定义。

这个指标清楚地表明了当资源减少到什么程度时，我们才可以终止这个任务，并且这个生成指标的过程不需要提交任何『模拟』任务，这样得到的结果要精确很多。

当然，上述『压缩』的过程自然不能在生产环境中开展。这时我们前面提到的模拟器：Fauxmaster的作用就发挥出来了。Borg可以加载某时刻的checkpoints，从而在Fauxmaster上重现出与当时一模一样的环境（除了Borglet是模拟的之外）。

在具体进行压缩的过程中，Borg还使用了以下几个小技巧：

> - 随机选择机器来移除。
> - 对每一个任务进行上述压缩实验（除了某些跟机器紧密绑定的存储型任务）。
> - 当Cell的大小减小到一定程度时（比如剩余资源只有Job所需资源的二倍），将硬性约束改为非硬性约束，从而适当增加调度成功的几率。
> - 允许最多0.2%的”挑剔型“任务挂起，因为它们每次都会被调度到一小撮机器上。
> - 如果某次压缩实验需要更大的Cell，管理员可以将原Cell克隆几份再开始“压缩”的过程。
> - 上述压缩实验会在每一个Cell中重复11次，每一次都会选择一个不同的随机数种子来移除机器。

所以，通过上述压缩实验，Borg提供了一种直观的、可以用来评估不同调度策略优劣的测试方法。即： 调度策略越优秀，对于同一个任务来说它最后得到的最小工作单元中所需的机器数就越少 。

不难发现，Borg对资源使用进行评估的方法关注的是一个任务在某一具体时刻运行起来所需的最少的资源成本，而不是像传统做法那样去模拟并重现一个调度算法的执行过程，然后跟踪检查一段时间内集群负载等资源指标的变化情况。

当然，在生产环境中，Borg并不会真的把资源『压缩』到这么紧，而是给应对各类突发事件留有足够余量的。

### 1.2 Cell的共享

Borg进行高效的集群管理最直接的一个优化方法就是任务的混部。这里Borg进行了一项对比实验，即把LRS和batch job分别部署到不同的集群中，结果同样的硬件和任务条件下我们需要比Borg多20%-30%的机器。造成这种情况的关键原因是：prod级别的任务（即大多数的LRS）实际使用的资源比它申请的资源要少很多，而Borg会回收这部分资源来运行non-prod级别的任务（比如大多数batch job）。

另一方面，不仅是不同类型的任务在Borg中混合部署，不同用户的任务也是混合部署的。Borg的实验表明，如果在一定条件下（比如此Cell上任务所属的不同用户数量达到一定值）自动将不同用户的任务隔离到不同Cell上，那么Borg将需要比现在多20-150%的机器才能满足正常的运行要求。

看到这里，相信很多读者也会产生同我一样的疑问：把不同类型、不同用户的任务混合在一台机器上运行，会不会造成CPU时间片的频繁切换而降低系统性能呢？为了回答这个问题，Borg专门以CPI（cycles per instruction，每条指令所需的时钟周期）的变化为指标对任务与CPI之间的关系做出了评估。

这里Borg使用的评估方法是：将Cell分为『共享的Cell』（混部）和『独享的Cell』（不混部），然后从所有Cell中随机选择12000个prod级别的任务，然后再这些任务中进行为期一周的持续采样。每次采样间隔5分钟，每次采样都统计被选中任务的CPU时钟周期和指令数目。这个过程最后得出的结论包括：

>  一、CPI数值的变化与两个变量的变化正相关：机器本身的CPU使用量，机器上的任务数量。任务数量对CPI的影响更大：在一台机器上每增加一个任务，就会将这台机器上其他任务的CPI增加0.3%；而机器CPU使用量每增加1%，指令CPI的增长只有0.2%左右。但是，尽管存在上述关系，实际生产环境中Borg只有很小一部分CPI变化是由于上述两个变量的改变造成的，更多CPI变化的诱因是应用本身实现上（比如算法，数据库连接等）对CPU的影响。

>  二、共享的Cell与独享的Cell相比，有大约3%的CPU性能损失。这个结论是通过比较这两类Cell上的采样结果得到的，也表明了混部策略确实会一定程度上降低CPU的表现。

>  三、为了避免（二）中的结论受到应用本身差异行的干扰（比如被采样任务本身就是CPU敏感的），Borg专门对Borglet进程做了CPI采样：因为这个进程在整个集群中完全同质，并且同时分布在独享Cell和共享Cell的所有机器上。这时，测试得出的结论是独享Cell上的Borglet进程的CPU表现要比共享Cell上好1.19倍。

综上，通过上述系统地测试，Borg确认了 共享Cell会给任务带来CPU上的性能损失 ，但是相比任务混部所带来的机器数量的大幅节省，上述CPU损失还是很可以接受的。更何况，机器数量减少不仅仅节省了CPU，还节省了大量内存和磁盘的成本，与这些相比，任务混部在CPU上造成的一点浪费确实微不足道。

### 1.3 使用更大的Cell

Borg还做了一个很有意义的测试，那就是将一个大Cell中的任务分开部署到跟多小Cell中（这些任务是随机挑选出来的）。结果表明，为了运行这些任务，小Cell需要比大Cell多得多的机器才能正常工作。

### 1.4 细粒度的资源请求

Borg用户提交的任务使用一个CPU核心的千分之一作为单位来申请CPU，使用字节为单位来申请内存和磁盘，这与Kubernetes里的资源单位是一样的。这种情况下，一个常见的资源请求描述如下所示：

    "cpu": 1000,
    "memory": 1048576,     
    
请求中具体需要某种资源量的大小完全由用户决定，并且一旦该任务创建成功，上述参数会作为任务进程的cgroup参数来限制任务的资源使用情况。

不难发现，Borg以及Kubernetes的资源请求粒度都是小而灵活的，这也是基于容器的编排管理平台的一大特点：资源粒度直接对应到cgroups的配置上，所以用户可以进行非常精细的调节。在这种情况下，提供类似于『1个CPU，1G内存』这种固定的资源配额offier来供用户选择的做法就不够明智了。

事实上，这种细粒度的资源请求一方面能够减少资源请求的聚集（比如可能90%的任务都要求『个CPU，1G内存』）所造成资源碎片化，另一方面还能有效地避免本来无关的两种资源发生不必要的关联（比如为了申请1个CPU，任务必须申请1G内存）。在试验中，Borg直接展示了如果用户使用资源配额offer来持续向Borg请求资源（比如OpenStack就只为用户提供了的tiny、medium、large等几种可选的offer），Borg所管理的集群将需要比原先多30%-50%的机器才能支撑同样规模的任务运行。

### 1.5 资源回收

终于来到了关键的部分。我们前面已经不止一次提到过，Borg通过任务混部提高集群利用率的一个重要基础就是资源的回收和重分配。

准确来讲，资源回收主要发生在任务调度的资源可行性检查阶段。举个例子，假设一台机器的容量是10G内存，并且已经有一个申请了4G内存的任务A在运行，那么这台机器的剩余可用资源就是6G，另一个申请8G内存的任务B是通不过可行性检查的。但实际情况是，Borg会在一段时间后把任务A申请的内存改成1G，使得调度器认为这台机器的剩余可用资源变成9G。这样，任务B就可以调度成功并且运行在这台机器上了，这就是说任务B使用了回收自任务A的一部分资源。这个过程具体实现是怎样的呢？

在Borg中，任务申请的资源limit是一个上限。这个上限是Borg用来确定一台机器的资源是否足够运行一个新任务的主要标准。

既然是上限，大多数用户在设置这个limit时都会故意把这个值设置的稍微高一点，以备不时之需。不过，大多数时候任务的资源使用率都是比较低的。为了解决这个问题，Borg做了一个非常有意义的工作，那就是先为每个任务估算它真正需要使用的资源量，然后把空闲部分资源回收给那些对资源要求不是很高的任务来使用。这部分回收资源的典型使用者就是非生产环境任务，比如batch job。

这个估算过程由Borgmaster通过Borglet汇报的资源使用情况每隔几秒计算一次，得出的资源使用量称为 "资源预留" 。一个任务的资源预留在最开始是与用户设置的limit相等的（即等于任务请求的资源量），在任务成功启动一段时间后（300s），它的资源预留会 慢慢减少 为任务的 实际资源使用量加上一个可配置的安全余量 。另一方面，一旦任务的资源使用量突然增加并超过了上述资源预留，Borg会 迅速 增加它的资源预留到初始值来保证任务能够正常工作。

需要注意的是，生产级别的任务（prod级别的任务）是永远不会使用回收而来的资源的。只有对于非prod级别的任务来说，它们在被调度的时候Borg才会把可回收资源纳入到可行性检查的范围内，正如我们前面介绍的那样。

既然是估算，Borg就有可能会把过多的任务调度在一台机器上从而造成机器的资源被完全耗尽。更糟糕的是对于任务来说，它们的实际资源使用量却完全是处于各自limit范围内的。在这种情况下，Borg会杀死一些非prod级别的任务来释放资源。

Borg内部的实验表明如果在当前集群中禁用资源回收的话，将近一半的Cell都需要额外增加30%的机器才能支撑同样规模的任务。而在G的生产环境中，则有近20%的任务是运行在这些回收来的资源上的。并且Borg对内部任务的统计再次验证了：对于绝大部分任务而言，它的实际的资源使用相比它申请的资源限制来说都是很低的，将近一半机器的CPU和内存使用量不到20%。

最后的问题是，我们应该为给任务设置多大的安全余量呢？不难想到，如果安全余量设置得很小，我们就可以实现更高的资源利用率，但是也更容易出现使用量超出资源预留的情况（此时就会OOM）。相反，如果把安全余量设置得很大，那资源利用率就不可能很高，当然OOM的情况也会减少。这里Borg给出的答案是通过实验来得出合理的值：给定不同的安全余量值，分别观察不同余量下资源利用率和OOM在一段时间内的的变化，然后选择一个资源利用率和OOM出现次数的平衡点来作为整个集群的安全余量。

## 2 隔离与性能

前面说了那么多共享的内容，读者应该可以猜到Borg的机器上运行着的任务密度应该是很高的。事实的确如此：一半以上的Borg机器上同时运行着9个以上的任务，这其中绝大多数机器运行着约25个任务、开启了4500个线程。共享给Borg带来了极高的资源利用率，但是也使得这些任务间的隔离成为了一个不得不重点解决的问题。

### 2.1 任务间隔离

Borg最早是直接使用chroot和cgroup来提供任务间的隔离和约束，并且允许用户通过ssh登陆到这些隔离环境中来进行调试。后期这个ssh登陆的办法被替换成了borgssh指令，即通过Borglet来负责维护一个用户到隔离环境内shell的ssh连接。需要注意的是，来自外部用户的应用是运行在GAE或者GCE上的，而不是直接作为Borg任务来跑的。其中GAE作为PaaS主要使用的是砂箱技术来支撑和隔离用户的应用，而GCE作为IaaS自然使用的是VM技术。值得一提的是无论GAE还是GCE，它们所需的KVM进程则是作为job运行在Borg上的。

Borg的早期阶段对于资源限制做的还是比较原始的，它只在任务调度成功后对内存、磁盘和CPU的使用情况进行持续的检查，然后依据检查结果杀死那些使用了太多资源的任务。在这种策略下，Borg任务间的资源竞争是很普遍的，以至于有些用户故意将任务的资源请求设置的很大，以期尽量减少机器上同时运行的任务数，这当然大大降低了资源利用率。

所以，很快Borg就开始使用Linux容器技术来解决限制与隔离的问题。G家内部的容器技术有一个对应的开源项目，这就是曾经名噪一时的[lmctfy容器](https://github.com/google/lmctfy)。确切地说，lmctfy给用户提供了一个可以方便地配置cgroup的工具，并能够把用户的这些cgroup配置结合namespace创建出一个任务隔离环境即『容器』出来。由于lmctfy从一开始就是从限制与隔离的角度来开发的，所以它的资源操作接口定义地很丰富，不仅涵盖了cgroup的大部分子系统，还可以进行嵌套等比较复杂的资源管理。但是，随着Docker容器镜像这一杀手级特性的普及以及Docker本身飞快的演化，lmctfy的作者们也不得不放弃了该项目的维护，转而开始去贡献libcotainer项目。不过至于现在G家内部，应该还是在使用类似于lmcty这种自研的容器技术栈，而Docker则主要用作对外提供的公有云服务（Google Container Engine）。

当然，容器也不是万能的，一些底层的资源共享问题比如内存带宽的共享或者CPU缓存污染问题在Borg中仍然存在，但是至少在任务的运行资源的限制和调度优化上，上述容器技术已经足够了。

### 2.2 性能优化

我们前面提到过，Borg中的任务是分为LRS（也可以称为Latency Sensitive任务）和batch job的，其中前者因为对于访问延时敏感所以可以享受更好的『待遇』，这个划分是Borg进行资源回收和在分配的基础。但是还有个待解决的问题是，哪种资源是可以在不影响任务运行的前提下进行回收的呢？

凡是能够进行热回收的资源在Borg中都称为可压缩资源，典型的例子是CPU周期和磁盘I/O带宽。与之相反，内存和磁盘空间这种就属于不可压缩资源。当一台机器上不可压缩资源不够用时，Borglet就不得不按照优先级从低到高杀死任务，直到剩余任务的资源预留能够得到满足。而如果是可压缩资源不足，Borg就能够从某些任务上面回收一些资源（一般从LRS任务上，因为它们申请的资源一般都比实际使用多一些）而不需要杀死任何任务。如果回收资源仍然解决不了问题，那么Borg才会通过Borgmaster将一些任务从这个机器上调度走。

具体到Borglet的实现上同样体现了对资源的限制和管理。Borglet维护了一个内存资源检测循环，它负责在调度时按照资源使用预测的结果（对于prod级别任务），或者按照当前内存使用情况（对于非prod级别任务）为容器设置内存限额。同时，这个循环还负责检测OOM事件，一旦发现有任务试图使用比限额更多的内存时Borglet将杀死它们。而前面刚刚提到的不可压缩资源（内存）不足时的处理也是这个循环完成的、

为了让LRS任务获得更好的性能，LRS可以完全预留某些或者所有CPU核心，并且不允许其他的LRS任务运行在这些CPU核心上。另一方面，batch job则不受此限制，它们可以随时运行在任意CPU核心上，但是在CPU调度上batch job会被分配更小的配额，即它们能占有CPU的时间要比LRS少。

不难看出，为了能够更加高效的使用CPU资源，Borg就必须引入更加复杂的任务调度策略，这也就意味着调度过程会占用更多的时间。所以，Borg的开发者对CPU调度做了优化以期在最小的时间代价里完成调度过程。这些优化包括在内核3.8引入的以进程或者进程组为单位的新的CPU负载计算方法（per-entity load tracking），在调度算法中允许LRS抢占batch job的资源，以及减少多个LRS共享同一CPU时的算法的执行次数。

上述优化的结果使得绝大多数任务都能够在5ms内获得CPU时间片，这比默认的CFS高效很多。不过在一些极端情况下（比如任务对调度时延非常敏感时），Borg会使用cpuset来直接为任务分配独享的CPU核心。不过，这种需要设置cpuset的情况非常少见，而且Borg的作者不止一次告诫容器的使用者不要同时设置cpu.shares和cpuset：因为这会给后续系统的CPU超卖，auto-scaling，统一资源单位的抽象等设计带来很多麻烦。这其实很容易理解：cpu.shares是一个相对值，随着任务（容器）的增加每个容器真正享有的时间片数量是会不断变化的，而在一个任务必须和某个CPU绑定的前提下，每个任务到底能分配到多少时间片这种问题就要变得复杂很多。这也是为什么Kubernetes暂不支持用户设置cpuset的一个主要原因。

虽然Borg任务能够使用的资源取决于它们的limit，其实大多数任务的可压缩资源比如CPU是可以超卖的，即它们可以使用超出限额的可压缩资源（比如CPU）从而更好地利用机器的空闲CPU。只有5%的LRS和不到1%的batch Job会禁止超卖以期获得更精确的资源使用预测。

与CPU相反，Borg中内存的超卖默认是禁止的，因为这会大大提高任务被杀死的几率。但即使如此。仍然有10%的LRS和79%的batch job会开启内存超卖，并且内存超卖对于MapReduce任务来说默认就是开启的。这也正对应了1.5中Borg关于资源回收的设计：batch job更倾向于使用回收来的资源并且驱使系统进行资源回收。

大多数情况下以上策略都能够有助于资源利用率的提高，但是这也使得batch job不得不在某些情况下牺牲自己来给迫切需要运行资源的LRS任务让路：毕竟batch job使用的资源大多是从别人那里回收来的。

与Borg相比，Kubernetes的资源模型还在开发的过程中，当前能够支持的类型也只有CPU和内存两种，其他类似于磁盘空间、IOPS、存储时间和网络带宽等都还处于概念设计阶段。出于跨平台的考虑，Kubernetes的CPU资源的度量会被换算成一个内部统一的KCU单位，比如x86上KCU就等于CPU时间（类似Borg）。同Borg一样，Kubernetes中的CPU也是可压缩资源，而内存就是不可压缩资源了：虽然我们随时可以通过cgroup增加Docker容器的内存限制，但是只有这些page被释放之后进程才可以使用它们，否则仍然会发生OOM。

总结

Borg目前披露的细节就是这么多了，从这些内容上，我们不难看出作为Google超大规模任务容器集群的支撑平台，Borg对于资源混部与集群利用率的优化工作可以说是整篇文章的精髓所在。另外，尽管作者在最后声称后续工作主要是Kubernetes的研发和升级，但是我们绝不能说Kubernetes就是开源版的Borg。

尽管很多概念包括架构、甚至一些实现方法都借鉴了Borg，开发者也基本上是同一拨人，但是Kubernetes与Borg关注的问题存在着根本的差异。

Kubernetes的核心是Pod，然后围绕Pod，Kubernetes扮演了一个Pod集群编排的角色，在此基础上它又为这些Pod集群提供了副本管理（ReplicationController）和访问代理（Service）的能力。所以，Kubernetes实际上更贴近Swarm这样的Docker容器集群管理工具，只不过它的管理单位是Pod。这样的定位与Borg专注于支撑内部任务并且最大程度地提高资源利用率的初衷是不一样的。很难想像会有人把KVM或者MapReduce Job跑在Kubernetes上，而这些却是Borg的典型任务。

相比之下，Mesos关注的核心问题是集群环境下任务资源的分配和调度，这与Borg的一部分目标很接近。但是，两层调度策略决定了Mesos本身的实现是十分轻量的，它的大部分工作在于如何在兼顾公平和效率的情况下向上层框架提供合理的资源邀约，至于对运行其上的任务本身Mesos的关注并不算多（交给上层framework负责即可）。

那么有没有一个开源项目能够配上开源版Borg的称号呢？目前看来是：Aurora+Mesos。

Apache Aurora项目在Mesos的基础上提供了很多非常有意思的特性，这其中就包括了同时运行batch job和普通应用，任务优先级和资源抢占的能力。当然，从时间点上来看很可能是Aurora借鉴了Borg的思想，但最关键的是，Aurora把集群利用率的提高当作了该项目的主要目标之一，这才使得它与Borg产生了更多的交集。

当然，至于选择哪种，就完全是取决于用户的需求了。从各个项目的发展上来看，集群规模不大又需要Pod概念的话，直接使用Kubernetes就足够了，但如果是互联网企业部署自己内部的私有云的话，还是建议先搭一层Mesos作为集群资源的抽象（已经有自己的资源编排平台的同学除外，比如百度Matrix这类），然后使用不同的framework（包括Aurora，Marathon以及Kubernetes本身）来满足不同场景的需求。

最后说一句，作为Borg的同源衍生项目，Kubernetes的Roadmap里还有很多Borg的优秀特性待实现，比如我们前面提到过的资源模型，对batch job的支持等都是很好的例子。可以预见，Kubernetes接下来很有可能会发展成为一个『大量借鉴Borg优秀思想、架构、以及代码实现』的一个加强版Swarm，这本身确实很让人期待，这也是目前Kubernetes在用户眼中可能要比Mesos稍胜一筹的原因之一。更何况，Google已经与Mesos达成了战略合作，Kubernetes和Mesos今后的分工会更加明确，重叠功能会更少。这也意味着在核心功能足够完善前，Kubernetes对资源利用率提升等问题上的重视程度依然不会非常高。

无论如何，当Docker遇上Borg，这绝对是一件非常有意义的事情。在后续的文章里，我们会进一步对以Docker为核心的容器集群的编排管理、调度、监控和性能优化进行更多的深入的剖析和解读。
