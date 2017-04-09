grpc 的协议分析
============

grpc 和通常的基于TCP的实现不同，是直接基于HTTP2 协议的。HTTP2 使得grpc 能够更好的适用于移动客户端和服务端通信的使用场景，并且连接多路复用也保证了RPC 的效率。

grpc 的协议设计上很好的使用了HTTP2 现有的语义，请求和响应的数据使用HTTP Body 发送，其他的控制信息则用Header 表示。先看个例子，假设Protobuf 定义如下:

    package foo.bar;
    
    message HelloRequest {
      string greeting = 1;
    }
    
    message HelloResponse {
      string reply = 1;
    }
    
    service HelloService {
      rpc SayHello(HelloRequest) returns (HelloResponse);
    }
  
在这里面我们定义了一个service HelloService。grpc 为这样一个调用发送的请求为:

    HEADERS (flags = END_HEADERS)
    :method = POST
    :scheme = http
    :path = /foo.bar.HelloService/SayHello
    :authority = api.test.com
    grpc-timeout = 1S
    content-type = application/grpc+proto
    grpc-encoding = gzip
    authorization = Bearer y235.wef315yfh138vh31hv93hv8h3v
    
    DATA (flags = END_STREAM)
    <Delimited Message>
    
Http 请求的Path 部分用来表示调用哪个服务，格式是/{package}.{ServiceName}/{RpcMethodName}，content-type 目前取值都是application/grpc+proto，将来grpc 支持除Protobuf 之外的协议如Json 时，会有别的值。grpc-encoding 可以有gzip, deflate, snappy 等取值，表示采用的压缩方法。grpc-timeout 表示调用的超时时间，单位有Hour(H), Minute(M), Second(S), Millisecond(m), Microsecond(u), Nanosecond(n) 等。

除了grpc 定义的标准头之外，也可以自己添加新的头。如果是二进制的Header，则Header Name 以-bin 结尾，Header Value 是经过Base64 编码的二进制数据。

服务端对这个请求返回一个Response:

    HEADERS (flags = END_HEADERS)
    :status = 200
    grpc-encoding = gzip
    
    DATA
    <Delimited Message>
    
    HEADERS (flags = END_STREAM, END_HEADERS)
    grpc-status = 0 # OK
    trace-proto-bin = jher831yy13JHy3hc
    
grpc-status 为0 表示请求没有出现问题，成功返回。

grpc 还定义了GOAWAY Frame， 当Server 断开一个连接的时候，需要向客户端发送这样一条消息；以及PING Frame，接受到PING Frame 后直接原样返回数据，用于连接存活检测和延迟检测。

HTTP2 的Header 并不是特别高效的格式，存储上和解析上都有一些效率问题。如果启用加密连接的话，则会有更多的效率开销。
