#!/bin/bash

iso_label=201706  # don't change this

#
customiso=./customiso/
chroot=$customiso/arch/x86_64/squashfs-root/
vanilla_iso=./archlinux-2017.06.01-x86_64.iso

function init_mount_unpack {

    if [ -e $customiso ]; then
        #unsquash
        echo "Already unpacked"
        return 0
    fi

    if [ "`mount | grep /mnt/archiso | wc -l`" = "0" ]; then
        sudo mkdir /mnt/archiso
        sudo mount -t iso9660 -o loop $vanilla_iso /mnt/archiso
        sudo cp -a /mnt/archiso $customiso
    fi

    sudo sed -ibak 's/^HOOKS=.*$/HOOKS=\"base udev memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block pcmcia filesystems keyboard\"/' $chroot/etc/mkinitcpio.conf

    cd $customiso/arch/x86_64/
    sudo unsquashfs airootfs.sfs
    cd -

    comms="pacman-key --init; pacman-key --populate archlinux; pacman -Syu --force archiso linux; mkinitcpio -p linux; LANG=C pacman -Sl | awk '/\[installed\]$/ {print $1 \"/\" $2 \"-\" $3}' > /pkglist.txt; pacman -Scc; exit;"

    sudo sh -c "echo $comms > $chroot/run.sh"

    sudo arch-chroot $chroot /bin/bash ./run.sh
    sudo cp $chroot/boot/vmlinuz-linux $customiso/arch/x86_64/vmlinuz &&
    sudo cp $chroot/boot/initramfs-linux.img $customiso/arch/x86_64/archiso.img &&

    sudo mv $chroot/pkglist.txt $customiso/arch/pkglist.x86_64.txt

    unsquash
}


function unsquash {
    cd $customiso/arch/x86_64/ 
    sudo rm airootfs.sfs 2>/dev/null
    sudo mksquashfs squashfs-root airootfs.sfs
    cd -
}


function copy_static_files {
    static_dir=static_confs/

    cp -uvnpr $static_dir/* $chroot/etc
}


function derive_results {
    rsync -avP $iso_label $root/${RED}/ 
}



function link_ovas {
   ovas=/nomansland/MAIN_REPOS/hsap-pipeline-web-ui/
   ovas_chroot=$chroot/$hsap/

   sudo mkdir -p `dirname $ovas_chroot`
   sudo rsync -avP $ovas $ovas_chroot

   #queue_chroot sudo chown http: /nomansland -R
   #sudo chmod a+wrx /nomansland -R
}


init_mount_unpack
#copy_static_files


#sudo xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "${iso_label}"  -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr ./isolinux/isohdpfx.bin -output arch-custom.iso ./

