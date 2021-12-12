import os
from sys import platform

if platform == "linux" or platform == "linux2":
    # Linux...

    # Remove compiled files from earlier runs if any
    os.system("rm -rf *.txt *.ucdb transcript vsim.wlf work/ ucdb/ cover_report/")
    
    # Make ucdb directory to store all coverage reports
    os.system("mkdir ucdb")   

    # Compile the design and testbench files
    os.system("vlog -cover bcst -work work  ../src/*.sv")
    os.system("vlog -cover bcst -work work  ../testbench/test_package.sv")
    os.system("vlog -cover bcst -work work  ../testbench/*.sv")
    os.system("vlog -cover bcst -work work  ../testbench/knight_tests/*.sv")

    # Run the tests with coverage and dump coverage into their respective .ucdb file
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T1.ucdb; exit\" KnightsTour_tb_PWM_NEMO_check")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T2.ucdb; exit\" KnightsTour_tb_cal_check")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T3.ucdb; exit\" KnightsTour_tb_moveW1")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T4.ucdb; exit\" KnightsTour_tb_moveE2FF")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T5.ucdb; exit\" KnightsTour_tb_tour_chk")
    os.system("vsim -c -coverage -do \"run -all; coverage save -assert -directive -cvg -codeAll ./ucdb/T6.ucdb; exit\" KnightsTour_tb_tour_move")
    
    # Merge all the ucdb files and generate html and txt reports from them
    os.system("vsim -c -coverage -do \"vcover merge ./ucdb/suite.ucdb ./ucdb/T1.ucdb ./ucdb/T2.ucdb ./ucdb/T3.ucdb ./ucdb/T4.ucdb ./ucdb/T5.ucdb ./ucdb/T6.ucdb; exit\"")
    os.system("vsim -c -coverage -do \"vcover report -html -output suite_report -verbose -threshL 50 -threshH 90 ./ucdb/suite.ucdb; exit\"")
    os.system("vsim -c -coverage -do \"vcover report -output suite_report.txt -verbose ./ucdb/suite.ucdb; exit\"")

elif platform == "win32":
    # Windows...
    # Coverage cannot be run here so just compile and test them out
    os.system("vlog -work work  ../src/*")
    os.system("vlog -work work  ../testbench/test_package.sv")
    os.system("vlog -work work  ../testbench/*.sv")
    os.system("vlog -work work  ../testbench/knight_tests/*.sv")

    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_PWM_NEMO_check")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_cal_check")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_moveW1")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_moveE2FF")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_tour_chk")
    os.system("vsim -c -do \"run -all; exit\"  KnightsTour_tb_tour_move")

    # For GUI debugging
    # os.system("vsim -L altera_mf_ver -L lpm_ver KnightsTour_tb_tour_move")

else:
    # Could not find an appropriate OS to run the script on. Exit script.
    print("Couldn't find an operating system matching the specification.")
    print("Good Bye...")