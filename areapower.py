import os
import math

os.chdir(os.getcwd()+'/cacti')
os.system('./cacti -infile sectoredDRAM/DDR4.cfg > sectoredDRAM.out')
os.chdir(os.getcwd()+'/..')


f = open('cacti/sectoredDRAM.out', 'r')

lines = f.readlines()

stats = {}

for line in lines:
    if '###' in line:
        if 'MAT-Width' in line:
            stats['mat-width'] = float(line.split()[2])
        if 'MAT-Height' in line:
            stats['mat-height'] = float(line.split()[2])
        if 'MAT-Non-Cell' in line:
            stats['mat-non-cell'] = float(line.split()[2])
        if 'CAS-Peripheral-Height' in line:
            stats['cas-periphery-height'] = float(line.split()[2])
        if 'CAS-Peripheral-Length' in line:
            stats['cas-periphery-width'] = float(line.split()[2])
        if 'RAS-Peripheral-Height' in line:
            stats['ras-periphery-height'] = float(line.split()[2])
        if 'RAS-Peripheral-Length' in line:
            stats['ras-periphery-width'] = float(line.split()[2])
        if 'LWD-Stripe-Width' in line:
            stats['lwd-width'] = float(line.split()[2])
        if 'LWD-Per-MAT' in line:
            stats['lwd-per-mat'] = int(line.split()[2])
        if 'Vertical-MATs' in line:
            stats['no-mats-vertical'] = int(line.split()[2])
        if 'Horizontal-MATs' in line:
            stats['no-mats-horizontal'] = int(line.split()[2])
        if 'Sector-Transistor-Height' in line:
            stats['sector-transistor-height'] = float(line.split()[2])
        if 'Global-Data-Line-Width' in line:
            stats['sectorline-stripe-width'] = float(line.split()[2])
        if 'DRAM-Die-Area' in line:
            stats['total-dram-area'] = float(line.split()[2])

stats['sector-latch-area'] = 2.6
stats['lwd-height'] = (stats['mat-height']-stats['mat-non-cell'])/stats['lwd-per-mat']

print(stats)

stats['bank-width'] = (stats['lwd-width'] + stats['mat-width']) * stats['no-mats-horizontal'] + stats['lwd-width']
stats['bank-height'] = (stats['mat-height'] * stats['no-mats-vertical'])

stats['bank-periphery-width'] = stats['ras-periphery-width'] + stats['cas-periphery-width']
stats['bank-periphery-height'] = stats['ras-periphery-height'] + stats['ras-periphery-height']

stats['bank-area'] = (stats['bank-periphery-height'] + stats['bank-height']) * (stats['bank-periphery-width'] + stats['bank-width'])

print('\n\nMAT Pattern: LWD-MAT-LWD-MAT-LWD-MAT...-LWD (Baseline)\n')
print('Width of a bank:', stats['bank-width'])
print('Height of a bank:', stats['bank-height'])
print('Width of bank periphery:', stats['bank-periphery-width'])
print('Height of bank periphery:', stats['bank-periphery-height'])
print('Bank area:', stats['bank-area'])
print('16 bank area:', stats['bank-area'] * 16/1000000, 'mm^2')
print('Die area:', stats['total-dram-area']/1000000, 'mm^2')

stats['io-area'] = stats['total-dram-area']/1000000 - stats['bank-area'] * 16/1000000
print('Estimated I/O area:', stats['io-area'], 'mm^2')

print('16-bank/die area ratio:', str((stats['bank-area']*16)/stats['total-dram-area']*100) + '%')

print('\n\nMAT Pattern: LWD-MAT-LWD-LWD-MAT-LWD-LWD-MAT...-LWD (Sectored)\n')
bank_width = stats['bank-width'] + stats['lwd-width'] * (stats['no-mats-horizontal'] - 1) + stats['sectorline-stripe-width'] * stats['no-mats-horizontal']
print('Width of a bank:', bank_width)

bank_height = ( 
                (512 / stats['lwd-per-mat'] * stats['no-mats-vertical']) * 
                (
                    (stats['mat-height'] - stats['mat-non-cell']) / (512 / stats['lwd-per-mat']) + stats['sector-transistor-height']
                )
              ) + stats['no-mats-vertical']*stats['mat-non-cell']
print('Height of a bank:', bank_height)

print('Width of bank periphery:', stats['bank-periphery-width'])

bank_periphery_height = stats['bank-periphery-height'] + math.sqrt(stats['sector-latch-area'])
print('Height of bank periphery:', bank_periphery_height)

bank_area = (bank_height + bank_periphery_height) * (bank_width + stats['bank-periphery-width'])
print('Bank area:', bank_area)
print('16 bank area:', bank_area * 16/1000000, 'mm^2')

