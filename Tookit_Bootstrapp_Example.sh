#!/bin/bash
# shellcheck enable=require-variable-braces
# shellcheck disable=SC2034,2002,2004,2207,2010,2068
# shellcheck source=/dev/null
## DO NOT REMOVE THESE!
## This is to prevent shellcheck from complaining about false positive issues like unused variables.

## Crash On Fail
set -e pipefail

## Testing
FancyTermStatus="1"

## Toolkit Module Folders
ToolkitMainDir="${ToolKitDir}main"
ToolkitMenuDir="${ToolKitDir}menu"


###############
## FUNCTIONS ##
###############

## Specifically Load A Module
LoadModule() {
    local LoadAttemptReturn
    [[ -z "${1}" ]] && printf "%s\n" "[ERROR] Target Module Field Required" >&2 && return 1
    [[ -z "${2}" ]] && printf "%s\n" "[ERROR] Target Module Name Required" >&2 && return 1
    source "${1}"; LoadAttemptReturn=${?}
    case "${LoadAttemptReturn}" in
        0) ## Module Loaded Successfully
            printf "%s\n" "Successfully Loaded Module: ${2^}"
        ;;
        1) ## Module Load Failed
            printf "%s\n" "[ERROR] Failed Loading Module: ${2^}" >&2 && return 1
        ;;
        *) ## Unexpected Module Load Result
            printf "%s\n" "[ERROR] Unexpected Result Loading Module: ${2^}" >&2 && return 1
        ;;
    esac
} ## End Of Function


## Specifically Load A Controller
LoadMasterController() {
    local LoadAttemptReturn
    case "${1:-NULL}" in
        ""|"NULL"|"null")
            printf "%b\n" "[ERROR] Master Controller Required" >&2 && return 1
        ;;
        *)
            source "${1}";LoadAttemptReturn=${?}
            case "${LoadAttemptReturn}" in
                0) ## Controller Loaded Successfully
                    #printf "%s\n" "Successfully Loaded Controller: ${2^}"
                    InitializeController "${AppID:-Unknown}"
                ;;
                1) ## Controller Load Failed
                    printf "%s\n" "[ERROR] Failed Loading Controller: ${2^}" >&2 && return 1
                ;;
                *) ## Unexpected Controller Load Result
                    printf "%s\n" "[ERROR] Unexpected Result Loading Controller: ${2^}" >&2 && return 1
                ;;
            esac
        ;;
    esac
} ## End Of Function

## Module Bootstrapper
SystemModuleInit() {
    ## Make Sure Network And Core Are Present
    [[ ! -f "${ToolKitDir}modules/system/core.sh" ]] && printf "%s\n" "[ERROR] Core Module Missing" >&2 && return 1
    ## Load Core And Network First, Then The rest
    LoadModule "${ToolKitDir}modules/system/core.sh" "Core"
    for SysModule in ${SysModules[@]}; do
        LoadModule "${ToolKitDir}modules/system/${SysModule}" "${SysModule::-3}"
    done
} ## End Of Function

## Find System Modules
SystemModuleDiscovery() {
    #printf "%s\n" "Scanning For Modules..."
    SysModules=($( ls -R "${ToolKitDir}modules/system/" | grep -E "[a-zA-Z]{1,}\.sh"))
    case "${SysModules[*]:-NULL}" in
        ""|"NULL"|"null")
            printf "%s\n" "[ERROR] No System Modules Found" >&2 && return 1
        ;;
        *)
            ## Module Array Cleanup
            SysModules=("${SysModules[@]/core.sh}")
            ## NOTE: The above edit leaves spaces on purpose, we still want to count total modules unlike the controllers
            return 0
        ;;
    esac
} ## End Of Function

## Find Game Modules
GameModuleDiscovery() {
    #printf "%s\n" "Scanning For Modules..."
    GameModules=($( ls -R "${ToolKitDir}modules/games/" | grep -E "[a-zA-Z]{1,}\.sh"))
    case "${GameModules[*]:-NULL}" in
        ""|"NULL"|"null")
            printf "%s\n" "[ERROR] No Game Modules Found" >&2 && return 1
        ;;
        *)
            return 0
        ;;
    esac
} ## End Of Function

## Find Controller Profiles
ControllerDiscovery() {
    #printf "%s\n" "Scanning For Application Controllers..."
    ApplicationControllers=($( ls -R "${ToolKitDir}controllers/" | grep -E "[a-zA-Z]{1,}\.sh"))
    case "${ApplicationControllers[*]:-NULL}" in
        ""|"NULL"|"null")
            printf "%s\n" "[ERROR] No Application Controllers Found" >&2 && return 1
        ;;
        *)
            ## Module Array Cleanup
            ApplicationControllers=("${ApplicationControllers[@]/appid_controller.sh}")
            return 0
        ;;
    esac
} ## End Of Function

## Todo: Controller init

