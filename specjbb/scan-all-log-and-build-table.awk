# input: all.log from measure-all.sh
# output: table with: sum of GC times per config

# example intput
#  1 **** -XX:+UseSerialGC and 512 classes ****                                                                                                                                                                                                           
#  6 A (22 bit) gc times
#  7 count(field-1)  sum(field-1)    median(field-1) sstdev(field-1)
#  8 100     217390.588      2137.323        175.85124605385
#  9 B (26 bit) gc times
# 10 count(field-1)  sum(field-1)    median(field-1) sstdev(field-1)
# 11 100     196823.74       1925.933        185.46432109446
# 12 C (22 bit, with klass indirection table) gc times
# 13 count(field-1)  sum(field-1)    median(field-1) sstdev(field-1)
# 14 100     219525.767      2151.823        170.07816971112
# 15 D (22 bit, with staggered Klass locations) gc times
# 16 count(field-1)  sum(field-1)    median(field-1) sstdev(field-1)
# 17 100     204376.167      2007.647        181.69572730216


BEGIN {

}

/\*\*\*\* \-XX/ {
	GC=$2
	NUM_CLASSES=$4
	ALL_GCs
}

/^[A-D] .* gc times/ {
	VARIANT=$1
	EXPECT_NUMBERS=FNR+2
}

{
	if (EXPECT_NUMBERS == FNR) {
		TABLE[GC][NUM_CLASSES][VARIANT] = $2
#		print GC, NUM_CLASSES, VARIANT, $2
	}
}

END {
	print "GC,Classes,A,B,C,D"
	for (GC in TABLE) {
		for (NUM_CLASSES in TABLE[GC]) {
			print GC "," NUM_CLASSES "," \
				TABLE[GC][NUM_CLASSES]["A"] "," \
				TABLE[GC][NUM_CLASSES]["B"] "," \
				TABLE[GC][NUM_CLASSES]["C"] "," \
				TABLE[GC][NUM_CLASSES]["D"] ","
		}
	}
}
