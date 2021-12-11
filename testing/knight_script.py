import os
from sys import platform

if platform == "linux" or platform == "linux2":
    #Linux...
    os.system("vlog -cover bcst -work work  ../src/*.sv")
    os.system("vlog -cover bcst -work work  ../testbench/test_package.sv")
    os.system("vlog -cover bcst -work work  ../testbench/*.sv")
    os.system("vlog -cover bcst -work work  ../testbench/knight_tests/*.sv")

    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_PWM_NEMO_check.ucdb; exit\" KnightsTour_tb_PWM_NEMO_check")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_cal_check.ucdb; exit\"      KnightsTour_tb_cal_check")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_moveW1.ucdb; exit\"         KnightsTour_tb_moveW1")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_moveE2FF.ucdb; exit\"       KnightsTour_tb_moveE2FF")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_tour_chk.ucdb; exit\"       KnightsTour_tb_tour_chk")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll KnightsTour_tb_tour_move.ucdb; exit\"      KnightsTour_tb_tour_move")
    # os.system("vsim -coverage -do \"run -all\"      KnightsTour_tb_tour_move")

elif platform == "win32":
    # Windows...
    os.system("vlog -work work  ../src/*.sv")
    os.system("vlog -work work  ../testbench/test_package.sv")
    os.system("vlog -work work  ../testbench/*.sv")
    os.system("vlog -work work  ../testbench/knight_tests/*.sv")

    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_PWM_NEMO_check")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_cal_check")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_moveW1")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_moveE2FF")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_tour_chk")
    # os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_tour_move")

    os.system("vsim -L altera_mf_ver -L lpm_ver KnightsTour_tb_moveE2FF")

else:
    print("Couldn't find an operating system matching the specification.")
    print("Good Bye...")


############### JUNK ########################
#  -do \"waves.do\"

# coverage save -assert -directive -cvg -codeAll KnightsTour_tb_moveW1.ucdb

# coverage save -assert -directive -cvg -codeAll KnightsTour_tb_moveE2FF.ucdb

# coverage save -assert -directive -cvg -codeAll KnightsTour_tb_tour_chk.ucdb