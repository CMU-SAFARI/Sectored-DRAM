SRCDIR := src
OBJDIR := obj
MAIN := $(SRCDIR)/Main.cpp
SRCS := $(filter-out $(MAIN) $(SRCDIR)/Gem5Wrapper.cpp, $(wildcard $(SRCDIR)/*.cpp))
OBJS := $(patsubst $(SRCDIR)/%.cpp, $(OBJDIR)/%.o, $(SRCS))


# Ramulator currently supports g++ 5.1+ or clang++ 3.4+.  It will NOT work with
#   g++ 4.x due to an internal compiler error when processing lambda functions.
CXX := clang++
# CXX := g++-5
CXXFLAGS := -O3 -std=c++11 -Werror -g #-DDEBUG_CACHE #-g -fsanitize=address # -static -DDEBUG_CACHE 
# CXXFLAGS := -O0 -std=c++11 -g -Werror -fsanitize=address -DDEBUG_CACHE 
#CXXFLAGS := -O2 -std=c++11 -g -Werror -fsanitize=address 
#-DDEBUG_CACHE

INCLUDE := ../DRAMPower/src
EXT_LIBS := ../DRAMPower/src/libdrampowerxml.a ../DRAMPower/src/libdrampower.a -lxerces-c

CXXFLAGS += -I$(INCLUDE)

.PHONY: all clean depend

all: depend ramulator

clean:
	rm -f ramulator
	rm -rf $(OBJDIR)
	make -C ../DRAMPower clean

depend: $(OBJDIR)/.depend


$(OBJDIR)/.depend: $(SRCS)
	@mkdir -p $(OBJDIR)
	@rm -f $(OBJDIR)/.depend
	@$(foreach SRC, $(SRCS), $(CXX) $(CXXFLAGS) -DRAMULATOR -MM -MT $(patsubst $(SRCDIR)/%.cpp, $(OBJDIR)/%.o, $(SRC)) $(SRC) >> $(OBJDIR)/.depend ;)

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/.depend
endif


ramulator: $(MAIN) $(OBJS) $(SRCDIR)/*.h $(EXT_LIBS) | depend
	$(CXX) -static-libgcc -static-libstdc++ $(CXXFLAGS) -DRAMULATOR -Lsrc/DRAMPower/src -o $@ $(MAIN) $(OBJS) $(EXT_LIBS)

libramulator.a: $(OBJS) $(OBJDIR)/Gem5Wrapper.o
	libtool -static -o $@ $(OBJS) $(OBJDIR)/Gem5Wrapper.o

../DRAMPower/src/libdrampower.a:
	make -C ../DRAMPower/ -j 4 src/libdrampower.a

../DRAMPower/src/libdrampowerxml.a:
	make -C ../DRAMPower/ -j 4 parserlib

.PHONY: src/DRAMPower/src/libdrampower.a src/DRAMPower/src/libdrampowerxml.a

$(OBJS): | $(OBJDIR)

$(OBJDIR): 
	@mkdir -p $@

$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -DRAMULATOR -c -o $@ $<
