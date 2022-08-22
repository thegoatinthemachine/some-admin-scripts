# Some administration scripts

Mostly these will be bash. These should all be completely sanitized of any
organization-specific content or secrets, intended as a demonstration that I
have some clue what I'm doing.

## Script notes

### Imaging utilities/setup.sh

This worked swimmingly on Intel macOS. Apple in their infinite wisdom has
completely redone the permissions around installing macOS on the new Apple ARM
platform. ``startosinstall`` no longer works in the Apple ARM recovery OS
environment, around which this script was designed. The idea was that we'd
create a USB installer using a combination of tools, including MDS (Mac Deploy
Stick), boot into recovery mode, and blast away. This particular setup was for
secure-erasure. Ideally one would just throw away the key to filevault and
consider it nuked, but this covered cases where filevault hadn't been used.

### Imaging utilities/prepare-image-stick.sh

This was the best way at the time that I could come up with for the imaging
process we had available. As per the setup script, we'd use Mac Deploy Stick to
generate a disk image. This script would mount an arbitrarily large number of
USB drives plugged into, for example, a hub with a dozen of them, and make sure
those USB sticks were loaded with the correct, bootable information from the
disk image. This has a lot of checks and debug flags because it was prone to
hardware wonkiness. One of the downsides of the method is that the disk image
would load copies and behave as though it were occupying physical disk space,
so you could only simultaneously write as many USBs as your disk space allowed
"copies" of the disk image to mount. If I were re-writing this (which I'm not,
thank god) I'd try to find some way around that issue. This was, again, aimed
at a fleet of intel macs, in which booting from a USB and running scripts made
the most sense. This was in that weird inbetween stage well after Apple killed
the netboot process (I still am unclear on why, that PXEboot-like process was
damn near seamless) and before they had introduced the Auto Deployment which
picked up MDM details from DEP and had auto-advance when plugged into Ethernet.

The biggest takeaway for me from this, I was proud of how I handled wrangling a
bunch of disks which would be intended to have the same name at the end of the
process. MacOS' volume mounting just dumps all the mountpoints in ``/Volumes/``
by default with USBs, so making sure there weren't name collisions was a big
deal for getting this to go. This was really crucial to us speeding up and
making sure we had a good collection of deployment sticks right away. If we
changed some part of the install process, or there was new software we wanted
in the initial package, or there was, as can be seen from the comments in the
file, a new OS revision, we wanted every USB stick to be fungible. This way
around it, a computer set up with the correct details could have a bunch of
USBs plugged into a hub and let it rip. This took a process that otherwise was
very manual, one at a time, and time-consuming, and parallelized and automated
the crap out of it.

There are better ways now, may I never have to touch every machine the way I
did for this again. Most recently, with a buggy MDM, I wrote an Ansible script
which handled most of this deployment process.

## printer_managr/add_IPP_Everywhere_printer.ps1


This was hardcoded because it was so short, but I have removed the organization
specific details. The crucial bit about this, why this script behaves in
exactly this way, this was the only way I could identify to deal with IPP
Everwhere printers served by CUPS. This was years ago on an old print server,
on which I did not have Samba or Avahi installed or joined to the domain. Samba
makes this specific process unnecessary, because you can just define standard
Windows print services.

Of particular note, the way that printing typically works is that the files to
be printed are passed through a driver, but really most of them are
fundamentally pretty similar. Postscript Printer Descriptions can be defined
for systems which use CUPS, ie, macOS and Linux. IIRC, the language for this is
a 'filter'. So here's the thing about CUPS: you can pass a server raw
information without putting drivers on every endpoint and they'll work
correctly if they have the filter set up between the server and the printer.
This was ideal in a situation where Apple had started to outmode the concept of
printer drivers. The way that MDMs distribute printer information is by telling
the machine which IPP Everwhere address to find or which AirPrint printer to
use. Apple's CUPS is perfectly happy to send raw printer data to a printer or a
server, it doesn't care.

On Windows I may have had the ability to pass drivers to it, but honestly... I
didn't want to set up the print server twice for the printer. So I set it up so
the print server could talk to the printer correctly, and presented an IPP
Everywhere endpoint. Windows doesn't know how to deal with IPPE endpoints,
because it expects some kind of driver. Enter "MS Publisher Color Printer".
This is a stupid, stupid workaround to get Windows to sent full color raw info
to the CUPS server, and let CUPS do the filtering to spit out commands to the
server.

The value of this script is not in the method. This is not best practice. If
you're using CUPS, set up Samba and point your Windows machines at that,
because those printers show correctly in Microsoft land. The value is in my
research about RAW printers in Windows and CUPS, IPP Everwhere, and
troubleshooting and workaround that boils down to:

1. Explicitly name the "MS Publisher Color Printer" as a driver so it can be
   used to send RAW printer information to the server, which itself has the
   driver.
2. Add the IPPE endpoint as a printer port, explicitly.
3. Tie all that together with your defined printer associating the two.
