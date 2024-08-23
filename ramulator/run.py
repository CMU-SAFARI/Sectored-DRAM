# When generating scripts for kratos
# remember to supply absolute paths for ramulator and output directories

# NOTE: assumes that "scripts" is one level under ramulator directory

import os
import random
from argparse import ArgumentParser

def get_random_list(wl_list, no_wls):
    ret = []
    for i in range(no_wls):
        idx = random.randrange(0, len(wl_list))
        ret.append(wl_list[idx])
    return ret

# @returns SBATCH command used to invoke the ramulator script
def generateExecutionSetup(ramulator_dir, output_dir, config, workload_name_list):
        ### Generate high, medium, low memory intensity workload combinations
            
        BASH_HEADER = "#!/bin/bash\n"

        CMD = BASE_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            config_path = 'configs/SectoredDRAM/' + config + '.cfg',
            stats_file_name = '{stats_file_name}',
        )
        
        SBATCH_CMD = SBATCH_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            output_file_name = '{output_file_name}',
            error_file_name = '{error_file_name}',
            job_name = '{job_name}',
            config_name = config,
            workload = '{workload}'
        )
        
        trace_file_list = ""
        prog_list = ""

        for j in range(7):
            trace_file_list += 'traces/' + workload_name_list[j] + '.trace '
            prog_list += workload_name_list[j] + '-'
        
        trace_file_list += 'traces/' + workload_name_list[7] + '.trace'
        prog_list += workload_name_list[7]

        CMD = CMD.format(
            stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt'
        )
        
        SBATCH_CMD = SBATCH_CMD.format(
            output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/output.txt',
            error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/error.txt',
            job_name = prog_list,
            workload = prog_list
        )            

        CMD += ' ' + trace_file_list
        
        os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)

        f = open(ramulator_dir + '/scripts/' + config + '-' + prog_list + '.sh', 'w')
        f.write(BASH_HEADER)
        f.write(CMD)
        f.close()
        
        return SBATCH_CMD   


PROGS = [    
    "GemsFDTD2006",
    "astar2006",
    "blender",
    "bwaves2006",
    "bzip22006",
    "cactus",
    "cactusADM2006",
    "calculix2006",
    "deepsjeng",
    "gcc2006",
    "gcc",
    "gobmk2006",
    "gromacs2006",
    "h264ref2006",
    "hmmer2006",
    "imagick",
    "lbm2006",
    "lbm",
    "leela",
    "libquantum2006",
    "mcf2006",
    "mcf2006high",
    "mcf",
    "namd",
    "omnetpp2006",
    "parest",
    "perlbench2006",
    "povray2006",
    "rand",
    "sjeng2006",
    "stride_reuse",
    "tonto2006",
    "wrf2006",
    "x264",
    "xalancbmk2006",
    "xalancbmk",
    "xz",
    "zeusmp2006"
]

parser = ArgumentParser(description='Prepare script(s) and directories to run ramulator')

parser.add_argument('configs', help='Configs to evaluate, separated with commas')
parser.add_argument('nworkloads', help='number of random multiprogrammed 8-core workloads to generate')

parser.add_argument('-o', '--output-dir', dest='outdir', help='base directory for outputs (expect sub directories here)', default='ramulator-output')
parser.add_argument('-r', '--ramulator-dir', dest='ramdir', help='base directory of ramulator project', default='.')
parser.add_argument('-p', '--progs', dest='progs', help = 'list of single-core apps to run if not all', nargs='*', action='store')
parser.add_argument('-s', '--single', dest='single', help = 'Generate ONLY single core runs', action='store_true')
parser.add_argument('-k', '--kratos', dest='kratos', help = 'are we running on kratos?', action='store_true')
parser.add_argument('-i', '--instructions', dest='instructions', help = 'how many instructions to simulate', default=100000000) # default 100M

HIGH_MPKI = "rand"   # 166.6
MEDIUM_MPKI = "lbm"  # 12.4
LOW_MPKI = "namd"    # 0.29

random.seed(1337)

args = parser.parse_args()

ramulator_dir = args.ramdir
output_dir = args.outdir
configs = args.configs
if args.progs is not None:
    PROGS = args.progs
n_random_mc_workloads = int(args.nworkloads)
for_kratos = args.kratos
single_core_only = args.single
insts_to_sim = args.instructions

os.system('cd configs/SectoredDRAM && python3 util.py expected_limit_insts ' + str(insts_to_sim) + ' && cd ../..')

os.system('mkdir -p ' + ramulator_dir + '/' + output_dir)
os.system('mkdir -p ' + ramulator_dir + '/scripts')

if not for_kratos:
    BASE_COMMAND_LINE = "\
        {ramulator_dir}/ramulator \
        {ramulator_dir}/{config_path} \
        --mode=cpu --stats {stats_file_name}"
        
