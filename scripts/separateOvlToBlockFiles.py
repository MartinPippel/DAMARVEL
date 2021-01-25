#!/sw/bin/python3

#
# print block number for a given read id
#

import sys

if len(sys.argv) != 4:
    print("usage: <db> <ovl_text_file> <file_out_prefix>")
    sys.exit(1)

strDb = sys.argv[1]
strLas = sys.argv[2]
foutprefix = sys.argv[3]

if not strDb.endswith(".db"):
    strDb = strDb + ".db"

blockIds=[]
files=[]

def getBlockId( element ):
    mid = 0
    start = 0
    end = len(blockIds)
    step = 0

    while (start <= end):
        #print("Subarray in step {}: {}".format(step, str(blockIds[start:end+1])))
        step = step+1
        mid = (start + end) // 2

        if element == blockIds[mid]:
            #print("element {} blockIds[mid] {} start {} end {} mid {}".format(element, blockIds[mid], start, end, mid))
            return mid + 1

        if element < blockIds[mid]:
            end = mid - 1
        else:
            start = mid + 1
    #print("start {} end {} mid {}".format(start, end, mid))
    return start
    #return -1

nBlock = 0

for strLine in open(strDb):
    if nBlock == 0:
        if strLine.startswith("size = "):
            nBlock = 1
        continue
    blockIds.append(int(strLine.strip()))

files = [None] * len(blockIds) 
data = [None] * len(blockIds) 

# init data array with empty lists 
for i in range(len(blockIds)):
    data[i]=[]

# process read ID file
prevAread=-1
prevBread=-1
aBlockId=-1
bBlockId=-1
for strLine in open(strLas):
    aread, bread = strLine.split(" ")
    aread = int(aread)
    bread = int(bread)

    if(prevAread == aread and prevBread == bread):
        continue

    if(aread != prevAread):
        aBlockId=getBlockId(aread)
        prevAread=aread

    if(bread != prevBread):
        bBlockId=getBlockId(bread)
        prevBread=bread

    #print("reads: %d (%d) %d (%d)" % (aread, aBlockId, bread, bBlockId))    

    if(aread < bread):
        data[aBlockId].append((aread,bread))
        data[bBlockId].append((aread,bread))
        #files[aBlockId].write("%d %d\n" % (aread, bread))
        #files[bBlockId].write("%d %d\n" % (aread, bread))
    elif(aread > bread):
        data[aBlockId].append((bread,aread))
        data[bBlockId].append((bread,aread))
        #files[aBlockId].write("%d %d\n" % (bread, aread))
        #files[bBlockId].write("%d %d\n" % (bread, aread))
    else:
        data[aBlockId].append((aread,bread))
        #files[aBlockId].write("%d %d\n" % (aread, bread))

for i in range(len(blockIds)):
    #print("Database block %d: %d" % (i, blockIds[i]))
    if (len(data[i])):
        tmpFileName=foutprefix+"."+str(i)+".txt"
        fp = open(tmpFileName, "w")
        fp.write('\n'.join('{} {}'.format(x[0],x[1]) for x in data[i]))
        fp.write('\n')
        fp.close()

# close output files 
#for i in range(len(blockIds)):
#    files[i].close()
