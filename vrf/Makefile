# Makefile For VCS

export PRJ_PATH=$(shell pwd)/..

all:
	@echo "VCS Verification ENV"

cmp:
	@vcs -LDFLAGS -Wl,--no-as-needed -debug_pp +lint=TFIPC-L +lint=PCWM ../rtl/sopc/riscv_sopc_tb.v -f ../rtl/filelist/filelist.f -top riscv_sopc_tb -l vcs.log

run:
	@./simv -l simv.log

dve:
	@dve -vpd *.vpd &

clean:
	@rm -rf ucli.key csrc simv simv.daidir vcs.log simv.log *.vpd DVEfiles

