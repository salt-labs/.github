#requires -PSEdition Core

<#

.SYNOPSIS

    Adds outputs based on environment variables

.DESCRIPTION

    Adds outputs based on environment variables

    For the defined environment variables below, makes if the determination
        * If AUTO, attempts to determine TRUE/FALSE
        * If TRUE, sets the output
        * If FALSE, does nothing

.PARAMETER LogLevel

    Optional log level to use for the script output.

    Valid options; debug, info, information, verbose, warn, warning, err, error

    Defaults to information level logging

.PARAMETER Project

    Optional name of the GitHub project.

    If not provided, the script will determine the project name from the ${ENV:GITHUB_REPOSITORY} variable if present.

.PARAMETER DieHard

    Exits with a non-zero return code from any error. Useful for CI systems.

.INPUTS

    * Log Level
    * Project name
    * GitHub Actions environment variables

.OUTPUTS

    * GitHub Actions outputs are set in the correct format to be used by subsequent jobs.

.NOTES

    Version: 		0.1
    Author: 		MAHDTech@saltlabs.tech
    Creation Date:	02/07/2020
    Purpose/Change:	Initial script development

    Version:        0.2
    Author:         MAHDTech@saltlabs.tech
    Creation Date:	07/07/2020
    Purpose/Change:	Implemented auto-detection

.EXAMPLE

    ./outputs.ps1 `
        -LogLevel Info `
        -DieHard

#>

#################################################
# Parameters
#################################################

[CmdletBinding(

    ConfirmImpact = "Medium",
    DefaultParameterSetName = "DefaultParameterSet",
    HelpURI = "",
    SupportsPaging = $False,
    SupportsShouldProcess = $True,
    PositionalBinding = $False

)]
Param(

    # Parameter: LogLevel
    [Parameter(
        Mandatory = $False,
        HelpMessage = "[OPTIONAL]: The Log Level for the script. Valid options; Debug, Information, Warning, Error"
    )]
    [ValidateSet(
        "Debug",
        "Verbose",
        "Information",
        "Info",
        "Warning",
        "Warn",
        "Error",
        "Err"
    )]
    [String]
    $LogLevel = "Information",

    # Parameter: Project
    [Parameter(
        Mandatory = $False,
        HelpMessage = "[OPTIONAL]: The name of the GitHub Project."
    )]
    [ValidateNotNullOrEmpty()]
    [String]
    $Project = "Default",

    # Parameter: DieHard
    [Parameter(
        Mandatory = $False,
        HelpMessage = "[OPTIONAL]: A switch to fail early on error."
    )]
    [Switch]
    $DieHard

)

#################################################
# Begin
#################################################

