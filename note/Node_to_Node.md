## Node_to_Node radio communication
 
> 这次笔记记录的是节点与节点之间通信的知识。
 
###**注意：**

- 看完之后知道message_t结构的作用,它是在TinyOS 2.0中提供的消息机制；
- 怎样通过无线方式发送信息；
- 怎样接受无线信息。

###前言
TinyOS中提供了许多的接口，用来对底层通信进行抽象，接着系统中许多的组件提供该接口(实现了该接口)。所有这些接口和组件共用一个抽象的消息缓冲对象，称为message_t。它是nesc语言定义的一个结构体
，它对于用户来说是透明的，用户不能直接访问该对象，而是要通过系统提供的访问器来对其进行操作。

###message_t介绍
首先我们看下系统定义的message_t结构体：

	typedef nx_struct message_t{
    	nx_uint8_t header[sizeof(message_header_t)];
		nx_uint8_t data[TOSH_DATA_LENGTH];
		nx_uint8_t footer[sizeof(message_footer_t)];
		nx_uint8_t metadata[sizeof(message_metadata_t)];
	}message_t;

上述代码描述通信协议中数据格式。message_t结构体就是数据包传送的格式，类似计算机网络中的各种数据包或者MAC帧。

**注意：**该结构体中的header、footer和metadata字段是透明的，不能直接访问。我们只能通过接下要介绍的Packet,AMPacket等一些接口来访问。这种方式的基本原理是，它允许数据(负载payload)在传送过程中保持在固定的偏移位置，avoiding a copy when a message is passed between two link layers.

###基本通信接口
系统提供了许多接口和组件，他们都利用message_t作为隐含的数据结构。他们位于`tos/interface`目录下面。

- Packet： 该接口提供了对message_t数据类型的基本操作。这些操作包括清空消息的内容，取得负载payload的长度，得到指向payload的地址指针。
- Send: 提供了不基于地址发送消息操作。该接口提供了command函数用于发送消息和取消还未发送完成的消息。同时提供了event事件函数来指示消息的发送成功与否。它还提供了方便的函数来获得消息最大的payload和指向payload区域的指针。如：
	command void* getPayload(message_t* msg,uint8_t)
	command uint8_t maxPayloadLength()
	command error_t send(message_t* msg, uint8_t len)
- Receive： 该接口提供了消息接收基本操作。其中常用的方法是`event message_t* receive(message_t* msg,void* payload,uint8_t len)`，这个event函数用来接收消息。它同样提供了一些command来获取最大payload长度和指向payload区域的指针。
- PacketAcknowledgements： 提供了一种机制对于每一个包需要确认包。
	command error_t noAck(message_t* msg)
	command error_t requestAck(message_t* msg)
- RadioTimeStamping： 提供了对于无线发送和接受的数据包添加时间戳的功能。

###Active Message接口(通信机制，重点！！！)
利用同一无线信道提供多种服务进行通信的方式是很常用的，TinyOS 提供了Active Message(AM)层来多路访问无线信道。术语“AM Type”指的是该字段利用多路访问机制。AM Type的功能和以太帧中的MAC地址字段，IP协议中的地址字段，和UDP协议中的端口字段相似，它提供了多路访问来进行通信服务。AM包包括目的地址字段，该字段存在存储在"AM address"中，这个说明该包要发送的目标。该接口位于`tos/interfaces`目录下面，AM服务提供了一下两个接口。

- AMPacket： 和Packet接口类似，提供了对message_t抽象数据类型的访问操作。这个接口提供了command函数获取节点的AM地址，AM包的目的地址和AM包的类型。同样提供了command函数设置AM包的目的地址，检查目标地址是否是本节点。

		command am_addr_t address()  //本节点的AM地址
		command am_addr_t destination(message_t* amsg) //目标节点的AM地址
		command am_addr_t source(message_t* msg) //该AM包发送的源地址 
- AMSend： 和Send接口类似，提供了基本AM消息发送的基本接口。它与Send不用的关键点在于AMSend在send函数中需要指定AM包的目的地址。

节点的AM地址可以在程序安装的时候进行指定，使用`make telosb install,ID`命令。可以在运行期间进行改变，通过`ActiveMessageAddressC`组件修改。

###基本组件
许多组件实现了基本的通信和 active message 接口。这些组件位于`tos/system`目录下面。常用的组件为：

- AMReceiverC:  提供(provides)了如下接口：Receive, Packet， AMPacket
- AMSenderC: 提供了(provides)如下接口：AMSend， Packet， AMPacket， PacketAcknowledegements as Acks
- AMSnooperC： 提供了(provides)如下接口：Receive, Packet, AMPacket
- AMSnoopingReceiverC: 提供了(provides)如下接口：Receive, Packet, AMPacket
- ActiveMessageAddressC： 提供了commands来得到和设置节点的active message地址。这个接口不是为普通用户提供的来操作AM地址，如果这样做了回事网络栈崩溃，因此，除非你对网络很清楚，否则别使用这个接口。

###Naming Wrappers
由于TinyOS支持许多平台(例如telosb,MicaZ等)，每一个平台对于无线的驱动等实现会不同，因此需要一个中间部分将底层与上层的进行连接起来。naming wrapper称为`ActiveMessageC`，就是起中间桥接作用。`ActiveMessageC`提供了许多通信接口。

###程序示例
节点与节点之间的通信代码请查看`code/BlinkToRadio`目录下面的程序。在该程序中提供了注释，对程序的说明。
