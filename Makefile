RTL_SRCS = rtl/riscv_pkg.sv \
           rtl/pc_incrementer.sv \
           rtl/instr_mem.sv \
           rtl/control_unit.sv \
           rtl/imm_gen.sv \
           rtl/reg_file.sv \
           rtl/alu.sv \
           rtl/data_mem.sv \
           rtl/riscv_core.sv

TB_SRCS  = tb/riscv_core_tb.sv

.PHONY: all sim clean

all: sim

sim: obj_dir/sim

obj_dir/sim: $(RTL_SRCS) $(TB_SRCS)
	mkdir -p verif/logs
	verilator --sv --cc --exe --main --timing \
	  --top-module riscv_core_tb \
	  --Mdir obj_dir \
	  $(RTL_SRCS) $(TB_SRCS)
	make -C obj_dir -f Vriscv_core_tb.mk

run: obj_dir/sim
	mkdir -p verif/logs
	cd $(CURDIR) && obj_dir/sim

clean:
	rm -rf obj_dir verif/logs/dut.log