else:
    BASE_COMMAND_LINE = "\
        LD_LIBRARY_PATH=/mnt/panzer/aolgun/EXT_LIBS \
        {ramulator_dir}/ramulator \
        {ramulator_dir}/{config_path} \
        --mode=cpu --stats {stats_file_name}"
    SBATCH_COMMAND_LINE = "\
        sbatch --cpus-per-task=1 --nodes=1 --ntasks=1 \
        --chdir={ramulator_dir} \
        --output={output_file_name} \
        --error={error_file_name} \
        --partition=cpu_part \
        --job-name='{job_name}' \
        {ramulator_dir}/scripts/{config_name}-{workload}.sh"

all_command_lines = []

if not for_kratos:
    for config in configs.split(','):
        os.system('mkdir -p ' + ramulator_dir + '/' + output_dir + '/' + config)

        for workload in PROGS:
            os.system('mkdir -p ' + ramulator_dir + '/' + output_dir + '/' + config + '/' + workload)
            CMD = BASE_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                config_path = 'configs/SectoredDRAM/' + config + '.cfg',
                stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + workload + '/stats.txt'
                )
            CMD += ' ' + workload + '.trace'
            all_command_lines.append(CMD)

        for i in range(n_random_mc_workloads):
            CMD = BASE_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                config_path = 'configs/SectoredDRAM/' + config + '.cfg',
                stats_file_name = '{stats_file_name}'
                )
            
            trace_file_list = ""
            prog_list = ""
            for j in range(7):
                workload_idx = random.randint(0, len(PROGS) - 1)
                trace_file_list += PROGS[workload_idx] + '.trace '
                prog_list += PROGS[workload_idx] + '-'
            
            workload_idx = random.randint(0, len(PROGS) - 1)
            trace_file_list += PROGS[workload_idx] + '.trace'
            CMD += ' ' + trace_file_list
            prog_list += PROGS[workload_idx]
            
            os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)
            CMD = CMD.format(stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt')
            
            all_command_lines.append(CMD)

BASH_HEADER = "#!/bin/bash\n"
all_sbatch_commands = []
all_sbatch_commands.append(BASH_HEADER)

if for_kratos:
    for config in configs.split(','):
        random.seed(1337)

        os.system('mkdir -p ' + ramulator_dir + '/' + output_dir + '/' + config)
        for workload in PROGS:
            os.system('mkdir -p ' + ramulator_dir + '/' + output_dir + '/' + config + '/' + workload)
            CMD = BASE_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                config_path = 'configs/SectoredDRAM/' + config + '.cfg',
                stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + workload + '/stats.txt',
                )
            CMD += ' ' + ramulator_dir + '/traces/' + workload + '.trace'
            f = open(ramulator_dir + '/scripts/' + config + '-' + workload + '.sh', 'w')
            f.write(BASH_HEADER)
            f.write(CMD)
            f.close()
            SBATCH_CMD = SBATCH_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + workload + '/output.txt',
                error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + workload + '/error.txt',
                job_name = config + '-' + workload,
                config_name = config,
                workload = workload
            )
            all_sbatch_commands.append(SBATCH_CMD)

        if single_core_only:
            continue

        for i in range(n_random_mc_workloads):
            
            CMD = BASE_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                config_path = 'configs/SectoredDRAM/' + config + '.cfg',
                stats_file_name = '{stats_file_name}',
            )
            
            SBATCH_CMD = SBATCH_COMMAND_LINE.format(
                ramulator_dir = ramulator_dir,
                output_file_name = '{output_file_name}',
                error_file_name = '{error_file_name}',
                job_name = '{job_name}',
                config_name = config,
                workload = '{workload}'
            )
            
            trace_file_list = ""
            prog_list = ""

            for j in range(7):
                workload_idx = random.randint(0, len(PROGS) - 1)
                trace_file_list += 'traces/' + PROGS[workload_idx] + '.trace '
                prog_list += PROGS[workload_idx] + '-'
            
            
            workload_idx = random.randint(0, len(PROGS) - 1)
            trace_file_list += 'traces/' + PROGS[workload_idx] + '.trace'
            prog_list += PROGS[workload_idx]


            CMD = CMD.format(
                stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt'
            )
            
            SBATCH_CMD = SBATCH_CMD.format(
                output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/output.txt',
                error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/error.txt',
                job_name = prog_list,
                workload = prog_list
            )            

            CMD += ' ' + trace_file_list
            
            os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)

            f = open(ramulator_dir + '/scripts/' + config + '-' + prog_list + '.sh', 'w')
            f.write(BASH_HEADER)
            f.write(CMD)
            f.close()
            
            all_sbatch_commands.append(SBATCH_CMD)
            
        ### Generate high, medium, low memory intensity workload combinations
            
        CMD = BASE_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            config_path = 'configs/SectoredDRAM/' + config + '.cfg',
            stats_file_name = '{stats_file_name}',
        )
        
        SBATCH_CMD = SBATCH_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            output_file_name = '{output_file_name}',
            error_file_name = '{error_file_name}',
            job_name = '{job_name}',
            config_name = config,
            workload = '{workload}'
        )
        
        trace_file_list = ""
        prog_list = ""

        for j in range(7):
            trace_file_list += 'traces/' + HIGH_MPKI + '.trace '
            prog_list += HIGH_MPKI + '-'
        
        trace_file_list += 'traces/' + HIGH_MPKI + '.trace'
        prog_list += HIGH_MPKI

        CMD = CMD.format(
            stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt'
        )
        
        SBATCH_CMD = SBATCH_CMD.format(
            output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/output.txt',
            error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/error.txt',
            job_name = prog_list,
            workload = prog_list
        )            

        CMD += ' ' + trace_file_list
        
        os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)

        f = open(ramulator_dir + '/scripts/' + config + '-' + prog_list + '.sh', 'w')
        f.write(BASH_HEADER)
        f.write(CMD)
        f.close()
        
        all_sbatch_commands.append(SBATCH_CMD)   
        
        CMD = BASE_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            config_path = 'configs/SectoredDRAM/' + config + '.cfg',
            stats_file_name = '{stats_file_name}',
        )
        
        SBATCH_CMD = SBATCH_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            output_file_name = '{output_file_name}',
            error_file_name = '{error_file_name}',
            job_name = '{job_name}',
            config_name = config,
            workload = '{workload}'
        )
        
        trace_file_list = ""
        prog_list = ""

        for j in range(7):
            trace_file_list += 'traces/' + MEDIUM_MPKI + '.trace '
            prog_list += MEDIUM_MPKI + '-'
        
        trace_file_list += 'traces/' + MEDIUM_MPKI + '.trace'
        prog_list += MEDIUM_MPKI

        CMD = CMD.format(
            stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt'
        )
        
        SBATCH_CMD = SBATCH_CMD.format(
            output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/output.txt',
            error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/error.txt',
            job_name = prog_list,
            workload = prog_list
        )            

        CMD += ' ' + trace_file_list
        
        os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)

        f = open(ramulator_dir + '/scripts/' + config + '-' + prog_list + '.sh', 'w')
        f.write(BASH_HEADER)
        f.write(CMD)
        f.close()
        
        all_sbatch_commands.append(SBATCH_CMD)    
        
        CMD = BASE_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            config_path = 'configs/SectoredDRAM/' + config + '.cfg',
            stats_file_name = '{stats_file_name}',
        )
        
        SBATCH_CMD = SBATCH_COMMAND_LINE.format(
            ramulator_dir = ramulator_dir,
            output_file_name = '{output_file_name}',
            error_file_name = '{error_file_name}',
            job_name = '{job_name}',
            config_name = config,
            workload = '{workload}'
        )
        
        trace_file_list = ""
        prog_list = ""

        for j in range(7):
            trace_file_list += 'traces/' + LOW_MPKI + '.trace '
            prog_list += LOW_MPKI + '-'
        
        trace_file_list += 'traces/' + LOW_MPKI + '.trace'
        prog_list += LOW_MPKI

        CMD = CMD.format(
            stats_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/stats.txt'
        )
        
        SBATCH_CMD = SBATCH_CMD.format(
            output_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/output.txt',
            error_file_name = ramulator_dir + '/' + output_dir + '/' + config + '/' + prog_list + '/error.txt',
            job_name = prog_list,
            workload = prog_list
        )            

        CMD += ' ' + trace_file_list
        
        os.system('mkdir -p ' + output_dir + '/' + config + '/' + prog_list)

        f = open(ramulator_dir + '/scripts/' + config + '-' + prog_list + '.sh', 'w')
        f.write(BASH_HEADER)
        f.write(CMD)
        f.close()
        
        all_sbatch_commands.append(SBATCH_CMD)     
        
        
        ### Randomly generate multi-core workloads using high-mpki single-core wls
        wl_list = ['bwaves2006','GemsFDTD2006','gobmk2006','libquantum2006','mcf2006high']
        
        all_sbatch_commands.append(generateExecutionSetup(ramulator_dir,output_dir,config, ['lbm','lbm2006','bwaves2006','GemsFDTD2006','gobmk2006','libquantum2006','mcf2006high','lbm']))
        
        for i in range(15):
            all_sbatch_commands.append(generateExecutionSetup(ramulator_dir,output_dir,config, get_random_list(wl_list, 8)))

f = open('run.sh', 'w')
for CMD in all_sbatch_commands:
    #print(CMD)
    f.write(CMD + '\n')
f.close()
