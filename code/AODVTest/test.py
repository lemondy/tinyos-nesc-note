#! /usr/bin/python
from TOSSIM import *
import sys

t = Tossim([])
r = t.radio()
f = open("topology.txt", "r")

num_node = 25
end_time = 2.5 #second

lines = f.readlines()
for line in lines:
  s = line.split()     #默认用空格分开
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Boot", sys.stdout)   #对三个channel的输出，都是输出到边准输出窗口里
t.addChannel("APPS", sys.stdout)
t.addChannel("AODV", sys.stdout)
#t.addChannel("AODV_DBG2", sys.stdout)
#t.addChannel("TossimPacketModelC", sys.stdout)
#t.addChannel("CpmModelC", sys.stdout)

noise = open("noise.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()         #无参数时，默认删除空白符（包括'\n','\t','\r',''）
  if (str != ""):
    val = int(str)
    for i in range(1, num_node+1):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, num_node+1):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()
  t.getNode(i).bootAtTime(1000 * i);

while True:
  t.runNextEvent()
  if t.time() > end_time * 10000000000:
    break

