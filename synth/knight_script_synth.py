import os
from sys import platform

if platform == "linux" or platform == "linux2":
    # Linux...

    # Remove compiled files from earlier runs if any
    os.system("rm -rf *.txt *.mr *.pvl *.syn *.swo *.swp *.svf outputs/")

    os.system("mkdir outputs")

    # Running the synthesis script
    os.system("design_vision -shell dc_shell -f KnightsTour.dc");

else:
    # Could not find an appropriate OS to run the script on. Exit script.
    print("Couldn't find an operating system matching the specification.")
    print("Good Bye...")
