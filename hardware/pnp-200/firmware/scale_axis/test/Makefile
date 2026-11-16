# make            build and run the host simulation (axis_core.h on a simulated belt axis)
# make avr ELF=…  run the compiled firmware in simavr (needs simavr and libsimavr-dev)

CXXFLAGS = -std=c++11 -O2 -Wall -Wextra -I..

test: sim_test
	./sim_test

sim_test: sim_test.cpp ../axis_core.h
	$(CXX) $(CXXFLAGS) sim_test.cpp -o $@

avr_sim: avr_sim.c
	$(CC) -O2 -Wall avr_sim.c -o $@ -lsimavr -lm

avr: avr_sim
	./avr_sim $(ELF)

clean:
	rm -f sim_test avr_sim

.PHONY: test avr clean
