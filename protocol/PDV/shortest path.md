##Shortest Path##
最短路径问题是解决图中两点之间的最短路径问题。算法的具体形式包括：

- **确定起点的最短路径问题：**即已知起点，求最短路径问题。使用的算法为Dijkstra(迪杰斯特拉)算法。(这个最短路径指的是起点确定，依次找到起点到其他点的最短路径)
- **确定终点的最短路径问题：**已知终点，求最短路径问题。在无向图中该问题与确定起点问题相同，但在有向图中该问题等同于把所有路径方向反转的确定起点的问题。
- **确定起点和终点的最短路径问题：**求两个定点之间的最短路径。
- **全局最短路径问题：**图中任意两个点之间的最短路径问题。使用Floyd-Warshall算法。

常用的最短路径算法：

- [Dijkstra算法](http://zh.wikipedia.org/wiki/%E6%88%B4%E5%85%8B%E6%96%AF%E7%89%B9%E6%8B%89%E7%AE%97%E6%B3%95)
- [A*算法](http://zh.wikipedia.org/wiki/A*%E6%90%9C%E5%AF%BB%E7%AE%97%E6%B3%95)
- [Bellman-Ford算法](http://zh.wikipedia.org/wiki/%E8%B4%9D%E5%B0%94%E6%9B%BC-%E7%A6%8F%E7%89%B9%E7%AE%97%E6%B3%95)
- [SPFA算法](http://zh.wikipedia.org/wiki/%E8%B4%9D%E5%B0%94%E6%9B%BC-%E7%A6%8F%E7%89%B9%E7%AE%97%E6%B3%95)
- [Floyd-Warshall算法](http://zh.wikipedia.org/wiki/Floyd-Warshall%E7%AE%97%E6%B3%95)
- [Johnson算法](http://zh.wikipedia.org/w/index.php?title=Johnson%E7%AE%97%E6%B3%95&action=edit&redlink=1)
- [Bi-Direction BFS算法](http://zh.wikipedia.org/w/index.php?title=Bi-Direction_BFS%E7%AE%97%E6%B3%95&action=edit&redlink=1)
