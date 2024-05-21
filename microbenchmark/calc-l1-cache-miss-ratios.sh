find . -name errlog* -print0 | xargs -0 ack L1-dcache-load | sed 's/,//g' > l1-cache.txt

awk '
/.*errlog-A.*L1-dcache-load-misses/ { print; A=$2 } \
/.*errlog-B.*L1-dcache-load-misses/ { print; print (($2 * 100) / A); A=0 } \
' l1-cache.txt