die_area = bank_area*16/1000000 + stats['io-area']
print('Die area:', die_area, 'mm^2')

print("\n\n########### Baseline vs SectoredDRAM ###########\n")
print('Bank Width', bank_width/stats['bank-width'])
print('Bank Height', bank_height/stats['bank-height'])
print('Bank Periphery Height', bank_periphery_height/stats['bank-periphery-height'])
print('Bank Area', bank_area/stats['bank-area'])
print('16 Bank Die Area', die_area/(stats['total-dram-area']/1000000))


print("\n\n########### Sector Caches ###########\n")

os.chdir(os.getcwd()+'/cacti')
os.system('./cacti -infile sectoredDRAM/cache-baseline-32KiB.cfg > cache-baseline-32KiB.out')
os.system('./cacti -infile sectoredDRAM/cache-sectored-32KiB.cfg > cache-sectored-32KiB.out')
os.system('./cacti -infile sectoredDRAM/cache-baseline-256KiB.cfg > cache-baseline-256KiB.out')
os.system('./cacti -infile sectoredDRAM/cache-sectored-256KiB.cfg > cache-sectored-256KiB.out')
os.system('./cacti -infile sectoredDRAM/cache-baseline-8192KiB.cfg > cache-baseline-8192KiB.out')
os.system('./cacti -infile sectoredDRAM/cache-sectored-8192KiB.cfg > cache-sectored-8192KiB.out')
os.system('./cacti -infile sectoredDRAM/sector-predictor.cfg > sector-predictor.out')
os.chdir(os.getcwd()+'/..')

f = open('cacti/cache-baseline-32KiB.out', 'r')
lines = f.readlines()
baseline_l1_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
baseline_l1_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
baseline_l1_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
baseline_l1_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

f = open('cacti/cache-sectored-32KiB.out', 'r')
lines = f.readlines()
sectored_l1_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
sectored_l1_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
sectored_l1_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
sectored_l1_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

f = open('cacti/cache-baseline-256KiB.out', 'r')
lines = f.readlines()
baseline_l2_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
baseline_l2_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
baseline_l2_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
baseline_l2_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

f = open('cacti/cache-sectored-256KiB.out', 'r')
lines = f.readlines()
sectored_l2_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
sectored_l2_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
sectored_l2_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
sectored_l2_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

f = open('cacti/cache-baseline-8192KiB.out', 'r')
lines = f.readlines()
baseline_l3_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
baseline_l3_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
baseline_l3_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
baseline_l3_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

f = open('cacti/cache-sectored-8192KiB.out', 'r')
lines = f.readlines()
sectored_l3_cache_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
sectored_l3_cache_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
sectored_l3_cache_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
sectored_l3_cache_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])


f = open('cacti/sector-predictor.out', 'r')
lines = f.readlines()
sp_size = float([x for x in lines if ('Data array: Area (' in x)][0].split()[4])
sp_wrenergy = float([x for x in lines if ('Total dynamic write energy' in x)][0].split()[7])
sp_rdenergy = float([x for x in lines if ('Total dynamic read energy' in x)][0].split()[7])
sp_leakage = float([x for x in lines if ('Total leakage power of' in x)][0].split()[7])

print('L1 size:', sectored_l1_cache_size)
print('SP size:', sp_size)

print('L1 area overhead:', (sectored_l1_cache_size/baseline_l1_cache_size - 1), 'times')
# 1 nJ/s = 1^10-9 watt
l1_power_overhead = (((sectored_l1_cache_rdenergy + sectored_l1_cache_wrenergy) * 4.5 * 1000) + sectored_l1_cache_leakage) / (((baseline_l1_cache_rdenergy + baseline_l1_cache_wrenergy) * 4.5 * 1000) + baseline_l1_cache_leakage)
print('L1 power overhead: (assuming 1/2 read, 1/2 write activity, 2 access per cycle, 4.5 GHz)', (l1_power_overhead - 1), 'times')

print('L2 area overhead:', sectored_l2_cache_size/baseline_l2_cache_size - 1, 'times')
l2_power_overhead = (((sectored_l2_cache_rdenergy + sectored_l2_cache_wrenergy) * 4.5/4 * 1000) + sectored_l2_cache_leakage) / (((baseline_l2_cache_rdenergy + baseline_l2_cache_wrenergy) * 4.5/4 * 1000) + baseline_l2_cache_leakage)
print('L2 power overhead: (assuming 1/2 read, 1/2 write activity, 0.5 access per cycle, 4.5 GHz)', (l2_power_overhead - 1), 'times')

