##节点和电脑通信

这次的笔记是记录节点和电脑之间通信方式。从而能够掌握从网络中收集数据，向节点发送命令，和监控网络的拥塞情况。

这次我们会利用一个基于 Java 的接口来与节点进行通信，同样也存在其他的一些像 C语言，python等接口。你可以在系统 `support/sdk/`目录下找到它支持的语言。

###内容概要###
1. Packet sources and TestSerial
2. BaseStation and net.tinyos.tools.Listen
3. MIG:gnerating packet objects
4. SerialForwarder and other packet sources
	4.1 Packet Sources
	4.2 The tool sides
5. Sending a packet to the serial port in Tinyos

###Packet sources and TestSerial ###

首先确定你使用的平台支持与电脑进行通信。大多数的节点都有一个串口或者类似的接口。例如，mica家族系列可以直接在主板上控制串口。Telos节点同样有串口接口，但是得通过usb接口电脑才能和节点通信。

对mote-pc通信基本的抽象是packet source。 packet source指的是通信媒介能够通过应用程序从节点接收数据和发送数据给节点。packet sources的实例包括串口，TCP sockets, 和 SerialForwarder 工具。大多数Tinyos通信工具携带一个参数 `-comm`，这样就允许你利用字符串的形式指定一个packet source。例如：

```
$ java net.tinyos.tools.Listen -comm serial@/dev/ttyUSB0：telosb
```

上面的命令告诉监听工具监听/dev/ttyUSB0(在unix型机器上的形式)串口，从而监听节点。

我们以`apps/tests/TestSerial`程序为例。这个程序每秒给串口发送一个包，当节点接收到数据包时，它就通过LEDS显示包的序列号。当在节点上烧录了程序之后，你需要运行一个相应的 Java 程序，它与节点通过串口通信。在该目录下面，运行如下命令：

```
$ java TestSerial
```

如果出现如下语句：

```
The java class is not found: TestSerial
```

这个意味着你要么没有编译过TestSerial.java文件，要么就是TestSerial.java文件不存在。

由于在上面运行 Java 程序中没有指定与那个节点通信，TestSerial 就会与一个默认的的进行通信，而这个默认的就是SerialForwarder。 如果此时你电脑上没有运行SerialForwarder， TestSerial就会退出，提示没能找到节点连接。因此正确的写法如下：

```
$ java TestSerial -comm serial@/dev/ttyUSB0:telosb
```

在`-comm`后面指定的是`serial@<port>:<speed>`.每个平台有不用的发送速率，你可以用数字的形式指定，也可以利用平台默认的速率。

		Platform     Speed(baud)
		_________________________
		telos		 115200
		telosb 		 115200
		micaz		 57600
		mica2dot	 19200

在linux上你需要让串口可读，你可以运行如下命令：

```
chmod 666 serialport
```

在文件`/sdk/java/net/tinyos/packet/BaudRate.java`中指定了平台与其默认速率关系。

如果你运行`TestSerial`以合适的端口和速率，你应该可以看到如下的输出语句：

```
Sending packet 1
Received packet sequence number 4
Sending packet 2
Received packet sequence number 5
Sending packet 3
Received packet sequence number 6
Sending packet 4
Received packet sequence number 7
```
并且LEDS灯在闪烁。

###BaseStation and net.tinyos.tools.Listen ###

基站是Tinyos中比较常用的应用。它作为一个串口和无线网络之间的桥梁。当它从串口中接收到数据后，它就通过无线射频转发该数据；当它从无线网络中接收到数据后，它通过串口转发给节点。利用基站程序允许 PC 工具直接和节点网络通信。

节点1烧录BlinkToRadio程序，节点2烧录BaseStation程序。如果节点1启动了，你可以看节点2的 LED1 在闪烁。当节点2的发送数据给无线网络 LED0 会闪烁，同时当它发送数据给串口时 LED1 灯会闪烁。当它丢掉一个包时它会闪烁 LED2 灯。

BaseStation 接收的 BlinkToRadio 发送的数据，接着将他们通过串口发送给电脑。Java 监听工具是个基础的数据包监听器：它以二进制的形式打印出任何它监听的数据包。利用如下形式监听,要添加`-comm`参数：

	$ java net.tinyos.tools.Listen
 
可以看到如下的输出：

	00 FF FF 00 00 04 22 06 00 02 00 01
	00 FF FF 00 00 04 22 06 00 02 00 02
	00 FF FF 00 00 04 22 06 00 02 00 03
	00 FF FF 00 00 04 22 06 00 02 00 04
	00 FF FF 00 00 04 22 06 00 02 00 05
	00 FF FF 00 00 04 22 06 00 02 00 06
	00 FF FF 00 00 04 22 06 00 02 00 07
	00 FF FF 00 00 04 22 06 00 02 00 08
	00 FF FF 00 00 04 22 06 00 02 00 09
	00 FF FF 00 00 04 22 06 00 02 00 0A
	00 FF FF 00 00 04 22 06 00 02 00 0B

Listen工具仅仅是打印出从节点接收到的数据。从节点接收到的数据可以分为几个字段。第一个字节(00)表明这个包是AM包。接下来的 Active Message 字段，他们定义在 `tinyos-2.x/tos/lib/serial/Serial.h`文件中。最后剩下的是数据 payload 区域。 它是定义在 BlinkToRadio.h 文件中，如下：

	typedef nx_struct BlinkToRadioMsg {
		nx_uint16_t nodeid;
		nx_uint16_t counter;
	}BlinkToRadioMsg; 

接收到的数据包整体结构如下(省略掉开始的00)：

- 目的地址(2字节)
- 链路层源地址(2字节)
- 消息长度(1字节)
- 组ID（1字节）
- Active Message类型(1字节)
- 负载区域(最大28字节)
	- nodeid
	- counter

因此该数据的整体结构如下：

![](./packet_descripte.png)

节点发送的数据大端存储的，例如，01 02就表示258(256*1+2)。数据的格式与处理器端向无关，因为包的格式是nx_struct类型，这个是网络格式，也就是，大端表示和字节对齐。利用nx_struct(而不是标准的 C struct)格式表示消息的负载确保在不同的平台上的一致性。
