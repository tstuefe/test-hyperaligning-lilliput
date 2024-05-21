export PERF_COMMAND="perf stat  -B -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads  "

bash ./measure-all.sh

