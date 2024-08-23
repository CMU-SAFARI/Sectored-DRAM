import os

os.system('./cacti -infile DDR4.cfg > temp.txt')

f = open('temp.txt', 'r')

lines = f.readlines()

for line in lines:
    if '###' in line:
        print(line)

