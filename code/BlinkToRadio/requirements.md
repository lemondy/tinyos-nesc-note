##问题说明
1. 实现一个节点控制亮灯读数，一个节点控制亮灯状态
2. 具体要求：节点1与节点2和节点3通信，节点1接收节点2的计数器后，保存该计数器值但不亮灯，节点1收到节点3计数值后，该值为偶数时，触发亮灯，否则，不亮灯。节点2与节点3的计数值都为自增字段。节点3的Timer1.5秒，节点2的Timer间隔250毫秒。
3. 效果：节点1，节点2和节点3都开着的时候，节点1亮灯在1.5秒内变换，在下一个1.5秒内灭灯。此时按住节点3RESET，节点1停在当前亮灯状态(如果是亮，则读书变换，如果是灭，则一直是灭)。然后节点3 RESET松开，按住节点2 RESET，节点1每隔1.5秒亮闪一次，当读数不变。
4. 提示：需要分辨节点的编号来设置不同的状态。