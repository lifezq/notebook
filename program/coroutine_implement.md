Coroutine及其实现
================

线程是内核对外提供的服务，应用程序可以通过系统调用让内核启动线程，由内核来负责线程调度和切换。线程在等待IO操作时线程变为unrunnable状态会触发上下文切换。现代操作系统一般都采用抢占式调度，上下文切换一般发生在时钟中断和系统调用返回前，调度器计算当前线程的时间片，如果需要切换就从运行队列中选出一个目标线程，保存当前线程的环境，并且恢复目标线程的运行环境，最典型的就是切换ESP指向目标线程内核堆栈，将EIP指向目标线程上次被调度出时的指令地址。

协程也叫用户态线程，协程之间的切换发生在用户态。在用户态没有时钟中断，系统调用等机制，那么协程切换由什么触发？调度器将控制权交给某个协程后，控制权什么时候回到调度器，从而调度另外一个协程运行？ 实际上，这需要协程主动放弃CPU，控制权回到调度器，从而调度另外一个协程运行。所谓协作式线程(cooperative)，需要协程之间互相协作，不需要使用CPU时将CPU主动让出。

协程切换和内核线程的上下文切换相同，也需要有机制来保存当前上下文，恢复目标上下文。在POSIX系统上，getcontext/makecontext/swapcontext等可以用来做这件事。

协程带来的最大的好处就是可以用同步的方式来写异步的程序。比如协程A，B：A是工作协程，B是网络IO协程(这种模型下，实际工作协程会比网络IO协程多)，A发送一个包时只需要将包push到A和B之间的一个channel，然后就可以主动放弃CPU，让出CPU给其它协程运行，B从channel中pop出将要发送的包，接收到包响应后，将结果放到A能拿到的地方，然后将A标识为ready状态，放入可运行队列等待调度，A下次被调度器调度就可以拿到结果继续做后面的事情。如果是基于线程的模型，A和B都是线程，通常基于回调的方式，1. A阻塞在某个队列Q上，B接受到响应包回调A传给B的回调函数f，回调函数f将响应包push到Q中，A可以取到响应包继续干活，如果阻塞基于cond等机制，则会被OS调度出去，如果忙等，则耗费CPU。2. A可以不阻塞在Q上，而是继续做别的事情，可以定期过来取结果。 这种情况下，线程模型业务逻辑其实被打乱了，发包和取包响应的过程被隔离开了。

实现协程库的基本思路很简单，每个线程一个调度器，就是一个循环，不断的从可运行队列中取出协程，并且利用swapcontext恢复协程的上下文从而继续执行协程。当一个协程放弃CPU时，通过swapcontext恢复调度器上下文从而将控制权归还给调度器，调度器从可运行队列选择下一个协程。每个协程初始化通过getcontext和makecontext，需要的栈空间从堆上分配即可。

以下分析一个简单的协程库libtask，由golang team成员之一的Russ cox在加入golang team之前开发。只支持单线程，简单包装了一下read/write等同步IO。

   在libtask中，一个协程用一个struct Task来表示：


    struct Task        
    { 
      char  name[256];  // offset known to acid
      char  state[256];
      Task  *next; //通过这两个指针将task串起来
      Task  *prev;
      Task  *allnext;
      Task  *allprev;
      Context context;// 当前协程上下文
      uvlong  alarmtime;
      uint  id;
      uchar *stk; // 当前协程可以使用的堆栈，初始化为栈顶地址
      uint  stksize;// 当前协程可以使用的堆栈大小
      int exiting;
      int alltaskslot;
      int system;
      int ready;
      void  (*startfn)(void*);//当前协程的执行入口函数
      void  *startarg;//参数
      void  *udata;
    };
    

 下面看看新增一个协程的过程：


    static Task*
    taskalloc(void (*fn)(void*), void *arg, uint stack)
    {                                                                                                                                                                    
      Task *t;
      sigset_t zero;
      uint x, y;
      ulong z;
    
      /* allocate the task and stack together */
      t = malloc(sizeof *t+stack);     //在堆上为这个协程分配结构体和协程所使用的堆栈
      if(t == nil){
        fprint(2, "taskalloc malloc: %r\n");
        abort();
      }
      memset(t, 0, sizeof *t);
      t->stk = (uchar*)(t+1);
      t->stksize = stack;
      t->id = ++taskidgen;
      t->startfn = fn;                // 协程入口函数
      t->startarg = arg;              // 协程入口函数参数
    
      /* do a reasonable initialization */
      memset(&t->context.uc, 0, sizeof t->context.uc);
      sigemptyset(&zero);
      sigprocmask(SIG_BLOCK, &zero, &t->context.uc.uc_sigmask);
    
      /* must initialize with current context */
      if(getcontext(&t->context.uc) < 0){              // 初始化当前协程上下文
        fprint(2, "getcontext: %r\n");
        abort();
      }
    
      /* call makecontext to do the real work. */
      /* leave a few words open on both ends */
      t->context.uc.uc_stack.ss_sp = t->stk+8;          //ss_sp成员为栈顶地址，后续makecontext会将ss_sp往高地址移动ss_size个字节，从这里开始压栈
      t->context.uc.uc_stack.ss_size = t->stksize-64;   //ss_size成员为栈大小
    #if defined(__sun__) && !defined(__MAKECONTEXT_V2_SOURCE)   /* sigh */
    #warning "doing sun thing"
      /* can avoid this with __MAKECONTEXT_V2_SOURCE but only on SunOS 5.9 */
      t->context.uc.uc_stack.ss_sp = 
        (char*)t->context.uc.uc_stack.ss_sp
        +t->context.uc.uc_stack.ss_size;
    #endif
      /*
       * All this magic is because you have to pass makecontext a
       * function that takes some number of word-sized variables,
       * and on 64-bit machines pointers are bigger than words.
       */
    //print("make %p\n", t);
      z = (ulong)t;
      y = z;
      z >>= 16; /* hide undefined 32-bit shift from 32-bit compilers */
      x = z>>16;
      makecontext(&t->context.uc, (void(*)())taskstart, 2, y, x);       // 协程入口函数为taskstart，y,x两个参数会被压到t->context.uc.uc_stack栈底
      return t;
    }
    

 

 然后调用taskready将这个协程放入可运行队列中:


    void
    taskready(Task *t)
    {
      t->ready = 1; //
      addtask(&taskrunqueue, t);   //将协程放入到可运行队列中，后续调度器就可以从taskrunqueue中拿到它了。taskrunqueue就是一个全局变量，libtask只支持单线程从这里也可以看出来
    }
    

