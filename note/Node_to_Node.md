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
