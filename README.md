# Sectored DRAM: A Practical Energy-Efficient and High-Performance Fine-Grained DRAM Architecture

Sectored DRAM is a new DRAM substrate that mitigates the excessive energy consumption 
from both (i) transmitting unused data on the memory channel and (ii) 
activating a disproportionately large number of DRAM cells at low cost.

## Cite Sectored DRAM

Please cite the following paper if you find Sectored DRAM useful:

A. Olgun, F. N. Bostanci, G. F. Oliveira, Y. C. Tugrul, R. Bera, A. G. Yaglikci, H. Hassan, O. Ergin, O. Mutlu, "Sectored DRAM: A Practical Energy-Efficient and High-Performance Fine-Grained DRAM Architecture", ACM TACO, June 2024.

Link to the PDF: [https://arxiv.org/pdf/2207.13795](https://arxiv.org/pdf/2207.13795)

BibTeX format for your convenience:

```tex
@article{olgun2024sectored,
    author = {Olgun, Ataberk and Bostanci, Fatma and Francisco de Oliveira Junior, Geraldo and Tugrul, Yahya Can and Bera, Rahul and Yaglikci, Abdullah Giray and Hassan, Hasan and Ergin, Oguz and Mutlu, Onur},
    title = {{Sectored DRAM: A Practical Energy-Efficient and High-Performance Fine-Grained DRAM Architecture}},
    year = {2024},
    journal = {ACM TACO}
}
```

## Repository File Structure

```
.
+-- cacti/                          # DRAM chip and Processor chip area modeling sources
+-- DRAMPower/                      # DRAM power model integrated into Ramulator
+-- mcpat/                          # Processor power model
+-- RambusModel/                    # Sectored DRAM's DRAM power model using Rambus Power Model
+-- ramulator/                      # Ramulator simulator sources
|   +-- configs/SectoredDRAM        # Configurations used in simulating Sectored DRAM and other prior work
|   +-- run.py                      # Key script to create Slurm jobs for Ramulator simulations
+-- TraceGenerator/                 # TraceGenerator tool to generate Sectored DRAM Ramulator compatible traces
+-- areapower.py                    # Key script to generate and summarize area and power results
+-- README.md                       # This file
```

## Installation Guide

Please refer to README files in each directory.

## Example Use

1. Generate traces for a workload using the TraceGenerator tool (refer to its README)
2. Run traces using Ramulator  
2.1. `cd ramulator && python3 run.py`  
2.2. `./run.sh`
3. Compute IDD values using Rambus Power Model  
3.1. `cd RambusModel && python3 compare_power.py`
4. Compute DRAM chip area, processor chip area, processor static and dynamic power using CACTI  
4.1.  `python3 areapower.py`

## Contacts

Ataberk Olgun (ataberk.olgun [at] safari [dot] ethz [dot] ch)