all:
	rm -f image.flp
	nasm -f bin -o bootloader.bin bootloader.asm
	nasm -f bin -o kernel.bin kernel.asm
	mkdosfs -f 2 -F 12 -C image.flp 1440
	dd conv=notrunc if=bootloader.bin of=image.flp bs=512
	mcopy -i image.flp kernel.bin ::/
	#dd conv=notrunc if=kernel.bin of=image.flp seek=1 bs=512
	#dd conv=notrunc if=hello.bin of=image.flp seek=4 bs=512
	hexdump -C image.flp > hexdump
#	qemu-system-i386 -fda image.flp

#iso:
#	mkisofs -no-emul-boot  -o image.iso -b image.flp .

test: all
	bochs -q

clean:
	rm *.bin *.flp hexdump
