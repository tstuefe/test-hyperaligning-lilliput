
# Env vars:
# JDK_A_NAME .. JDK_D_NAME: name of jdk dir
# OPTIONS_A .. OPTIONS_D: optional options for JVM A..D
# NUM_CLASSES: number of classes (default 8192)
# USEGC: which GC to use (literally, the -XX:+UseXX option) (default G1)
# NUM_FULL_GC: How many GCs (default 100)
# PERF_COMMAND: Perf stat line, optional
# ISOLATE_CPUS_COMMAND: cpu isolation. Defaults to isolation on core 8..15
# PERF_STAT_COMMAND: perf stat. Defaults to cache statistics.

ONLY_POST_PROCESSING=0
if [[ "$#" -eq 1 ]]; then
	if [[ "$1" == "--only-post" ]]; then
		echo "Only post processing..."
		ONLY_POST_PROCESSING=1
	fi
	
fi

# The "microbenchmark" dir
BASE_DIR=${BASE_DIR:-$PWD}

JDK_A_NAME_DEFAULT="jdk-22bit-staggered-klass-OFF"
JDK_B_NAME_DEFAULT="jdk-26bit-staggered-klass-OFF"
JDK_C_NAME_DEFAULT="jdk-22bit-klasstable-ON"
JDK_D_NAME_DEFAULT="jdk-22bit-staggered-klass-ON"

JDK_A_NAME=${JDK_A_NAME:-$JDK_A_NAME_DEFAULT}
JDK_B_NAME=${JDK_B_NAME:-$JDK_B_NAME_DEFAULT}
JDK_C_NAME=${JDK_C_NAME:-$JDK_C_NAME_DEFAULT}
JDK_D_NAME=${JDK_D_NAME:-$JDK_D_NAME_DEFAULT}

JDK_A="${BASE_DIR}/../${JDK_A_NAME}"
JDK_B="${BASE_DIR}/../${JDK_B_NAME}"
JDK_C="${BASE_DIR}/../${JDK_C_NAME}"
JDK_D="${BASE_DIR}/../${JDK_D_NAME}"

COUNT=1

# large ccs, to enforce largest possible shift
COMMON_OPTIONS="-XX:+IgnoreUnrecognizedVMOptions -Xshare:off -Xmx6g -Xms6g -XX:+AlwaysPreTouch -XX:MetaspaceSize=3g -Xlog:gc -Xlog:metaspace* -XX:CompressedClassSpaceSize=3g -XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders "

export LC_NUMERIC=en_US.UTF-8
export LANG=en_US.UTF-8

# test options
NUM_CLASSES=${NUM_CLASSES:-"4096"}
NUM_OBJECTS=`echo "scale=0; 67108864 / $NUM_CLASSES" | bc`
NUM_FULL_GC=${NUM_FULL_GC:-"100"}

CLASSSTRIDE_OPTION="--randomize"
#CLASSSTRIDE_OPTION="--class-stride 1"
#CLASSSTRIDE_OPTION="--class-stride 9"

TEST_OPTIONS="-C $NUM_CLASSES -n $NUM_OBJECTS --cycles $NUM_FULL_GC $CLASSSTRIDE_OPTION -y --nowait"

# GC
USEGC=${USEGC:-"-XX:+UseG1GC"}

# isolate to Cpus 8 to 15
ISOLATE_CPUS_COMMAND_DEFAULT="chrt -r 1 taskset 0xFF00 "
ISOLATE_CPUS_COMMAND=${ISOLATE_CPUS_COMMAND:-$ISOLATE_CPUS_COMMAND_DEFAULT}

# Perf command
PERF_COMMAND_DEFAULT=" perf stat  -B -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads "
PERF_COMMAND=${PERF_COMMAND:-$PERF_COMMAND_DEFAULT}

PRECOMMAND="$ISOLATE_CPUS_COMMAND $PERF_COMMAND "

# $1 A B or C
# $2 jdk path
# $3 jdk options
function run() {
	local LETTER=$1
	local JDK=$2
	local OPTIONS=$3
	COMMAND="${JDK}/bin/java  ${USEGC} ${COMMON_OPTIONS} ${OPTIONS} -cp ${BASE_DIR}/the-test/target/repros8-1.0.jar de.stuefe.repros.metaspace.InterleaveKlassRefsInHeap $TEST_OPTIONS"
	echo "Running $PRECOMMAND $COMMAND"
	#/usr/bin/time -f="%e" -a -o times-run${LETTER}.txt $PRECOMMAND  $COMMAND  >> outlog-${LETTER}.txt
	$PRECOMMAND  $COMMAND  >> outlog-${LETTER}.txt 2>>errlog-${LETTER}.txt
}

if [[ $ONLY_POST_PROCESSING -eq 0 ]]; then
	# remove logs from earlier runs
	rm outlog*
	rm times-run*
	rm gc-times*

	for run in `seq 1 $COUNT` ; do

		run A ${JDK_A} ${OPTION_A}
		run B ${JDK_B} ${OPTION_B}
		run C ${JDK_C} ${OPTION_C}
		run D ${JDK_D} ${OPTION_D}

	done

fi


# $1 A B or C
# $2 description
function post_process() {

	local LETTER=$1

	echo "${LETTER} ($2) gc times "

	# Filter out warmup phase, we only want to examine the explicitly issued full gcs
	awk "BEGIN {IN=0} /will start GCs\.\.\./ {IN=1} /after GCs\.\.\./ {IN=0} { if (IN==1) print }" < outlog-${LETTER}.txt > outlog-${LETTER}-no-warmup.txt

	# Now scan for GC pauses 
	ack '\[gc.*GC\(.*Pause .*ms$' outlog-${LETTER}-no-warmup.txt | sed 's/.* \([0-9\.,]*\)ms/\1/g' > gc-times-${LETTER}.txt
	datamash --header-out count 1 sum 1 median 1 sstdev 1 < gc-times-${LETTER}.txt 
}

function post_process_all() {
	post_process A "$JDK_A_NAME"
	post_process B "$JDK_B_NAME"
	post_process C "$JDK_C_NAME"
	post_process D "$JDK_D_NAME"

	A_sum=`datamash sum 1 < gc-times-A.txt`

	B_sum=`datamash sum 1 < gc-times-B.txt`
	B_TO_A_sum=`echo "scale=2; ($B_sum * 100) / $A_sum" | bc`
	C_sum=`datamash sum 1 < gc-times-C.txt`
	C_TO_A_sum=`echo "scale=2; ($C_sum * 100) / $A_sum" | bc`
	D_sum=`datamash sum 1 < gc-times-D.txt`
	D_TO_A_sum=`echo "scale=2; ($D_sum * 100) / $A_sum" | bc`
	echo "GC Times, Sum, B to A: $B_TO_A_sum%"
	echo "GC Times, Sum, C to A: $C_TO_A_sum%"
	echo "GC Times, Sum, D to A: $D_TO_A_sum%"

	A_median=`datamash median 1 < gc-times-A.txt`
	A_sstdev=`datamash sstdev 1 < gc-times-A.txt`
	A_sstdev_perc=`echo "scale=2; ($A_sstdev * 100) / $A_median" | bc`
	echo "GC Times, Standard Deviation, A: +-$A_sstdev (+-$A_sstdev_perc%)"
}


post_process_all


chown -R thomas *

