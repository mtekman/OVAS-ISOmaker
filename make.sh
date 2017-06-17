#!/bin/bash
#
command=$1
[ "$command" = "" ] && echo -e "\n\t`basename $0` (install|update)\n" && exit -1


trap "kill 0" SIGINT  # kill all subprocesses

customiso=./customiso/
chroot=$customiso/arch/x86_64/squashfs-root/
vanilla_iso=./arch*.iso

chroot_cmd="sudo arch-chroot $chroot"

iso_label=ARCH_201706  # don't change this


function download_if_empty {

    if ! [ -e $vanilla_iso ]; then   
        if ! [ -e $chroot/etc/mkinitcpio.conf ] ; then
            # manual download till I can get the globbing to work
            wget http://mirror.23media.de/archlinux/iso/latest/archlinux-2017.06.01-x86_64.iso
            vanilla_iso=./*.iso
        fi
    fi
}


function init_mount_unpack {

    echo ""
    mntpnt=/mnt/archiso2
    sudo umount $vanilla_iso
    if [ "`mount | grep $mntpnt | wc -l`" = "0" ]; then
        echo "[Mounting iso]"
        sudo mkdir $mntpnt 2>/dev/null
        sudo mount -t iso9660 -o loop $vanilla_iso $mntpnt || (echo "Unable to mount.." && exit -1)
    else
        echo "[Already mounted]"
    fi

    sleep 2
    echo ""

    if ! [ -e $chroot/etc/mkinitcpio.conf ]; then
        echo ""
        echo "[Copying contents]"        
        sudo cp -unpr $mntpnt $customiso || (echo "Unable to copy..." && exit -1)
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
	sleep 1

	#
	# CAUTION: Updating the kernel leads to mouse and keyboard not working. Ignoring for now.
	#
        #$chroot_cmd pacman -Syu --force archiso linux --noconfirm
        #echo ""
        #echo "[Replacing HOOKS]"
        #$chroot_cmd sed -ibak 's/^HOOKS=.*$/HOOKS=\"base memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block pcmcia filesystems keyboard\"/' /etc/mkinitcpio.conf       
        #$chroot_cmd "LANG=C pacman -Sl | awk '/\[installed\]$/ {print $1 \"/\" $2 \"-\" $3}' > /pkglist.txt;"
    else
        echo "[Already populated]"
    fi
}



## BOOT and kernel functions ####
#
# CAUTION: Updating the kernel leads to mouse and keyboard not working. Ignoring for now.
#
function __updateEFI {
    echo "[ Updating EFI ]"
    sudo mkdir mnt
    sudo mount -t vfat -o loop $customiso/EFI/archiso/efiboot.img mnt
    sudo cp -v $customiso/arch/boot/x86_64/vmlinuz mnt/EFI/archiso/vmlinuz.efi
    sudo cp -v $customiso/arch/boot/x86_64/archiso.img mnt/EFI/archiso/archiso.img
}



function _updateBootOpts {
    #
    # CAUTION: Updating the kernel leads to mouse and keyboard not working. Ignoring for now.
    #
    #$chroot_cmd mkinitcpio -p linux
    #$chroot_cmd pacman -Scc --noconfirm

    sleep 1
    echo ""
    echo "[Copying over boot images]"

    sudo cp $chroot/boot/vmlinuz-linux $customiso/arch/x86_64/vmlinuz
    sudo cp $chroot/boot/initramfs-linux.img $customiso/arch/x86_64/archiso.img

    sleep 1
    echo ""
    #__updateEFI
}

function install_boot_opts {

    syslx_root=$customiso/arch/boot/syslinux
    
    echo "[Configuring Bootloader]"
    echo " - Setting splash"
    convert assets/splash.xcf -flatten /tmp/splash.png
    sudo cp -v /tmp/splash.png $syslx_root/
    
    echo " - Setting menu text"
    sudo sed -i 's/MENU TITLE .*/MENU TITLE Welcome to the OVAS pipeline/' $syslx_root/archiso_head.cfg
    sudo sh -c "echo \"\
INCLUDE boot/syslinux/archiso_head.cfg

LABEL arch64
TEXT HELP
Boots the OVAS live medium.
Provides a self-contained environment to perform variant analysis.
ENDTEXT
MENU LABEL Run OVAS
LINUX boot/x86_64/vmlinuz
INITRD boot/intel_ucode.img,boot/x86_64/archiso.img
APPEND archisobasedir=arch archisolabel=${iso_label} cow_spacesize=10G

LABEL poweroff
MENU LABEL Power Off
COM32 boot/syslinux/poweroff.c32

\" > $syslx_root/archiso_sys.cfg"

    _updateBootOpts
}




