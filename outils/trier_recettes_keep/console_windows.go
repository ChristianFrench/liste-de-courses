package main

import "syscall"

// Accents lisibles dans la console Windows (UTF-8).
func init() {
	k := syscall.NewLazyDLL("kernel32.dll")
	k.NewProc("SetConsoleOutputCP").Call(65001)
	k.NewProc("SetConsoleCP").Call(65001)
}
