# kali-vm-builder
Scripts to build a customized kali virtual machine

Modified code based on https://gitlab.com/kalilinux/build-scripts/kali-vm, to include further customization options, such as:
  - customize keyboard layout
  
 currently based on commit `2db0eb17aae5b746499461409640533097432880` of the original repository

Example command : `./build-in-container.sh -f virtualbox -s 100 -v virtualbox -L en_US.UTF-8 -Z Europe/Paris -K fr`