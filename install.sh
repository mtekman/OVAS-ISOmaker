#!/bin/bash
#
customiso=./customiso2/
chroot=$customiso/arch/x86_64/squashfs-root/
vanilla_iso=./archlinux-2017.06.01-x86_64.iso

chroot_cmd="sudo arch-chroot $chroot"

function download_if_empty {

    if ! [ -e $vanilla_iso ]; then   
        if ! [ -e $chroot/etc/mkinitcpio.conf ] ; then
            # manual download till I can get the globbing to work
            links "http://ftp.uni-hannover.de/archlinux/iso/latest/"
            vanilla_iso=./*.iso
        fi
    fi
}


function init_mount_unpack {

    echo ""
    if [ "`mount | grep /mnt/archiso | wc -l`" = "0" ]; then
        echo "[Mounting iso]"
        sudo mkdir /mnt/archiso
        sudo mount -t iso9660 -o loop $vanilla_iso /mnt/archiso
        
    else
        echo "[Already mounted]"
    fi

    sleep 2
    echo ""

    if ! [ -e $chroot/etc/mkinitcpio.conf ]; then
        echo ""
        echo "[Copying contents]"        
        sudo cp -unpr /mnt/archiso $customiso
        sleep 1

        echo ""
        echo "[Unsquashing FS]"
        cd $customiso/arch/x86_64/
        sudo unsquashfs airootfs.sfs
        cd -

        sleep 1
        echo ""
        echo "[Running chroot commands]"
        sleep 1

        $chroot_cmd pacman-key --init
        $chroot_cmd pacman-key --populate archlinux
        $chroot_cmd pacman -Syu --force archiso linux --noconfirm
        sleep 1
        echo ""
        echo "[Replacing HOOKS]"
        $chroot_cmd sed -ibak 's/^HOOKS=.*$/HOOKS=\"base udev memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block pcmcia filesystems keyboard\"/' /etc/mkinitcpio.conf       
        $chroot_cmd mkinitcpio -p linux
        $chroot_cmd "LANG=C pacman -Sl | awk '/\[installed\]$/ {print $1 \"/\" $2 \"-\" $3}' > /pkglist.txt;"
        $chroot_cmd pacman -Scc --noconfirm

        sleep 1
        echo ""
        echo "[Copying over boot images]"
    
        sudo cp $chroot/boot/vmlinuz-linux $customiso/arch/x86_64/vmlinuz
        sudo cp $chroot/boot/initramfs-linux.img $customiso/arch/x86_64/archiso.img
        sudo mv $chroot/pkglist.txt $customiso/arch/pkglist.x86_64.txt

        sleep 1
        echo ""
    else
        echo "[Already populated]"
    fi
}


function updateSquash {
    echo ""
    echo "[Updating Squash image]"
    cd $customiso/arch/x86_64/ 
    sudo rm airootfs.sfs 2>/dev/null
    sudo mksquashfs squashfs-root airootfs.sfs
    cd -
    echo ""
}


function copy_static_files {
    echo ""
    echo "[Updating Static Files]"
    static_dir=static_confs/

    sudo cp -vunpr $static_dir/* $chroot

    #resolve_links.cmd
    echo "[Resolving symlinks for stated directories]"
    for dir in `find $static_dir -name resolve_links.cmd -exec dirname {} \;`; do
        # Remove symlinks (if any)
        nodd=$chroot/`echo $dir | sed "s|$static_dir||"`
        echo " - Cleaning $nodd of symlinks"
        sudo find $nodd/ -type l -exec rm {} \;

        echo " - Copying over real files"       
        sudo cp -vunprL $dir $nodd
    done
}

function set_starts {
    echo ""
    echo "[Setting systemctl starts]"
    $chroot_cmd systemctl enable sshd
    $chroot_cmd systemctl enable httpd
}

function set_permissions {
    echo "[Setting Accounts and Permissions]"
    echo " - Creating accounts"
    $chroot_cmd useradd http
    $chroot_cmd usermod -d /home/http/ http
    $chroot_cmd usermod -a -G http http
    $chroot_cmd usermod -a -G wheel http

    echo " - Setting passwords"
    $chroot_cmd sh -c "echo 'http:http' | chpasswd"
    $chroot_cmd sh -c "echo 'root:root' | chpasswd"

    echo " - Setting permissions"
    $chroot_cmd chown http:http /nomansland -R
    $chroot_cmd chown http:http /extra -R
    $chroot_cmd chown root:root /home/
    $chroot_cmd chown http:http /home/http/ -R
    $chroot_cmd chmod u+wrx /home/http/ -R
    $chroot_cmd chmod a+wrx /nomansland -R
    $chroot_cmd chmod a+wrx /extra -R    
    $chroot_cmd chown root:root /etc -R
    $chroot_cmd chmod u+wrx /nomansland -R

    echo " - Setting default shells"
    $chroot_cmd chsh -s /bin/bash http
    $chroot_cmd chsh -s /bin/bash root
    
}

function install_packages {
    pack_list=package_list.txt
    sudo cp -v ./assets/$pack_list $chroot/$pack_list

    $chroot_cmd sh -c "cat $pack_list | pacman -S --needed --noconfirm -"
}


function install_boot_opts {
    echo "[ TODO ]"
    echo "Installing splash and opts"
}

function createISO {
    iso_label=201706  # don't change this

    sudo xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "${iso_label}"  -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr ./isolinux/isohdpfx.bin -output arch-custom.iso $customiso
}


download_if_empty
#init_mount_unpack
#install_packages
#copy_static_files
set_permissions
#set_starts
#updateSquash