## Find Toolkit Directory
ToolKitDirectoryDiscovery() {
    ## Create And Assign Variables
    local LocalSource && local LocalWorking
    LocalSource="$(dirname "${BASH_SOURCE[0]}")"
    LocalWorking="$(cd "${LocalSource}" && pwd)"
    ## Verify The Local Working Directory Is Valid
    case "$([[ -d "${LocalWorking}" ]] )${?}" in
        0)  ## Working Directory Is Valid
            case "$([[ -d "${LocalWorking}/toolbox/" ]] )${?}" in
                0) ## Directory Exists
                    ToolKitDir="${LocalWorking}/toolbox/" && return 0
                ;;
                1) ## Directory Does Not Exist
                    local FirstUpDir && local SecondUpDir && local DirScan
                    FirstUpDir="${LocalWorking%\/*}"
                    SecondUpDir="${FirstUpDir%\/*}"
                    ## Scan Immediate Above Directory Structure In Attempt To Find Toolkit Directory
                    DirScan="$( ls -D "${FirstUpDir}" | grep -o "toolbox" )"
                    ## Check Scan Results To See If The Directory Exists
                    case "${DirScan:-NULL}" in 
                        ""|"NULL"|"null")
                            DirScan="$( ls -D "${SecondUpDir}" | grep -o "toolbox" )"
                            case "${DirScan:-NULL}" in
                                ""|"NULL"|"null") ## Directory Invalid
                                    printf "%s\n" "[ERROR] Could Not Find Toolkit Directory" "Exiting..." >&2 && return 1
                                ;;
                                *)
                                    ToolKitDir="${SecondUpDir}/${DirScan}" && return 0
                                ;;
                            esac
                        ;;
                        *)
                            ToolKitDir="${FirstUpDir}/${DirScan}" && return 0
                        ;;
                    esac
                ;;
                *) ## Unexpected Directory Return Value
                    printf "%s\n" "[ERROR] Unexpected Directory Validity Return Value" "Exiting..." >&2 && return 1
                ;;
            esac
        ;;
        1) ## Working Directory Is Invalid
            printf "%s\n" "[ERROR] Could Not Identify Working Directory" "Exiting..." >&2 && return 1
        ;;
        *) ## Unexpected Directory Return Value
            printf "%s\n" "[ERROR] Unexpected Working Directory Resolution Return Value" "Exiting..." >&2 && return 1
        ;;
    esac
} ## End Of Function

APIConnectionCheck() { ## Phone Home To The Nightowl API
    local SanityCheck && SanityCheck="$( Legatus S | jq -r .attributes.uuid)"
    ## Scrape UUID, If Null We Are Running On A Jacked Node
    case "${SanityCheck:-NULL}" in
        ""|"NULL"|"null") ## Directory Invalid
            Panik "For Nightowl Use Only" >&2 && return 1
        ;;
        *)
            return 0
        ;;
    esac
}

## Bootstrapper Function
ToolKitBootStrapper() {
    ##
    ## ToolKitFileArr=($( ls -R "${ToolKitDir}" | grep -E "[tolman]{3,}\.sh" ))
    ##
    local ToolKitFileArr
    ToolKitDirectoryDiscovery
    ## Confirm Directory
    case "${ToolKitDir:-NULL}" in
        ""|"NULL"|"null") ## Directory Invalid
            printf "%s\n" "[ERROR] Could Not Identify Toolkit Directory" "Exiting..." >&2 && return 1
        ;;
        *) ## Directory Valid, Toolkit Found
            SystemModuleDiscovery
            case "${?}" in 
                0)
                    printf "%s\n" "Found ${#SysModules[@]} Modules"
                    SystemModuleInit
                    case "${?}" in 
                        0)
                            printf "%s\n" "Modules Loaded Successfully"
                            ## Phone Home To Make Sure We're Not Stolen
                            ControllerDiscovery
                            case "${?}" in
                                0) ## Toolkit Is Fully Up
                                    printf "%s\n" "Toolkit Initialized"
                                    LoadMasterController "${ToolKitDir}controllers/appid_controller.sh" "Master"
                                    case "${?}" in
                                        0)
                                            return 0
                                        ;;
                                        1)
                                            printf "%s\n" "[ERROR] Could Not Load Master Controller" >&2 && return 1
                                        ;;
                                        *)
                                            printf "%s\n" "[ERROR] Unexpected Error Loading Master Controller" >&2 && return 1
                                        ;;
                                    esac
                                    return 0
                                ;;
                                1)
                                    printf "%s\n" "[ERROR] Could Not Verify With API" "Exiting..." >&2 && return 1
                                ;;
                            esac
                        ;;
                        1)
                            printf "%s\n" "[ERROR] Failed To Initialize Modules" "Exiting..." >&2 && return 1
                        ;;
                        *)
                            printf "%s\n" "[ERROR] Unexpected Return While Loading Modules" "Exiting..." >&2 && return 1
                        ;;
                    esac
                ;;
                1)
                    printf "%s\n" "[ERROR] Failed to Find Modules" "Exiting..." >&2 && return 1
                ;;
                *)
                    printf "%s\n" "[ERROR] Unexpected Return When Finding Modules" "Exiting..." >&2 && return 1
                ;;
            esac
        ;;
    esac
} ## End Of Function

## Initialize Toolkit
ToolKitBootStrapper