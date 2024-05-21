
# Env vars:
# JDK_A_NAME .. JDK_D_NAME: name of jdk dir

# The "specjbb/results-xxx" dir
BASE_DIR=${BASE_DIR:-$PWD}

JDK_A_NAME_DEFAULT="jdk-22bit-staggered-klass-OFF"
JDK_B_NAME_DEFAULT="jdk-26bit-staggered-klass-OFF"
JDK_C_NAME_DEFAULT="jdk-22bit-klasstable-ON"
JDK_D_NAME_DEFAULT="jdk-22bit-staggered-klass-ON"

JDK_A_NAME=${JDK_A_NAME:-$JDK_A_NAME_DEFAULT}
JDK_B_NAME=${JDK_B_NAME:-$JDK_B_NAME_DEFAULT}
JDK_C_NAME=${JDK_C_NAME:-$JDK_C_NAME_DEFAULT}
JDK_D_NAME=${JDK_D_NAME:-$JDK_D_NAME_DEFAULT}

COUNT=1


export LC_NUMERIC=en_US.UTF-8
export LANG=en_US.UTF-8

# $1 A B or C
# $2 description
function post_process() {

	local LETTER=$1

	echo "${LETTER} ($2) gc times "

	# Filter out warmup phase, we only want to examine the explicitly issued full gcs
	for a in "${2}*"; do
		echo "post processing $a..."
		pushd $a
		rm gc-times-${LETTER}.txt
		ack '\[gc.*GC\(.*Pause .*ms$' composite.out | sed 's/.* \([0-9\.,]*\)ms/\1/g' >> gc-times-${LETTER}.txt
		datamash --header-out count 1 sum 1 median 1 sstdev 1 < gc-times-${LETTER}.txt 
		cp gc-times-${LETTER}.txt ..
		popd
	done
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



