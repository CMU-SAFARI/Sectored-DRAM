import os
import sys

workdir = os.getcwd()
print(workdir)
if "configs/SectoredDRAM" not in workdir:
    print("run me from the config directory")
    exit(1)

config_files = [l for l in os.listdir() if ".cfg" in l]

print(len(sys.argv))
if len(sys.argv) != 3:
    print("not enough arguments")
    exit(1)
    
look_for = sys.argv[1]
replace_with = sys.argv[2]
   
for file in config_files:
    f = open(file, "r")
    lines = f.readlines()
    f.close()
    f = open(file, "w")
    newlines = []
    for line in lines:
        if (look_for + " = ") in line:
            print("FOUND")
            newlines.append(look_for + " = " + replace_with + "\n")
        else:
            newlines.append(line)
    f.writelines(newlines)