Begin {

    #########################
    # Declarations
    #########################

    If ( $DieHard ) {
        $ErrorActionPreference = "Stop"
    } Else {
        $ErrorActionPreference = "Continue"
    }

    $ProgressPreference = "Continue"
    $ConfirmPreference = "High"

    # Set the Invocation
    $ScriptInvocation = (Get-Variable MyInvocation -Scope Script).Value

    # Get the invocation path (relative to $PWD)
    $ScriptInvocationPath = $ScriptInvocation.InvocationName

    # Full path to the script
    $ScriptPath = $ScriptInvocation.MyCommand.Path

    # Get the directory of the script
    $ScriptDirectory = Split-Path $ScriptPath

    # Name of the script
    $ScriptFileName = $ScriptInvocation.MyCommand.Name

    # Script Version
    $ScriptVersion = "0.1"

    # Set the Script Name so it can be used in logs, matching the filename with no extension
    $ScriptName = [System.IO.Path]::GetFilenameWithoutExtension($ScriptFileName)

    # Decorate the console
    $Host.Ui.RawUI.WindowTitle = "$ScriptName v$ScriptVersion"

    # Initialise an error counter
    $Global:ErrorCount = 0

    #########################
    # Functions
    #########################

    Function Register-Logging {

        <#

        .SYNOPSIS

            Sets the logging level used throughout the script based on a provided parameter.

        #>

        [CmdletBinding()]
        Param()

        Begin {

        }

        Process {

            $ValidLogLevels = @(
                "Debug",
                "Verbose",
                "Information",
                "Info",
                "Warning",
                "Warn",
                "Error",
                "Err"
            )

            If ( $ValidLogLevels -NotContains $LogLevel ) {

                Write-Output "The provided Log Level '$LogLevel' is invalid. Defaulting to a Log Level of 'Information'"
                $LogLevel = "Information"

            }

            # LogLevel is a parameter defined in the Global scope
            Switch ( $LogLevel ) {

                { "Debug" -Contains "$_" } {

                    $Global:DebugPreference = "Continue"
                    $Global:VerbosePreference = "Continue"
                    $Global:InformationPreference = "Continue"
                    $Global:WarningPreference = "Continue"
                    Break

                }

                { "Verbose" -Contains "$_" } {

                    $Global:DebugPreference = "SilentlyContinue"
                    $Global:VerbosePreference = "Continue"
                    $Global:InformationPreference = "Continue"
                    $Global:WarningPreference = "Continue"
                    Break

                }

                { "Information", "Info" -Contains "$_" } {

                    $Global:DebugPreference = "SilentlyContinue"
                    $Global:VerbosePreference = "SilentlyContinue"
                    $Global:InformationPreference = "Continue"
                    $Global:WarningPreference = "Continue"
                    Break

                }

                { "Warning", "Warn" -Contains "$_" } {

                    $Global:DebugPreference = "SilentlyContinue"
                    $Global:VerbosePreference = "SilentlyContinue"
                    $Global:InformationPreference = "SilentlyContinue"
                    $Global:WarningPreference = "Continue"
                    Break

                }

                { "Error", "Err" -Contains "$_" } {

                    $Global:DebugPreference = "SilentlyContinue"
                    $Global:VerbosePreference = "SilentlyContinue"
                    $Global:InformationPreference = "SilentlyContinue"
                    $Global:WarningPreference = "SilentlyContinue"
                    Break

                }

            }

        }

        End {

        }

    }

    Function Get-TimeStamp {

        <#

        .SYNOPSIS

            Returns a date in a format useful for log files

        #>

        Begin {

        }

        Process {

            Return Get-Date -Format "yyyy-MM-dd hh:mm:ss"

        }

        End {

        }

    }

    Function Write-Log {

        <#

        .SYNOPSIS

            Writes to stdout as a method of logging.

        .DESCRIPTION

            Writes to stdout and an optional log file as a method of logging.

        .PARAMETER LogLevel

            Case insensitive log level of the message written to file. Available options are;

                - Debug
                - Verbose
                - Information, Info
                - Warning, Warn
                - Error, Err

        .PARAMETER LogMessage

            Mandatory. The log message to write to the log file.

            Example:
                "This is a log message"

        .PARAMETER LogFile

            Optional. If you also want the log to be written to a log file as well as stdout.

            Example:
                "my-script.log"

        .PARAMETER Fatal

            Switch to indicate if the error is Fatal and the script should stop.

        .INPUTS

            Parameters

        .OUTPUTS

            Messages to stdout
            Log file if enabled

        .NOTES

            Version:        1.0
            Author:         MAHDTech
            Creation Date:  02/05/2019
            Purpose/Change: Initial function development

            Version:        1.1
            Author:         MAHDTech
            Creation Date:  15/05/2019
            Purpose/Change: Improved error handling

        .EXAMPLE

            Write-Log -LogLevel "Information" -LogMessage "Started $ScriptName"

        .EXAMPLE

            Write-Log -LogLevel "Debug" -LogFile "my-script.log" -LogMessage "This is a debug message"

        .EXAMPLE

            Write-Log -LogLevel "Error" -LogMessage "Fatal Exception $_.Exception" -Fatal

        #>

        [CmdletBinding(

            ConfirmImpact = "Medium",
            DefaultParameterSetName = "DefaultParameterSet",
            HelpURI = "",
            SupportsPaging = $False,
            SupportsShouldProcess = $True,
            PositionalBinding = $False

        )]
        Param (

            # Parameter: LogLevel
            [Parameter(
                Mandatory = $True,
                HelpMessage = "[MANDATORY]: The Log Level to display. Valid options; Debug, Information, Warning, Error"
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateSet(
                "Debug",
                "Verbose",
                "Information",
                "Info",
                "Warning",
                "Warn",
                "Error",
                "Err"
            )]
            [String]
            $LogLevel,

            # Parameter: LogMessage
            [Parameter(
                Mandatory = $True,
                HelpMessage = "[MANDATORY]: The message to write to the log file."
            )]
            [ValidateNotNullOrEmpty()]
            [String]
            $LogMessage,

            # Parameter: LogFile
            [Parameter(
                Mandatory = $False,
                HelpMessage = "[OPTIONAL]: The full path to the Log File to write the message in."
            )]
            [ValidateNotNullOrEmpty()]
            [String]
            $LogFile,

            # Parameter: Fatal
            [Parameter(
                Mandatory = $False,
                HelpMessage = "[MANDATORY]: Switch that indicates the error is Fatal and the script will stop."
            )]
            [Switch]
            $Fatal,

            # Parameter: Fresh
            [Parameter(
                Mandatory = $False,
                HelpMessage = "[OPTIONAL]: Switch that indicates to start a Fresh log file."
            )]
            [Switch]
            $Fresh

        )

        Begin {

            $AddContent = $NULL

        }

        Process {

            Switch ( $LogLevel ) {

                { "Debug" -Contains "$_" } {

                    $LogFileLevel = "DEBUG"
                    Write-Debug -Message "$(Get-TimeStamp) - $LogMessage"
                    If ( $DebugPreference -eq "SilentlyContinue" ) {
                        $AddContent = $False
                    } Else {
                        $AddContent = $True
                    }

                }

                { "Verbose" -Contains "$_" } {

                    $LogFileLevel = "VERBOSE"
                    Write-Verbose -Message "$(Get-TimeStamp) - $LogMessage"
                    If ( $VerbosePreference -eq "SilentlyContinue" ) {
                        $AddContent = $False
                    } Else {
                        $AddContent = $True
                    }

                }

                { "Information", "Info" -Contains "$_" } {

                    $LogFileLevel = "INFO"
                    Write-Information -Message "$(Get-TimeStamp) - $LogMessage"
                    If ( $InformationPreference -eq "SilentlyContinue" ) {
                        $AddContent = $False
                    } Else {
                        $AddContent = $True
                    }

                }

                { "Warning", "Warn" -Contains "$_" } {

                    $LogFileLevel = "WARNING"
                    Write-Warning -Message "$(Get-TimeStamp) - $LogMessage"
                    If ( $WarningPreference -eq "SilentlyContinue" ) {
                        $AddContent = $False
                    } Else {
                        $AddContent = $True
                    }

                }

                { "Error", "Err" -Contains "$_" } {

                    $LogFileLevel = "ERROR"
                    #Write-Error -Message "$(Get-TimeStamp) - $LogMessage"
                    Write-Warning -Message "$(Get-TimeStamp) - $LogMessage"
                    $AddContent = $True
                    # Increment the error count for DieHard mode.
                    $Global:ErrorCount ++

                }

                Default {

                    $LogFileLevel = "UNKNOWN"
                    Write-Warning -Message "An incorrect Log Level of $LogLevel was provided to the Write-Log function"
                    $AddContent = $True

                }

            }

            # If the LogFile is defined
            if ( $LogFile ) {

                If ( $PScmdlet.ShouldProcess( "$LogFile", "Write message to the Log File" ) ) {

                    # Fresh will always run as the file needs to be started :/
                    If ( $Fresh ) {

                        # Create a fresh log file
                        New-Item -ItemType File -Path "$LogFile" -Force | Out-Null

                    }

                    If ( $AddContent ) {

                        # Append the log file
                        Add-Content -Path "$LogFile" -Value "$(Get-TimeStamp) $LogFileLevel $LogMessage"

                    }

                }

            }

            # If Fatal was provided
            If ( $Fatal ) {

                Throw "Fatal Error. Execution of $ScriptName Halted."

            }


        }

        End {

            $AddContent = $NULL

        }

    }
    #Export-ModuleMember -Function Write-Log -Alias Log

    Function Start-Detection {

        <#

        .SYNOPSIS

            Starts the automatic detection process

        .DESCRIPTION

            Starts the automatic detection process to determine if
            the output should be enabled or disabled.

        .PARAMETER Name

            The Name of the variable to auto-detect.

            Supported values are;
                - ENABLE_DOCKER
                - ENABLE_GO
                - ENABLE_PULUMI
                - ENABLE_RUST

        .INPUTS

            Parameters

        .OUTPUTS

            GitHub Actions outputs in the format as follows:

            "::set-output name=ENABLE_XXXXX::TRUE"
            "::set-output name=ENABLE_XXXXX::FALSE"

        .EXAMPLE

            Start-Detection -Name ENABLE_DOCKER

        #>

        Param (

            # Parameter: Name
            [Parameter(
                Mandatory = $True,
                HelpMessage = "[MANDATORY]: The name of the supported environment variable."
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateSet(
                "ENABLE_DOCKER",
                "ENABLE_GO",
                "ENABLE_PULUMI",
                "ENABLE_RUST"
            )]
            [String]
            $Name

        )

        Begin {

            # Default to False
            $DetectionResult = "FALSE"

            # The output name needs to be in lower case
            $OutputName = $Name.ToLower()

        }

        Process {

            Write-Log -LogLevel Debug -LogMessage "Running auto-detection for $Name"

            Switch ( $Name ) {

                { "ENABLE_DOCKER" -Match "$_" } {

                    Write-Log -LogLevel Debug -LogMessage "Matched $_"

                    # Is there a Dockerfile in this repo?
                    If ( Test-Path -PathType Leaf "Dockerfile" ) {
                        Write-Log -LogLevel Debug -LogMessage "Enabling $_"
                        $DetectionResult = "TRUE"
                    } Else {
                        Write-Log -LogLevel Debug -LogMessage "Disabling $_"
                        $DetectionResult = "FALSE"
                    }

                }

                { "ENABLE_GO" -Match "$_" } {

                    Write-Log -LogLevel Debug -LogMessage "Matched $_"

                    # Find all the go files in this repo
                    $GoFiles = Get-ChildItem -Path .\ -Filter *.go -Recurse -File -ErrorAction Ignore

                    # Is there a Go modules file or .go files in the repo?
                    If ( ( Test-Path -PathType Leaf "go.mod" ) -Or ( $GoFiles.count -ge 1 ) ) {
                        Write-Log -LogLevel Debug -LogMessage "Enabling $_"
                        $DetectionResult = "TRUE"
                    } Else {
                        Write-Log -LogLevel Debug -LogMessage "Disabling $_"
                        $DetectionResult = "FALSE"
                    }

                }

                { "ENABLE_PULUMI" -Match "$_" } {

                    Write-Log -LogLevel Debug -LogMessage "Matched $_"

                    # Is there a .pulumi folder in this repo?
                    If ( Test-Path -PathType Container ".pulumi") {
                        Write-Log -LogLevel Debug -LogMessage "Enabling $_"
                        $DetectionResult = "TRUE"
                    } Else {
                        Write-Log -LogLevel Debug -LogMessage "Disabling $_"
                        $DetectionResult = "FALSE"
                    }

                }

                { "ENABLE_RUST" -Match "$_" } {

                    Write-Log -LogLevel Debug -LogMessage "Matched $_"

                    # Find all the go files in this repo
                    $RustFiles = Get-ChildItem -Path .\ -Filter *.rs -Recurse -File -ErrorAction Ignore

                    # Is there a cargo.toml or .rs files in this repo?
                    If ( ( Test-Path -PathType Leaf "cargo.toml" ) -Or ( $RustFiles.count -ge 1 ) ) {
                        Write-Log -LogLevel Debug -LogMessage "Enabling $_"
                        $DetectionResult = "TRUE"
                    } Else {
                        Write-Log -LogLevel Debug -LogMessage "Disabling $_"
                        $DetectionResult = "FALSE"
                    }

                }

                Default {

                    Write-Log -LogLevel Debug -LogMessage "No Match for $_"

                    Write-Log -LogLevel "Warn" -LogMessage "Auto-detection not yet implemented for $Name. Defaulting to 'FALSE'"

                }

            }

        }

        End {

            Write-Output "::set-output name=$OutputName::$DetectionResult"

        }

    }

    #########################
    # Parameter Validation
    #########################

    Try {

        Register-Logging

    } Catch {

        Write-Host "Failed to register logging, unable to continue"
        Exit $LASTEXITCODE

    }

    # Parameter: LogLevel
    Write-Log -LogLevel "Debug" -LogMessage "Initialized logging to Log Level $LogLevel"

    # Parameter: Target
    Write-Log -LogLevel "Debug" -LogMessage "Target set to $Target"

    # Parameter: Project
    If ( $Project -eq "Default" ) {

        Write-Log -LogLevel "Debug" -LogMessage "No Project provided, using default GITHUB_REPOSITORY variable if available"

        if ( $NULL -eq ${ENV:GITHUB_REPOSITORY} ) {
            Write-Log -Fatal -LogLevel "Error" -LogMessage "No project name was provided and the GITHUB_REPOSITORY variable is empty. Please provide a Project to continue"
        }

        $Project = ${ENV:GITHUB_REPOSITORY}.Substring(${ENV:GITHUB_REPOSITORY}.IndexOf('/')+1)

    }

    Write-Log -LogLevel "Debug" -LogMessage "Project set to $Project"

}

#################################################
# Process
#################################################

Process {

    Write-Log -LogLevel "Information" -LogMessage "$ScriptName has started"

    # The project type is a required variable as its depended on for other
    # jobs in the workflow. If the environment variable was not set, inform
    # the user it's required, otherwise set the output for the Project type
    if ( $NULL -eq ${ENV:PROJECT_TYPE} ) {
        Write-Log -Fatal -LogLevel "Error" -LogMessage "No project type was provided in the `$ENV:PROJECT_TYPE environment variable. This is a required. See the example Workflow for configuration."
    }
    Write-Output "::set-output name=project_type::${ENV:PROJECT_TYPE}"

    # A defined list of support environment variable names
    $VARIABLES = @(
        "ENABLE_DOCKER",
        "ENABLE_GO",
        "ENABLE_PULUMI",
        "ENABLE_RUST"
    )

    # Loop over each variable, and if set to auto, run the appropriate function
    ForEach ( $VARIABLE_NAME in $VARIABLES ) {

        Try {

            Write-Log -LogLevel Debug -LogMessage "Processing $VARIABLE_NAME"

            # Determine the current value for the variable if defined
            If ( Get-Variable -Name $VARIABLE_NAME -ErrorAction Ignore ) {
                $VARIABLE_VALUE = Get-Variable -ValueOnly $VARIABLE_NAME
            } Else {
                $VARIABLE_VALUE = "EMPTY"
            }

            # The output name needs to be in lower case
            $OUTPUT_NAME = $VARIABLE_NAME.ToLower()

            Switch ( $VARIABLE_VALUE ) {

                "AUTO" {
                    Write-Log -LogLevel "Debug" -LogMessage "$VARIABLE_NAME auto-detection enabled"
                    Start-Detection -Name $VARIABLE_NAME
                }

                "TRUE" {
                    Write-Log -LogLevel "Debug" -LogMessage "$VARIABLE_NAME enabled"
                    Write-Output "::set-output name=$OUTPUT_NAME::TRUE"
                }

                "FALSE" {
                    Write-Log -LogLevel "Debug" -LogMessage "$VARIABLE_NAME disabled"
                    Write-Output "::set-output name=$OUTPUT_NAME::FALSE"
                }

                Default {
                    Write-Log -LogLevel "Debug" -LogMessage "$VARIABLE_NAME had unknown value of $VARIABLE_VALUE. Defaulting to FALSE"
                    Write-Output "::set-output name=$OUTPUT_NAME::FALSE"
                }

            }

        } Catch {

            Write-Log -LogLevel "Error" -LogMessage "Failed to process $VARIABLE_NAME"

        }

    }

}

#################################################
# End
#################################################

End {

    If ( ( $DieHard ) -And ( $ErrorCount -gt 0 ) ) {

        Write-Log -Throw -LogLevel "Error" -LogMessage "$ErrorCount errors during execution. Review the log file for details."

    }

    Write-Log -LogLevel "Information" -LogMessage "$ScriptName has completed"
    Exit $LASTEXITCODE

}
