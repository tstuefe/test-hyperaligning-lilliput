
find . -name errlog* -print0 | xargs -0 ack  'L1-dcache-load' > l1-cache.txt
awk \
'/-A.txt.*L1-dcache-load-misses/ \
{ print "A", $2; A=$2 } \
/-B.txt.*L1-dcache-load-misses/ \
{ print "B", $2; print "Delta Percent", ($2*100)/A } ' l1-cache.txt