现在可以看看调度器：

    static void
    taskscheduler(void)
    {
      int i;
      Task *t;
    
      taskdebug("scheduler enter");
      for(;;){                          //无限循环
        if(taskcount == 0)
          exit(taskexitval);
        t = taskrunqueue.head;          //从可运行队列头部取出下一个运行的协程
        if(t == nil){
          fprint(2, "no runnable tasks! %d tasks stalled\n", taskcount);
          exit(1);
        }
        deltask(&taskrunqueue, t);      //从可运行队列中将它删除
        t->ready = 0;
        taskrunning = t;                //将t设置为当前正在运行的协程，taskrunning是一个全局变量
        tasknswitch++;                  //统计值，协程一共执行了多少次
        taskdebug("run %d (%s)", t->id, t->name);
        contextswitch(&taskschedcontext, &t->context);    // 通过swapcontext切换到目标协程，并且将调度器上下文保存在全局变量taskschedcontext中
    //print("back in scheduler\n"); taskrunning = nil; if(t->exiting){ if(!t->system) taskcount--; i = t->alltaskslot; alltask[i] = alltask[--nalltask]; alltask[i]->alltaskslot = i; free(t); } } }


协程主动放弃CPU调用taskyield：


    int
    taskyield(void)         
    {
      int n;
      n = tasknswitch;
      taskready(taskrunning); // 将自己设置为ready重新放回可运行队列
      taskstate("yield");
      taskswitch();           //将控制权还给调度器
      return tasknswitch - n - 1;
    }
    

看看taskswitch：


    void
    taskswitch(void)
    {
      needstack(0);     // 检查当前协程是否堆栈溢出，如果溢出，程序退出
      contextswitch(&taskrunning->context, &taskschedcontext);     // 切换到 taskschedcontext 上下文，从上面调度器循环可以看出，它就是调度器上下文
    }
    

看看如何检查协程堆栈溢出：


    void
    needstack(int n)
    {
        Task *t;           
        t = taskrunning;                  // t是个栈变量，当前协程是taskrunning
        if((char*)&t <= (char*)t->stk     // t是taskrunning， stk是taskrunning这个协程的栈顶，栈的增长方向是从高到低，stk是低地址，显然，t这个局部变量的地址小于stk时，栈溢出
        || (char*)&t - (char*)t->stk < 256+n){     // 如果离stk的地址小于256+n，则同样说明溢出，为什么这里需要预留256+n，不太清楚。
            fprint(2, "task stack overflow: &t=%p tstk=%p n=%d\n", &t, t->stk, 256+n);
            abort();
        }
    }
    

最后看看contextswitch:


    static void
    contextswitch(Context *from, Context *to)
    {
      if(swapcontext(&from->uc, &to->uc) < 0){   //调用swapcontext切换到to->uc协程
        fprint(2, "swapcontext failed: %r\n");
        assert(0);
      }
    }
    

taskswitch之后控制权回到调度器，调度器就继续从可运行队列中取出下一个协程运行了。

下面看看makecontext：


    void
    makecontext(ucontext_t *ucp, void (*func)(void), int argc, ...)
    {
        int *sp;
    
        sp = (int*)ucp->uc_stack.ss_sp+ucp->uc_stack.ss_size/4; // 将sp移动到分配的栈空间的最高地址
        sp -= argc;  // 往栈低地址方向留出argc个sizeof(int)空间用于后续压argc个int参数进栈 
        sp = (void*)((uintptr_t)sp - (uintptr_t)sp%16);    /* 16-align for OS X */
        memmove(sp, &argc+1, argc*sizeof(int));    //将argc后面的int参数进栈
    
        *--sp = 0;        /* return address */     // 函数返回后执行的下一条指令，这个返回值没用，因为协程是由外部调度器调度的。
        ucp->uc_mcontext.mc_eip = (long)func;      //设置IP
        ucp->uc_mcontext.mc_esp = (int)sp;        //设置当前栈顶，告诉func从哪里分配栈变量
    }
    

由于函数调用返回，压栈顺序，栈帧的变化参看：http://www.cnblogs.com/foxmailed/archive/2013/01/29/2881402.html

以上就是协程相关的全部流程。

后续分析同步IO操作的封装。


[阅读原文](http://www.cnblogs.com/foxmailed/p/3509359.html)

