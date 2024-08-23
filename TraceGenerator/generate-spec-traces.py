# This script ended up being too hard-coded, but w/e

import os
from argparse import ArgumentParser

SPECINT_NAMES = ["400.perlbench", "401.bzip2", "403.gcc", "429.mcf", "445.gobmk", "456.hmmer", "458.sjeng", "462.libquantum", "464.h264ref", "471.omnetpp", "473.astar", "483.xalancbmk"]
SPECINT_ARGS = [
    "-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1", #perl
    "input.combined 200", #bzip2
    "166.in -o 166.s", #gcc
    "inp.in", #mcf
    "--quiet --mode gtp < 13x13.tst", #gobmk
    "nph3.hmm swiss41", #hmmer
    "ref.txt", #sjeng
    "1397 8", #libquantum
    "-d foreman_ref_encoder_baseline.cfg", #h264
    "omnetpp.ini", #omnetpp
    "BigLakes2048.cfg", #astar
    "-v t5.xml xalanc.xsl" #xalanc
]

SPECFP_NAMES = []

parser = ArgumentParser(description='Collect all SPEC Ramulator traces under a directory given SPEC is installed in specdir')

parser.add_argument('tracedir', help='Collect traces in here')
parser.add_argument('specdir', help='SPEC top directory')
parser.add_argument('tempdir', help='Where to aggregate SPEC resources before trace generation')
#parser.add_argument('-s', '--sniperdir', help='Top level directory to sniper simulator', default='sniper')
#parser.add_argument('-o', '--only-single-core', dest='singlecore', help = 'Whether the script should only display results of single-core apps', action='store_true')
#parser.add_argument('-r', '--reference', dest='reference', help='Parse reference time traces and plot a histogram', action='store_true')

args = parser.parse_args()

SPEC_DIR = args.specdir
TEMP_DIR = args.tempdir
TRACE_DIR = args.tracedir

os.system("mkdir -p " + TEMP_DIR)
os.system("mkdir -p " + TRACE_DIR)

# create "temp" directories
for name in SPECINT_NAMES:    
    os.system("mkdir -p " + TEMP_DIR + '/' + name)
    os.system("mkdir -p " + TEMP_DIR + '/' + name + '/inputs')
    os.system("mkdir -p " + TEMP_DIR + '/' + name + '/outputs')

BASE_COMMAND_LINE = "\
    ../../tracegenerator.sh \
    -ifetch off \
    -paddr off \
    -dcache off \
    -- \
    ./{exec} \
    {args} \
    > {output} \
    2> {err} \
    "

# copy benchmark inputs and executables one-by-one
for b in SPECINT_NAMES:
    shortb = b.split('.')[1]
    if b == '483.xalancbmk':
        shortb = 'Xalan'
    
    if os.path.isfile(TEMP_DIR + '/' + b + '/' + shortb):
        print("SKIP COPYING SOURCES OF " + shortb)
        continue

    os.system('cp -r ' + SPEC_DIR + '/' + b + '/data/ref/input/* ' + TEMP_DIR + '/' + b)
    os.system('cp -r ' + SPEC_DIR + '/' + b + '/data/all/input/* ' + TEMP_DIR + '/' + b)
    os.system('cp ' + SPEC_DIR + '/' + b + '/run/build_base_amd64.0000/' + shortb + ' ' + TEMP_DIR + '/' + b)

print("Prepared the benchmark directory")
print("Now trying to generate traces")

# run and generate traces for each workload
for i in range(0, len(SPECINT_NAMES)):
    b = SPECINT_NAMES[i] # benchmark name
    shortb = b.split('.')[1]
    if b == '483.xalancbmk':
        shortb = 'Xalan'
        
    cmd = BASE_COMMAND_LINE.format(
            exec=shortb,
            args=SPECINT_ARGS[i],
            output="outputs/" + shortb + ".out" ,
            err="outputs/" + shortb + ".err")

    # Begin trace generation
    print("cd " + TEMP_DIR + "/" + b + " &&" + cmd)
    os.system("cd " + TEMP_DIR + "/" + b + " &&" + cmd)
        
    # copy traces to tracedir
    os.system('cp ' + TEMP_DIR + "/" + b + '/trace.out ' + TRACE_DIR + '/' + shortb + '.trace')