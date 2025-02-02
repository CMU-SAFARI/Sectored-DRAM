/*
 * Copyright (c) 2012-2014, TU Delft
 * Copyright (c) 2012-2014, TU Eindhoven
 * Copyright (c) 2012-2014, TU Kaiserslautern
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Authors: Matthias Jung
 *          Omar Naji
 *          Subash Kannoth
 *          Éder F. Zulian
 *          Felipe S. Prado
 *
 */

#ifndef LIB_DRAM_POWER_H
#define LIB_DRAM_POWER_H

#include <stdint.h>
#include <vector>

#include "CommandAnalysis.h"
#include "MemoryPowerModel.h"
#include "MemCommand.h"
#include "MemBankWiseParams.h"

class libDRAMPowerDummy {
 public:
  virtual void doCommand(DRAMPower::MemCommand::cmds, int, int64_t) {}
  virtual ~libDRAMPowerDummy() {}
};

class libDRAMPower : public libDRAMPowerDummy {
 public:
  libDRAMPower(const DRAMPower::MemorySpecification& memSpec, bool includeIoAndTermination);
  libDRAMPower(const DRAMPower::MemorySpecification& memSpec, bool includeIoAndTermination,const DRAMPower::MemBankWiseParams& bwPowerParams);
  ~libDRAMPower();

  void doCommand(DRAMPower::MemCommand::cmds type,
                 int                    bank,
                 int64_t                timestamp,
                 uint64_t               mats);

  void calcEnergy();

  void calcWindowEnergy(int64_t timestamp);

  const DRAMPower::MemoryPowerModel::Energy& getEnergy() const;
  const DRAMPower::MemoryPowerModel::Power& getPower() const;

  void enableHalfDRAM();

  // list of all commands
  std::vector<DRAMPower::MemCommand> cmdList;
 private:
  void updateCounters(bool lastUpdate, int64_t timestamp = 0);

  void clearCounters(int64_t timestamp);

  void clearState();

  DRAMPower::MemorySpecification memSpec;
 public:
  DRAMPower::CommandAnalysis counters;
 private:
  bool includeIoAndTermination;
  DRAMPower:: MemBankWiseParams bwPowerParams;
  // Object of MemoryPowerModel which contains the results
  // Energies(pJ) stored in energy, Powers(mW) stored in power. Number of
  // each command stored in timings.
  DRAMPower::MemoryPowerModel mpm;
};

#endif // ifndef LIB_DRAM_POWER_H
