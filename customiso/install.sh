#!/bin/bash

iso_label=201706  # don't change this

# 
chroot=./arch/x86_64/squashfs-root/

function install_confs {
   # Httpd confs
   queue_chroot 		

}


function link_ovas {
   ovas=/nomansland/MAIN_REPOS/hsap-pipeline-web-ui/
   ovas_chroot=$chroot/$hsap/

   sudo mkdir -p `dirname $ovas_chroot`
   sudo rsync -avP $ovas $ovas_chroot

   queue_chroot sudo chown http: /nomansland -R
   #sudo chmod a+wrx /nomansland -R
}


sudo xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "${iso_label}"  -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr ./isolinux/isohdpfx.bin -output arch-custom.iso ./

