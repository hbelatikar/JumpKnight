import os

os.system("vlog -work work  ../src/*.sv")
os.system("vlog -work work  ../testbench/test_package.sv")
os.system("vlog -work work  ../testbench/*.sv")
os.system("vlog -work work  ../testbench/knight_tests/*.sv")
os.system("vsim -c -do \"run -all\"  KnightsTour_tb_PWM_NEMO_check");
