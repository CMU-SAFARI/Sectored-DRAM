import os
import pandas as pd
import matplotlib.pyplot

NO_LOOPS = 3

names = ["ddr3_55nm_6f2_2g", "ddr3_55nm_6f2_2g2xIFSpeed", "paf8", "paf7", "paf6", "paf5", "paf4", "paf3", "paf2", "paf1"]
column_names = ["Baseline", "2XIFSpeed", "PA8", "PA7", "PA6", "PA5", "PA4", "PA3", "PA2", "PA1"]
plot_indices = ['IDD0', 'IDD4R', 'IDD4W', 'IDD7R', 'IDD7RW']

plot_indices = plot_indices[:NO_LOOPS]
#names = ["paf8"]

idd_total_pow = []
idd_periphery_pow = []
idd_core_pow = []
read_all_pow = []
activate_all_pow = []
read_all_indices = []
activate_all_indices = []

for i in range(0, NO_LOOPS):
    idd_total_pow.append([])
    idd_periphery_pow.append([])
    idd_core_pow.append([])

for i in range(0, len(names)):
    read_all_pow.append([])

for i in range(0, len(names)):
    activate_all_pow.append([])

name_counter = 0
for name in names:
    os.system("perl dram_model.pl -p -done " + name + " > /dev/null")

    for i in range(0,NO_LOOPS):
        fn = name + "_power_" + str(i) + ".txt"
        df = pd.read_csv(name + "_power_" + str(i) + ".txt", delimiter="\t")
        print(df)
        idd_total_pow[i].append(df['power'].sum())
        idd_core_pow[i].append(df[df['location'] == 'core']['power'].sum())
        idd_periphery_pow[i].append(df[df['location'] == 'periphery']['power'].sum())
        if i == 1: # READ LOOP
            for j in range(0, len(df)):
                key = df.iloc[j,:]['component'] + '-' + df.iloc[j,:]['location'] + '-' + df.iloc[j,:]['operation'] \
                    + '-' + df.iloc[j,:]['type'] + '-' + df.iloc[j,:]['voltage']
                val = df.iloc[j,:]['power']
                if key not in read_all_indices:
                    read_all_indices.append(key)
                read_all_pow[name_counter].append(val)
        if i == 0: # ACT LOOP
            for j in range(0, len(df)):
                key = df.iloc[j,:]['component'] + '-' + df.iloc[j,:]['location'] + '-' + df.iloc[j,:]['operation'] \
                    + '-' + df.iloc[j,:]['type'] + '-' + df.iloc[j,:]['voltage']
                val = df.iloc[j,:]['power']
                if key not in activate_all_indices:
                    activate_all_indices.append(key)
                activate_all_pow[name_counter].append(val)
        #print(df['power'].sum())

    name_counter += 1
    os.system("rm " + name + "_*")

df = pd.DataFrame(idd_total_pow, columns =column_names, index=plot_indices)
print(df)
# df = df.div(df['PA8'], axis=0)
# print(df)
df.plot.bar(figsize=(10,5), colormap='Paired', xlabel='Power Consumption Loop', ylabel='mW',).get_figure().savefig('power-total-plot.pdf', bbox_inches='tight')

df = pd.DataFrame(idd_core_pow, columns =column_names, index=plot_indices)
print(df)
df.plot.bar(colormap='Paired', xlabel='Power Consumption Loop', ylabel='mW',).get_figure().savefig('power-core-plot.pdf', bbox_inches='tight')
df.to_csv('core-power.csv')

df = pd.DataFrame(idd_periphery_pow, columns =column_names, index=plot_indices)
print(df)
df.plot.bar(colormap='Paired', xlabel='Power Consumption Loop', ylabel='mW',).get_figure().savefig('power-periphery-plot.pdf', bbox_inches='tight')
df.to_csv('periphery-power.csv')

df = pd.DataFrame(zip(*read_all_pow), columns =column_names, index=read_all_indices)
print(df)
df.plot.bar(colormap='Paired', xlabel='Location', ylabel='mW',).get_figure().savefig('power-read-all-plot.pdf', bbox_inches='tight')

df = pd.DataFrame(zip(*activate_all_pow), columns =column_names, index=activate_all_indices)
print(df)
df.plot.bar(colormap='Paired', xlabel='Location', ylabel='mW',).get_figure().savefig('power-activate-all-plot.pdf', bbox_inches='tight')


for i in range(len(names)):
    for j in range(len(plot_indices)):
        print(names[i], plot_indices[j], "=", idd_total_pow[j][i])


# generate xml to paste into DRAM Power specs
name_map = ['baseline', 'pa8', 'pa7', 'pa6', 'pa5', 'pa4', 'pa3', 'pa2', 'pa1']
for j in range(len(plot_indices)):
    for i in range(len(names)):
        print('<parameter id="' + plot_indices[j].lower() + name_map[i] + '" type="double" value="' + str(idd_total_pow[j][i]) + '" />')
        #print(names[i], plot_indices[j], "=", idd_total_pow[j][i])