print('L3 area overhead:', sectored_l3_cache_size/baseline_l3_cache_size - 1, 'times')
l3_power_overhead = (((sectored_l3_cache_rdenergy + sectored_l3_cache_wrenergy) * 4.5/10 * 1000) + sectored_l3_cache_leakage) / (((baseline_l3_cache_rdenergy + baseline_l3_cache_wrenergy) * 4.5/10 * 1000) + baseline_l3_cache_leakage)
print('L3 power overhead: (assuming 1/2 read, 1/2 write activity, 0.2 access per cycle, 4.5 GHz)', (l3_power_overhead - 1), 'times')


### TODO: Parse mcpat output, multiply l3, l2, l1 area and power overheads to find 1) the parameters for the IPC-based power model, 2) area overhead of sectoredDRAM for the whole processor

print("\n\n########### Processor Area/Power ###########\n")

os.chdir(os.getcwd()+'/mcpat')
os.system('build/mcpat -i ProcessorDescriptionFiles/SectoredDRAM.xml -p 5 > SectoredDRAM.out')
os.chdir(os.getcwd()+'/..')

f = open('mcpat/SectoredDRAM.out', 'r')
lines = f.readlines()

#for i in range(len(lines)):
#    print(i, lines[i])

processor_area = float(lines[12].split()[2])
processor_power = float(lines[13].split()[3])
auxiliary_area = processor_area - float(lines[23].split()[2]) - float(lines[32].split()[2])
auxiliary_power = processor_power - float(lines[24].split()[3]) - float(lines[25].split()[3]) - float(lines[33].split()[3]) - float(lines[34].split()[3])

core_area = float(lines[50].split()[2])
core_dynamic_power = float(lines[51].split()[3])
core_leakage_power = float(lines[52].split()[3])

l1_area = float(lines[211].split()[2])
l1_dynamic_power = float(lines[212].split()[3])
l1_leakage_power = float(lines[213].split()[3])

l2_area = float(lines[353].split()[2])
l2_dynamic_power = float(lines[354].split()[3])
l2_leakage_power = float(lines[355].split()[3])

l3_area = float(lines[32].split()[2])
l3_dynamic_power = float(lines[33].split()[3])
l3_leakage_power = float(lines[34].split()[3])

print('Single core area', core_area, 'mm^2')
print('Auxiliary area', auxiliary_area, 'mm^2')
print('L1D$ area', l1_area, 'mm^2')
print('L2D$ area', l2_area, 'mm^2')
print('L3D$ area', l3_area, 'mm^2')

print('Single core power', core_dynamic_power + core_leakage_power, 'W')
print('Auxiliary power', auxiliary_power, 'W')
print('L1D$ power', l1_dynamic_power + l1_leakage_power, 'W')
print('L2D$ power', l2_dynamic_power + l2_leakage_power, 'W')
print('L3D$ power', l3_dynamic_power + l3_leakage_power, 'W\n')

core_power = core_dynamic_power + core_leakage_power
l1_power = l1_dynamic_power + l1_leakage_power
l2_power = l2_dynamic_power + l2_leakage_power
l3_power = l3_dynamic_power + l3_leakage_power

# area overhead for 8-core processor
processor_area_overhead = (((core_area - l1_area - l2_area) + l1_area * sectored_l1_cache_size/baseline_l1_cache_size + l2_area * sectored_l2_cache_size/baseline_l2_cache_size) * 8 + l3_area * sectored_l3_cache_size/baseline_l3_cache_size + auxiliary_area + sp_size) / processor_area
print('Processor area overhead of SectoredDRAM:', str((processor_area_overhead - 1)*100) + '%')
processor_power_overhead = (((core_power - l1_power - l2_power) + l1_power * l1_power_overhead + l2_power * l2_power_overhead) * 8 + l3_power * l3_power_overhead + auxiliary_power) / processor_power
print('Processor power overhead of SectoredDRAM:', str((processor_power_overhead - 1)*100) + '%')

print('Baseline Processor Peak Dynamic Power', processor_power,'W')
print('SectoredDRAM Processor Peak Dynamic Power', processor_power*processor_power_overhead,'W')
print('Baseline Processor Static Power', processor_power * float(lines[14].split()[3])/processor_power,'W')
print('SectoredDRAM Processor Static Power', processor_power*processor_power_overhead * float(lines[14].split()[3])/processor_power,'W')
print('Static/Total Power Ratio', float(lines[14].split()[3])/processor_power)
print('\n')

for i in range(1,9):
    print(i, 'baseline core peak dynamic power', (processor_power-float(lines[14].split()[3])) / 8 * i, 'W')

print('\n')
for i in range(1,9):
    print(i, 'sectored core peak dynamic power', (processor_power*processor_power_overhead-float(lines[14].split()[3])) / 8 * i, 'W')