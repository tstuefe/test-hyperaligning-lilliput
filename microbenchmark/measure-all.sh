set -e

# This script overrides
# - BASE_DIR
# - USEGC
# - NUM_CLASSES
# it leaves all other variables alone

BASE_DIR=$PWD
export BASE_DIR

TIMESTAMP=`date | tr ':_ ' '-' `
RESULTS_ROOT="results-$TIMESTAMP"
mkdir -p $RESULTS_ROOT
pushd $RESULTS_ROOT

BASE_LOG="$PWD/all.log"
touch "$BASE_LOG"

for USEGC in "-XX:+UseSerialGC" "-XX:+UseParallelGC" "-XX:+UseG1GC" ; do
	export USEGC
	for NUM_CLASSES in 512 1024 2048 4096 8192 16384 32768; do
		echo "**** $USEGC and $NUM_CLASSES classes ****" >> "$BASE_LOG"
		export NUM_CLASSES

		GC_NAME=${USEGC:8}
		SUBDIR="$GC_NAME-$NUM_CLASSES"
		mkdir $SUBDIR
		pushd $SUBDIR
		
		bash "${BASE_DIR}/measure.sh" >> "$BASE_LOG"
		
		popd
	done

done

popd

chown -R thomas .


