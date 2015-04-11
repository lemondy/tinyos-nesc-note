##Chapter1

###1. Main是程序的入口组件，具体的说是Main.StdControl.init()是tingyos执行的第一个函数，这之后接着执行的是Main.StdControl.start()。

###2. nesc中的接口之间的关系用"->"符号来声明，左边组件的接口use右边组件提供的provide接口

###3. BlinkM.nc程序中部分代码如下:
```
    module BlinkM{
      provides{
        interface StdControl;
      }
      uses{
        interface Timer;
        interface Leds;
      }
    }
    //Continued below...
    
