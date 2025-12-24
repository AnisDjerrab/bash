# bash
A couple of scripts I made to learn to bash syntax

# task manager
A minimal cli task manager that loops every 10 secondes, reads /proc/stat and other system files, extracts the cpu, ram, and disk I/O usages, with additional options to kill programs that exceed some resource limits.
```
Usage :
  -v|--verbose : toggle verbose setting.
  -o|--output <outputDirectory> : set the log file output directory.
  -r|--MaxRAM <ValueInMegabyte> : max amount of RAM a process is allowed to use before the user is prompted to terminate it.
  -c|--MaxCPU <ValueInPercent> : max percent of CPU a process is allowed to use before the user is prompted to terminate it.
  -h|--help : Output this help panel
```
# file saving
A small bash script to compress input files using tar or bsdtar and moves them to a predefined directory (./extracted).
``` 
Usage :
  ./FileSaving.sh <file1> <folder2>...
```
