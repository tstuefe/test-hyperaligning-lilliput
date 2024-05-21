# Filter everything out between:
#
# Done; will start GCs...
# and
# After GCs...

BEGIN { IN=0 }

/will start GCs\.\.\./ {
	IN=1
}

/after GCs\.\.\./ {
	IN=0
}

{
	if (IN == 1) print
}

 
