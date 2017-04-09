gRPC - streaming
================

[__gRPC__](http://www.grpc.io)是一个高性能、通用的开源RPC框架，其由Google主要面向移动应用开发并基于HTTP/2协议标准而设计，基于ProtoBuf(Protocol Buffers)序列化协议开发，且支持众多开发语言。 gRPC提供了一种简单的方法来精确地定义服务和为iOS、Android和后台支持服务自动生成可靠性很强的客户端功能库。 客户端充分利用高级流和链接功能，从而有助于节省带宽、降低的TCP链接次数、节省CPU使用、和电池寿命。

gRPC具有以下重要特征：

强大的IDL特性 RPC使用ProtoBuf来定义服务，ProtoBuf是由Google开发的一种数据序列化协议，性能出众，得到了广泛的应用。
支持多种语言 支持C++、Java、Go、Python、Ruby、C#、Node.js、Android Java、Objective-C、PHP等编程语言。 3.基于HTTP/2标准设计

![img_01](http://colobu.com/2017/04/06/dive-into-gRPC-streaming/gRPC.png)

gRPC已经应用在Google的云服务和对外提供的API中。

gRPC开发起来非常的简单，你可以阅读 一个 [__helloworld__](https://github.com/smallnest/grpc-examples/tree/master/helloworld) 的例子来了解它的基本开发流程 (本系列文章以Go语言的开发为例)。

最基本的开发步骤是定义 proto 文件， 定义请求 Request 和 响应 Response 的格式，然后定义一个服务 Service， Service可以包含多个方法。

基本的gRPC开发很多文章都介绍过了，官方也有相关的文档，这个系列的文章也就不介绍这些基础的开发，而是想通过代码演示gRPC更深入的开发。 作为这个系列的第一篇文章，想和大家分享一下gRPC流式开发的知识。

gRPC的流可以分为三类， 客户端流式发送、服务器流式返回以及客户端／服务器同时流式处理, 也就是单向流和双向流。 下面针对这三种情况分别通过例子介绍。

### 1. 服务器流式响应

通过使用流(streaming)，你可以向服务器或者客户端发送批量的数据， 服务器和客户端在接收这些数据的时候，可以不必等所有的消息全收到后才开始响应，而是接收到第一条消息的时候就可以及时的响应， 这显然比以前的类HTTP 1.1的方式更快的提供响应，从而提高性能。

比如有一批记录个人收入数据，客户端流式发送给服务器，服务器计算出每个人的个人所得税，将结果流式发给客户端。这样客户端的发送可以和服务器端的计算并行之行，从而减少服务的延迟。这只是一个简单的例子，你可以利用流来实现RPC调用的异步执行，将客户端的调用和服务器端的执行并行的处理，

当前gRPC通过 HTTP2 协议传输，可以方便的实现 streaming 功能。 如果你对gRPC如何通过 HTTP2 传输的感兴趣， 你可以阅读这篇文章 [__gRPC over HTTP2__](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md), 它描述了 gRPC 通过 HTTP2 传输的低层格式。Request 和 Response 的格式如下：

>  Request → Request-Headers *Length-Prefixed-Message EOS
>  Response → (Response-Headers *Length-Prefixed-Message Trailers) / Trailers-Only

要实现服务器的流式响应，只需在proto中的方法定义中将响应前面加上stream标记， 如下图中SayHello1方法，HelloReply前面加上stream标识。

    syntax = "proto3";
    package pb;
    import "github.com/gogo/protobuf/gogoproto/gogo.proto";
    // The greeting service definition.
    service Greeter {
      // Sends a greeting
      rpc SayHello1 (HelloRequest) returns (stream HelloReply) {}
    }
    // The request message containing the user's name.
    message HelloRequest {
          string name = 1;
    }
    // The response message containing the greetings
    message HelloReply {
      string message = 1;
    }
    
这个例子中我使用[__gogo__](https://github.com/gogo/protobuf)来生成更有效的protobuf代码，当然你也可以使用原生的工具生成。


    GOGO_ROOT=${GOPATH}/src/github.com/gogo/protobuf
    protoc -I.:${GOPATH}/src  --gogofaster_out=plugins=grpc:. helloworld.proto
    
生成的代码就已经包含了流的处理，所以和普通的gRPC代码差别不是很大， 只需要注意的服务器端代码的实现要通过流的方式发送响应。


    func (s *server) SayHello1(in *pb.HelloRequest, gs pb.Greeter_SayHello1Server) error {
    	name := in.Name
    	for i := 0; i < 100; i++ {
    		gs.Send(&pb.HelloReply{Message: "Hello " + name + strconv.Itoa(i)})
    	}
    	return nil
    }
    
和普通的gRPC有什么区别？

普通的gRPC是直接返回一个HelloReply对象，而流式响应你可以通过Send方法返回多个HelloReply对象，对象流序列化后流式返回。

查看它低层的实现其实是使用ServerStream.SendMsg实现的。


    type Greeter_SayHello1Server interface {
    	Send(*HelloReply) error
    	grpc.ServerStream
    }
    func (x *greeterSayHello1Server) Send(m *HelloReply) error {
    	return x.ServerStream.SendMsg(m)
    }
    
对于客户端，我们需要关注两个方面有没有变化， 一是发送请求，一是读取响应。下面是客户端的代码：


       conn, err := grpc.Dial(*address, grpc.WithInsecure())
       if err != nil {
       	log.Fatalf("faild to connect: %v", err)
       }
       defer conn.Close()
       c := pb.NewGreeterClient(conn)
    stream, err := c.SayHello1(context.Background(), &pb.HelloRequest{Name: *name})
    if err != nil {
    	log.Fatalf("could not greet: %v", err)
    }
    for {
    	reply, err := stream.Recv()
      	if err == io.EOF {
    		break
    	}
    	if err != nil {
    		log.Printf("failed to recv: %v", err)
    	}
    	log.Printf("Greeting: %s", reply.Message)
    }
    
发送请求看起来没有太大的区别，只是返回结果不再是一个单一的HelloReply对象，而是一个Stream。这和服务器端代码正好对应，通过调用stream.Recv()返回每一个HelloReply对象， 直到出错或者流结束(io.EOF)。

可以看出，生成的代码提供了往/从流中方便的发送／读取对象的能力，而这一切， gRPC都帮你生成好了。

### 2. 客户端流式发送

客户端也可以流式的发送对象，当然这些对象也和上面的一样，都是同一类型的对象。

首先还是要在proto文件中定义，与上面的定义类似，在请求的前面加上stream标识。

    syntax = "proto3";
    package pb;
    import "github.com/gogo/protobuf/gogoproto/gogo.proto";
    option (gogoproto.unmarshaler_all) = true;
    // The greeting service definition.
    service Greeter {
      rpc SayHello2 (stream HelloRequest) returns (HelloReply) {}
    }
    // The request message containing the user's name.
    message HelloRequest {
      string name = 1;
    }
    // The response message containing the greetings
    message HelloReply {
      string message = 1;
    }
    
注意这里我们只标记了请求是流式的， 响应还是以前的样子。

生成相关的代码后， 客户端的代码为:


    func sayHello2(c pb.GreeterClient) {
    	var err error
    	stream, err := c.SayHello2(context.Background())
    	for i := 0; i < 100; i++ {
    		if err != nil {
    			log.Printf("failed to call: %v", err)
    			break
    		}
    		stream.Send(&pb.HelloRequest{Name: *name + strconv.Itoa(i)})
    	}
    	reply, err := stream.CloseAndRecv()
    	if err != nil {
    		fmt.Printf("failed to recv: %v", err)
    	}
    	log.Printf("Greeting: %s", reply.Message)
    }
    
这里的调用c.SayHello2并没有直接穿入请求参数，而是返回一个stream，通过这个stream的Send发送，我们可以将对象流式发送。这个例子中我们发送了100个请求。

客户端读取的方法是stream.CloseAndRecv(),读取完毕会关闭这个流的发送，这个方法返回最终结果。注意客户端只负责关闭流的发送。

服务器端的代码如下：

    func (s *server) SayHello2(gs pb.Greeter_SayHello2Server) error {
    	var names []string
    	for {
    		in, err := gs.Recv()
    		if err == io.EOF {
    			gs.SendAndClose(&pb.HelloReply{Message: "Hello " + strings.Join(names, ",")})
    			return nil
    		}
    		if err != nil {
    			log.Printf("failed to recv: %v", err)
    			return err
    		}
    		names = append(names, in.Name)
    	}
    	return nil
    }
    
服务器端收到每条消息都进行了处理，这里的处理简化为增加到一个slice中。一旦它检测的客户端关闭了流的发送，它则把最终结果发送给客户端，通过关闭这个流。流的关闭通过io.EOF这个error来区分。

### 3. 双向流

将上面两个例子整合，就是双向流的例子。 客户端流式发送，服务器端流式响应，所有的发送和读取都是流式处理的。

proto中的定义如下, 请求和响应的前面都加上了stream标识:

    syntax = "proto3";
    package pb;
    import "github.com/gogo/protobuf/gogoproto/gogo.proto";
    // The greeting service definition.
    service Greeter {
      rpc SayHello3 (stream HelloRequest) returns (stream HelloReply) {}
    }
    // The request message containing the user's name.
    message HelloRequest {
      string name = 1;
    }
    // The response message containing the greetings
    message HelloReply {
      string message = 1;
    }
    
客户端的代码:


    func sayHello3(c pb.GreeterClient) {
    	var err error
    	stream, err := c.SayHello3(context.Background())
    	if err != nil {
    		log.Printf("failed to call: %v", err)
    		return
    	}
    	var i int64
    	for {
    		stream.Send(&pb.HelloRequest{Name: *name + strconv.FormatInt(i, 10)})
    		if err != nil {
	    		log.Printf("failed to send: %v", err)
	    		break
	    	}
    		reply, err := stream.Recv()
    		if err != nil {
    			log.Printf("failed to recv: %v", err)
    			break
    		}
    		log.Printf("Greeting: %s", reply.Message)
    		i++
    	}
    }
    
通过stream.Send发送请求，通过stream.Recv读取响应。客户端可以通过CloseSend方法关闭发送流。

服务器端代码也是通过Send发送响应，通过Recv响应:

    func (s *server) SayHello3(gs pb.Greeter_SayHello3Server) error {
    	for {
    		in, err := gs.Recv()
    		if err == io.EOF {
    			return nil
    		}
    		if err != nil {
    			log.Printf("failed to recv: %v", err)
    			return err
    		}
    		gs.Send(&pb.HelloReply{Message: "Hello " + in.Name})
    	}
    	return nil
    }
    
这基本上"退化"成一个TCP的client和server的架构。

在实际的应用中，你可以根据你的场景来使用单向流还是双向流。

[阅读原文](http://colobu.com/2017/04/06/dive-into-gRPC-streaming/)
