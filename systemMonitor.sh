#!/bin/bash

OutputLogFilePath="."
MaxRAM=0
MaxCPU=0
Verbose=false


# this script checks the system performances each minute and monitors the most ram-consuming processes

date=$(date +%Y-%m-%d_%H:%M:%S)
echo "Starting the system monitor at [${date}] :"

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
    else 
        echo "error : unknown option <${arg}>. exiting the program..."
        exit 1
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

declare -A cpuLoadProcessBefore
declare -A cpuLoadProcessAfter

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
        if [ "$state" -eq 0 ]; then
            cpuTimeSpentBefore+=("$CoreTotalTime")
            cpuTimeOffBefore+=("$CoreOffTime")
        elif [ "$state" -eq 1 ]; then
            cpuTimeSpentAfter+=("$CoreTotalTime")
            cpuTimeOffAfter+=("$CoreOffTime")
        fi
        ((number++))
    done
}

GetLoadPerProcess() {
    for dir in /proc/[0-9]*; do
        if [ -e "${dir}/stat" ]; then
            ProcessInfos=$(cat "${dir}/stat")
            read -a DetailedProcessInfos <<< "${ProcessInfos}"
            totalTime=$((DetailedProcessInfos[13]+DetailedProcessInfos[14]))
            if [ "$state" -eq 0 ]; then
                cpuLoadProcessBefore["$DetailedProcessInfos[0]"]="${DetailedProcessInfos[1]} $totalTime"
            else
                cpuLoadProcessAfter["$DetailedProcessInfos[0]"]="${DetailedProcessInfos[1]} $totalTime"
            fi
        fi
    done
}

while true; do
    # get the cpu charge
    state=0
    GetCpuInfos "/proc/stat"
    GetLoadPerProcess
    sleep 10
    state=1
    GetCpuInfos "/proc/stat"
    GetLoadPerProcess
    # now, calculate the general percentage and the percentage of each core  and process
    for ((i = 0; i < "${#cpuTimeSpentBefore[@]}"; i++)); do
        totalTime=$(( cpuTimeSpentAfter[i] - cpuTimeSpentBefore[i] ))
        totalOff=$(( cpuTimeOffAfter[i] - cpuTimeOffBefore[i] )) 
        percentage=$(( (totalTime-totalOff) * 100 / totalTime ))
        cpuLoad+=("$percentage")
    done
    # calculate the ram usage
    Total=$(grep "MemTotal:" "/proc/meminfo")
    read -a TotalList <<< "$Total"
    free=$(grep "MemFree:" "/proc/meminfo")
    read -a FreeList <<< "$free"
    # calculate the swap usage
    TotalSwap=$(grep "SwapTotal:" "/proc/meminfo")
    read -a TotalListSwap <<< "$TotalSwap"
    freeSwap=$(grep "SwapFree:" "/proc/meminfo")
    read -a FreeListSwap <<< "$freeSwap"
    UsedSwap=$(( (TotalListSwap[1] - FreeListSwap[1]) / 1024 ))

    Used=$(( (TotalList[1] - FreeList[1]) / 1024 ))
    for key in "${!cpuLoadProcessBefore[@]}"; do
        if [ -n "$cpuLoadProcessAfter["$key"]" ]; then 
            read -s splittedArrayAfter <<< "${cpuLoadProcessAfter["$key"]}"
            read -s splittedArrayBefore <<< "${cpuLoadProcessBefore["$key"]}"
            difference=$((splittedArrayAfter[1]-splittedArrayBefore[1]))
            percentage=$(( difference * 100 / (( cpuTimeSpentAfter[1] - cpuTimeSpentBefore[1] )) ))
            path="${key:0:-3}"
            if [ "$MaxCPU" -gt 0 ]; then
                if [ "$percentage" -ge "$MaxCPU" ]; then
                    echo "do you want to terminate process ${splittedArrayBefore[0]} with PID <${path}> that is using ${percentage}% of the CPU ? Y/n : "
                    read answer
                    if [[ "$answer" == "Y" ]]; then
                        kill "$key"
                    fi 
                fi
            fi
            # and read the RAM usage
            if [ -e "/proc/${path}/statm" ]; then
                TotalProcess=$(cat "/proc/${path}/statm") 
                read -a TotalListProcess <<< "$TotalProcess"
                UsedProcess=$(( TotalListProcess[1] * 4096 / 1024 / 1024 ))
                if [ "$MaxRAM" -gt 0 ]; then
                    if [ "$UsedProcess" -ge "$MaxRAM" ]; then
                        echo "do you want to terminate process ${splittedArrayBefore[0]} with PID <${path}> that is using ${UsedProcess}Mb of RAM ? Y/n : "
                        read answer
                        if [[ "$answer" == "Y" ]]; then
                            kill "$key"
                        fi 
                    fi
                fi
            fi
        fi
    done

    if [[ "$Verbose" == "false" ]]; then
        date=$(date +%Y-%m-%d_%H:%M:%S)
        echo "Report at [${date}] : CPU usage ${cpuLoad[0]}%, RAM usage ${Used}M. more in depth infos are avalaible at ${OutputLogFilePath}/[${date}].log"
    else 
        echo "Report at [${date}] :"
        echo "General CPU usage : ${cpuLoad[0]}%"
        for ((i = 0; i < "${#cpuLoad[@]}" - 1; i++)); do
            echo "CPU core ${i} usage : ${cpuLoad[i + 1]}%"
        done
        echo "Total system RAM : $((TotalList[1] / 1024))M"
        echo "Total Free RAM : $((FreeList[1] / 1024))M"
        echo "Total Used RAM : ${Used}M"
        echo "Total system Swap : $((TotalListSwap[1] / 1024))M"
        echo "Total Free Swap : $((FreeListSwap[1] / 1024))M"
        echo "Total Used Swap : ${UsedSwap}M"
        mapfile -t lines < "/proc/diskstats"
        for ((i = 0; i < "${#lines[@]}"; i++)); do
            read -a elements <<< "${lines[i]}"
            echo "Total read on ${elements[2]} : $((elements[5] * 512 / 1024 / 1024))M."
            echo "Total Written on ${elements[2]} : $((elements[9] * 512 / 1024 / 1024))M."
        done
        echo "These stats are avalaible at ${OutputLogFilePath}/[${date}].log"
    fi 
    echo "General CPU usage : ${cpuLoad[0]}%" >> "${OutputLogFilePath}/[${date}].log"
    for ((i = 0; i < "${#cpuLoad[@]}" - 1; i++)); do
        echo "CPU core ${i} usage : ${cpuLoad[i + 1]}%" >> "${OutputLogFilePath}/[${date}].log"
    done
    echo "Total system RAM : $((TotalList[1] / 1024))M" >> "${OutputLogFilePath}/[${date}].log"
    echo "Total Free RAM : $((FreeList[1] / 1024))M" >> "${OutputLogFilePath}/[${date}].log"
    echo "Total Used RAM : ${Used}M" >> "${OutputLogFilePath}/[${date}].log"
    echo "Total system Swap : $((TotalListSwap[1] / 1024))M" >> "${OutputLogFilePath}/[${date}].log"
    echo "Total Free Swap : $((FreeListSwap[1] / 1024))M" >> "${OutputLogFilePath}/[${date}].log"
    echo "Total Used Swap : ${UsedSwap}M" >> "${OutputLogFilePath}/[${date}].log"
    mapfile -t lines < "/proc/diskstats"
    for ((i = 0; i < "${#lines[@]}"; i++)); do
        read -a elements <<< "${lines[i]}"
        echo "Total read on ${elements[2]} : $((elements[5] * 512 / 1024 / 1024))M." >> "${OutputLogFilePath}/[${date}].log"
        echo "Total Written on ${elements[2]} : $((elements[9] * 512 / 1024 / 1024))M." >> "${OutputLogFilePath}/[${date}].log"
    done
    cpuLoad=()
    cpuTimeSpentBefore=()
    cpuTimeOffBefore=()
    cpuTimeSpentAfter=()
    cpuTimeOffAfter=()
    declare -A cpuLoadProcessBefore
    declare -A cpuLoadProcessAfter

done