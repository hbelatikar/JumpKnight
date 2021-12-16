import os
from sys import platform

if platform == "linux" or platform == "linux2":
    # Linux...

    # Remove compiled files from earlier runs if any
    os.system("rm -rf *.txt *.ucdb transcript vsim.wlf work/ ucdb/ cover_report/")
    
    # Make ucdb directory to store all coverage reports
    os.system("mkdir ucdb")   

    # Compile the design and testbench files
    os.system("vlog -cover bcst -work work  ../synth/outputs/*.vg")
    os.system("vlog -cover bcst -work work  ../src/RemoteComm.sv ../src/KnightPhysics.sv ../src/UAR*.sv ../src/SPI_iNEMO4.sv")
    os.system("vlog -cover bcst -work work  ../testbench/test_package.sv")
    os.system("vlog -cover bcst -work work  ../testbench/knight_tests_postsynth/*.sv")

    os.system("vsim KnightsTour_tb_PWM_NEMO_check_postsynth")
    
    #os.system("vlog -cover bcst -work work  *.vg")
    #os.system("vlog -cover bcst -work work  RemoteComm.sv KnightPhysics.sv UAR*.sv SPI_iNEMO4.sv")
    #os.system("vlog -cover bcst -work work  test_package.sv")
    #os.system("vlog -cover bcst -work work  *_postsynth.sv")

    #os.system("vsim -c KnightsTour_tb_PWM_NEMO_check_postsynth")
	
else:
    # Could not find an appropriate OS to run the script on. Exit script.
    print("Couldn't find an operating system matching the specification.")
    print("Good Bye...")
