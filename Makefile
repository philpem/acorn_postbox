.PHONY: all test

TESTS       := $(basename $(wildcard tests/test_*.v))
TESTRESULTS := $(addsuffix .lxt2, ${TESTS})

MODULE_V    := postcode.v


all:
	@echo "Run 'make test' to run the test suite."

test: $(TESTRESULTS)
	@#echo "TODO: Aggregate test results, pass/fail"

testclean:
	-rm -f ${TESTRESULTS}

# Run a test to produce the test results
tests/%.lxt2:	tests/%
	vvp $< -lxt2
	@echo

# Build the test using Icarus Verilog
tests/%:	tests/%.v ${MODULE_V} FORCE
	iverilog -I./tests -o $@ $< ${MODULE_V}

.PHONY: FORCE

FORCE:
