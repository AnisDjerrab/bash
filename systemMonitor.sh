#!/bin/bash

OutputLogFilePath="./"
MaxRAM=0
MaxCPU=0
Verbose=false


# this script checks the system performances each minute and monitors the most ram-consuming processes

date=$(date +%Y-%m-%d_%H:%M:%S)
echo "starting the system monitor at ${date}"

Output=false
RAMLimit=false
CPULimit=false

for ((i = 1; i <= $#; i++)); do
    arg="${!i}"
    if [[ "$Output" == true ]]; then
        if [ -d "${arg}" ]; then
            OutputLogFilePath="${arg}"
            Output=false
        else 
            echo "invalid path <${arg}>. exiting the program..."
            exit 1
        fi
    elif [[ "$RAMLimit" == true ]]; then
        MaxRAM="${arg}"
        RAMLimit=false
    elif [[ "$CPULimit" == true ]]; then
        MaxCPU="${arg}"
        CPULimit=false
    elif [[ "$arg" == "-v" || "$arg" == "--verbose" ]]; then 
        Verbose=true
    elif [[ "$arg" == "-o" || "$arg" == "--outputDirectory" ]]; then
        Output=true
    elif [[ "$arg" == "-r" || "$arg" == "--MaxRAM" ]]; then
        RAMLimit=true
    elif [[ "$arg" == "-c" || "$arg" == "--MaxCPU" ]]; then
        CPULimit=true
    elif [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "System monitor version 1.0.0 by @AnisDjerrab, GNU general public lisence v3.0, 2025."
        echo "Usage :"
        echo "  -v|--verbose : toggle verbose setting."
        echo "  -o|--output <outputDirectory> : set the log file output directory."
        echo "  -r|--MaxRAM <ValueInMegabyte> : max amount of RAM a process is allowed to use before the user is prompted to terminate it."
        echo "  -c|--MaxCPU <ValueInPercent> : max percent of CPU a process is allowed to use before the user is prompted to terminate it."
        echo "  -h|--help : Output this help panel"
        echo "Thank's for supporting my work!"
        exit 0
    fi
done

if [[ "$Output" == true ]]; then
    echo "error : no path provided. exiting the program..."
    exit 1
fi

if [[ "$RAMLimit" == true ]]; then
    echo "error : no ram limit provided. exiting the program..."
    exit 1
fi

if [[ "$CPULimit" == true ]]; then
    echo "error : no cpu limit provided. exiting the program..."
    exit 1
fi

cpuLoad=()
cpuTimeSpentBefore=()
cpuTimeOffBefore=()
cpuTimeSpentAfter=()
cpuTimeOffAfter=()

state=0

GetCpuInfos() {
    local path="$1"
    # first get the cpu general usage informations
    GeneralCPUInfos=$(grep "cpu" "${path}")
    read -a CPUInfosNumbers <<< "${GeneralCPUInfos}"
    GeneralTotalTime=$((CPUInfosNumbers[0]+CPUInfosNumbers[1]+CPUInfosNumbers[2]+CPUInfosNumbers[3]+CPUInfosNumbers[4]+CPUInfosNumbers[5]+CPUInfosNumbers[6]+CPUInfosNumbers[7]+CPUInfosNumbers[8]+CPUInfosNumbers[9]))
    GeneralOffTime=$((CPUInfosNumbers[3]+CPUInfosNumbers[4]))
    if [ $state -eq 0 ]; then
        cpuTimeSpentBefore+=("$GeneralTotalTime")
        cpuTimeOffBefore+=("$GeneralOffTime")
    elif [ $state -eq 1 ]; then
        cpuTimeSpentAfter+=("$GeneralTotalTime")
        cpuTimeOffAfter+=("$GeneralOffTime")
    fi

    # now get each core usage infos
    number=0
    while true; do
        coreName="cpu${number}"
        CPUCoreInfos=$(grep "${coreName}" "${path}")
        if [ -z "${CPUCoreInfos}" ]; then
            break
        fi
        read -a CoreInfosNumbers <<< "${CPUCoreInfos}"
        CoreTotalTime=$((CoreInfosNumbers[0]+CoreInfosNumbers[1]+CoreInfosNumbers[2]+CoreInfosNumbers[3]+CoreInfosNumbers[4]+CoreInfosNumbers[5]+CoreInfosNumbers[6]+CoreInfosNumbers[7]+CoreInfosNumbers[8]+CoreInfosNumbers[9]))
        CoreOffTime=$((CoreInfosNumbers[3]+CoreInfosNumbers[4]))
        if [ $state -eq 0 ]; then
            cpuTimeSpentBefore+=("$CoreTotalTime")
            cpuTimeOffBefore+=("$CoreOffTime")
        elif [ $state -eq 1 ]; then
            cpuTimeSpentAfter+=("$CoreTotalTime")
            cpuTimeOffAfter+=("$CoreOffTime")
        fi
        ((number++))
    done
}


while true; do
    # get the cpu charge
    state=0
    GetCpuInfos "/proc/stat"
    sleep 1
    state=1
    GetCpuInfos "/proc/stat"
    # now, calculate the general percentage and the percentage of each core 
    for ((i = 0; i < "${#cpuTimeSpentBefore[@]}"; i++)); do
        totalTime=$(( cpuTimeSpentAfter[i] - cpuTimeSpentBefore[i] ))
        totalOff=$(( cpuTimeOffAfter[i] - cpuTimeOffBefore[i] )) 
        percentage=$(( (totalTime-totalOff) * 100 / totalTime ))
        cpuLoad+=("$percentage")
    done

    echo "${cpuLoad[@]}"

    cpuLoad=()
    cpuTimeSpentBefore=()
    cpuTimeOffBefore=()
    cpuTimeSpentAfter=()
    cpuTimeOffAfter=()

done