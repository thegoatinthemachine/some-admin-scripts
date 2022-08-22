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