function updateSquash {
    algo=${1:xz}

    backup_root=./backup_root

    #if ! [ -e $customiso/arch/x86_64/squashfs-root/ ];then
    #    echo " - squashfs-root does not exist"
    #    if [ -e $backup_root ]; then
    #        echo " - Moving backup into place"
    #        sudo mv -v $backup_root $customiso/arch/x86_64/squashfs-root/
    #    else
    #        echo " - Nothing to squash, terminating"
    #        exit -1
    #    fi
    #fi
    
    echo ""
    echo "[Updating Squash image ($algo)]"
    cd $customiso/arch/x86_64/
   
    sudo rm airootfs.sfs
    sudo mksquashfs squashfs-root airootfs.sfs -comp $algo
    sudo sh -c "md5sum airootfs.sfs > airootfs.md5"

    cd -
    echo ""
}



function copy_static_files {
    echo ""
    echo "[Updating Static Files]"
    static_dir=static_confs/

    sudo rsync -av $static_dir/* $chroot
    
    #resolve_links.cmd
    echo "[Resolving symlinks for stated directories]"
    for dir in `find $static_dir -name resolve_links.cmd -exec dirname {} \;`; do
        #echo "$dir"
        #continue
        # Remove symlinks (if any)
        nodd=$chroot/`echo $dir | sed "s|$static_dir||"`
        echo " - Cleaning $nodd of symlinks"
        symedfiles=`sudo find $nodd/ -maxdepth 1  -type l`

        echo " - Copying over real files"
        for file in $symedfiles; do
            actualpath=$(readlink -f $file)
            rsync -avP $actualpath $nodd/
        done
    done
}

function set_starts {
    echo ""
    echo "[Setting systemctl starts]"
    $chroot_cmd systemctl enable sshd         # enable internally for debugging
    $chroot_cmd systemctl enable httpd

    $chroot_cmd systemctl enable  dhcpcd       # slow, enable on demand
    $chroot_cmd systemctl disable pacman-init  # not needed for one time use
    
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
    pack_list_in=./assets/install_lists/*.deps

    for dep in $pack_list_in; do
	base=`basename $dep`
	sudo cp -v $dep $chroot/$base
	$chroot_cmd sh -c "cat $base | pacman -Sy --needed --noconfirm -"
    done
}


function createISO {
    back=./chroot_backup
    sudo mv -v $chroot $back   #  temporarily move chroot out of custom

    echo "[Creating ISO]"
    mkdir out
    output_iso=out/ovas-`date +%Y%m%d-%H%M`.iso
    [ -e $output_iso ] && rm $output_iso

    [ "$output_iso" = "" ] && echo "No iso filename given!" && exit -1
    
    make_xoriso $output_iso # OR
    #make_geniso $output_iso

    # move chroot back
    sleep 1
    sudo mv -v $back $chroot
    ls -lh out/*
}



function make_xoriso {
    output_iso=$1
    isolinux=`readlink -f $customiso/isolinux`
    
    sudo xorriso\
	 -as mkisofs -iso-level 3 -full-iso9660-filenames\
         -volid "${iso_label}"\
	 -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat\
	 -no-emul-boot -boot-load-size 4 -boot-info-table\
         -isohybrid-mbr $isolinux/isohdpfx.bin\
         -output $output_iso $customiso

    #-eltorito-alt-boot -e EFI/archiso/efiboot.img -no-emul-boot -isohybrid-gpt-basdat

}

function make_geniso {
    output_iso=$1

    sudo genisoimage -l -r -J -V "${iso_label}"\
         -b isolinux/isolinux.bin\
         -no-emul-boot -boot-load-size 4 -boot-info-table\
         -c isolinux/boot.cat -o $output_iso $customiso

    echo " - Making USB bootable"
    sudo isohybrid $output_iso
}

function writeLatestToUSB {
    last_usb_dev=`dmesg | tail | grep 'removable' | sed -r 's|\[[^[]+\[([a-z]+)\].*|/dev/\1|'`
    last_iso=`ls ./out/* -t | head -1 `

    [ "$last_usb_dev" = "" ] && echo "Could not determine USB" && exit -1
    [ "$last_iso" = "" ] && echo "Could not determine last ISO" && exit -1

    echo "Writing $last_iso -> $last_usb_dev, starting in 10 seconds"
    sleep 10
    
    sudo dd if=$last_iso of=$last_usb_dev status=progress
}


### main functions ###
function update {
    install_packages
    install_boot_opts
    set_starts
    updateSquash lz4
    createISO
}

function quickupdate {
    install_boot_opts
    set_starts
    updateSquash lz4
    createISO
}


## Main order ##
function install {
    download_if_empty
    init_mount_unpack
    install_packages
    copy_static_files
    set_permissions
    set_starts
    install_boot_opts
    updateSquash lz4
    createISO
    #writeLatestToUSB
}

$command
