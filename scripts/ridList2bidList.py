#!/projects/dazzler/pippel/prog/anaconda3/bin/python

#
# print list of block number for a given list read id
#
# output rid bid
#        rid bid
#        rid bid
import sys

if len(sys.argv) != 3:
    print("usage: <db> <readIdFile>")
    sys.exit(1)

strDb = sys.argv[1]

if not strDb.endswith(".db"):
    strDb = strDb + ".db"

if sys.argv[2] == "-":
    fin = sys.stdin
else:
    fin = open(sys.argv[2], "r")

data = fin.read()
nIDList = [int(i) for i in data.split()]

nBlock = 0
nOffReal_p = nOffTrim_p = 0

for strLine in open(strDb):
    if nBlock == 0:
        if strLine.startswith("size = "):
            nBlock = 1

        continue

    nOffReal = int(strLine.strip())

    for nId in nIDList:
        if nId >= nOffReal_p and nId < nOffReal:
    	    print("{} {}".format(nId, nBlock - 1))        	
        	
    nOffReal_p = nOffReal

    nBlock += 1

