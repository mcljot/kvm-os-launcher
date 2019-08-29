#!/usr/bin/python

import os, sys

env_path = "./rhel-7"

if not os.geteuid() == 0:
    print ("\nYou must be root to run this script.\n")
    sys.exit(1)

if len(sys.argv) == 2:
    try:
        clientNumber = int(sys.argv[1])
    except ValueError:
        print("\n%s is not an integer.\n" % sys.argv[1])
        sys.exit(4)
    if clientNumber >= 1 and clientNumber <= 9:
        checkNet = ("%s/scripts/net-check.sh") % (env_path)
        createVM = ("%s/scripts/init-rhel-vm.sh %d") % (env_path, clientNumber)
	os.system(checkNet)
        os.system(createVM)

    else:
        print("\nOut of range.\n")
        sys.exit(3)
else:
    print("\nYou need exactly one argument (1-9) to run this script.\n")
    sys.exit(2)
