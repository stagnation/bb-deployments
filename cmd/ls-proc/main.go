package main

import (
	"fmt"
	"os"
	"log"
)

func main() {
	entries, err := os.ReadDir("/proc/self")
	if err != nil {
		log.Fatal("Reading /proc/self:", err)
	}

	max := 10
	for i, e := range entries {
		if i > max {
			break
		}
		fmt.Println(e.Name())
	}

	os.Create(os.Args[1])
}
