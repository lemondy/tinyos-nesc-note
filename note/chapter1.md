##Chapter1

1. Main是程序的入口组件，具体的说是Main.StdControl.init()是tingyos执行的第一个函数，这之后接着执行的是Main.StdControl.start()。

2. nesc中的接口之间的关系用"->"符号来声明，左边组件的接口use右边组件提供的provide接口

3. BlinkM.nc程序中部分代码如下:
```
    module BlinkM{
      provides{
        interface StdControl;    //模块中自己提供的接口，必须在本模块中进行实现
      }
      uses{
        interface Timer;        //对已要使用的接口，可以通过call调用其中的command函数，要实现接口定义的event函数
        interface Leds;
      }
    }
    //Continued below...
```

4.我们可以在implementation花括号之后定义全局变量，也可以在函数中定义局部变量。对于在函数中定义的局部变量，必须写在函数内部最开始的位置，否则会报错。
    
