
################################################################################
# ██████╗ ██████╗  ██████╗       ██╗████████╗
# ██╔══██╗╚════██╗██╔════╝       ██║╚══██╔══╝
# ██║  ██║ █████╔╝██      ║█████╗██║   ██║   
# ██║  ██║██╔═══╝ ██║     ╚════ ╝██║   ██║   
# ██████╔╝███████╗╚██████╗       ██║   ██║   
# ╚═════╝ ╚══════╝ ╚═════╝       ╚═╝   ╚═╝   
################################################################################
# Prepare Host for DSC
# ------------------------------------------------------------------------------
#    Author  : Mark van de Waarsenburg (Netherlands)
#    Company : D2C-IT  - Dare to Change IT
#    Date    : 29-9-2018
#    Script  : .\00_DSC_Prepare_Host.ps1
#
################################################################################

<#
.Synopsis
   Prepare Server For DSC Config and start DSC
.DESCRIPTION
   Long description
.EXAMPLE
   Prepare and rename Host
   .\00_DSC_Prepare_Host.ps1 -newname LABDC01
#>


Param(
    #Param 1 : default
    [Parameter(Mandatory=$false)]  
    [String]$scriptfolder = "c:\Scripts"  , 
    
    #Param 2 : only use when tyou want to rename your host. Host wil reboot automaticly
    [Parameter(Mandatory=$false)]      
    [String]$NewName ,  
     #Param 3 :  If you als want install devoptools lile Git,Visualcode etc. 
    [Parameter(Mandatory=$false)]  
    [switch]$IncludeDevOPTools 
)

Begin{

    Function prep-DSCforHost       {

        Param($scriptfolder)
 
        # CREATE LOCAL SCRIPT FOLDER      
            If(!(test-path $scriptfolder)){mkdir $scriptfolder | out-null}
            If(!(test-path $scriptfolder\Powershell)){mkdir $scriptfolder\Powershell | out-null}
            If(!(test-path $scriptfolder\Powershell\Cert)){mkdir $scriptfolder\Powershell\Cert | out-null ;  Write-host "[Note] : create Folder $scriptfolder with Sub directory's"  -for Green}
            If(!(test-path $scriptfolder\Powershell\DSC)){mkdir $scriptfolder\Powershell\DSC  | out-null ;  Write-host "[Note] : create Folder $scriptfolder with Sub directory's"  -for Green}
            cd $scriptfolder

        # SETUP PACKAGE PROVIDER
            If( get-PackageProvider | where {$_.name -like "nuget"}){
                Write-host "[Note] : PackageProvider Nuget is installed"  -for Green
            }Else{
                Write-host "[Note] : Could not find PackageProvider Nuget and will be installed"  -for Yellow
                # Setup packageSource
                Get-PackageSource -name PSGallery | set-PackageSource -trusted -Force -ForceBootstrap | out-null
                Install-PackageProvider -name NuGet -force -Confirm:$false| out-null
            }#EndIF

        # ENABLE PSREMOTING 
            #write-host "[Note] : enable PSremoting " -for Yellow
            #enable-psremoting -Force
            #wsman quickconfig

        # IMPORT DSC RESOURCES
            write-host "[Note] : Install Powershell Modules for DSC" -for Yellow
            $modules = @("xComputerManagement","xNetworking","xDnsServer","xActiveDirectory","xPSDesiredStateConfiguration","cFileShare","xWinRM","xTimeZone","xWinEventLog" )
            Foreach($Module in $modules){
                write-host "         - Module $module " -for Yellow
                Install-Module -Name $Module 
            }
      
    } #End Function

}

Process{
    # PREPARE HOST FOR DSC
    prep-DSCforHost -scriptfolder $scriptfolder

    # INSTALL DEVOPS TOOLING
    If($IncludeDevOPTools){
        #setup Scripting Apps for Powershell/GIT
        If(!(Test-Path -Path "$env:ProgramData\Chocolatey")){
            Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            choco upgrade chocolatey
            choco feature enable -n allowGlobalConfirmation
        }

        $Packages = 'win32-openssh', 'git', 'notepadplusplus', 'poshgit', 'visualstudiocode'

        ForEach ($PackageName in $Packages){
                write-host "[note] : Install $packagename" -for Yellow
                $x = choco install $PackageName -y 
                write-host "         - $($x[4])" -for Green
        }#EndForeach  
            
    }#EndIF

    # Rename Host
    If($NewName){
        if(!($env:computername -eq $newName)){
            Write-host "[note] : rename host from $($env:computername) to $NewName"
            rename-computer -newname $NewName -Restart
        }
    }#EndIF

}
