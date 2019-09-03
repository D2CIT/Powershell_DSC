
################################################################################
# ██████╗ ██████╗  ██████╗       ██╗████████╗
# ██╔══██╗╚════██╗██╔════╝       ██║╚══██╔══╝
# ██║  ██║ █████╔╝██      ║█████╗██║   ██║   
# ██║  ██║██╔═══╝ ██║     ╚════ ╝██║   ██║   
# ██████╔╝███████╗╚██████╗       ██║   ██║   
# ╚═════╝ ╚══════╝ ╚═════╝       ╚═╝   ╚═╝   
################################################################################
# Configure server as Domain Controller (PUSH)
# ------------------------------------------------------------------------------
#    Author  : Mark van de Waarsenburg (Netherlands)
#    Company : D2C-IT  - Dare to Change IT
#    Date    : 29-9-2018
#    Script  : .\00_DSC_CreateDomainController.ps1
#    Note    : First run .\00_DSC_Prepare_Host.ps1
#
################################################################################
<#
.Synopsis
   Create domaincontroller via DSC
.DESCRIPTION
   Create domaincontroller via DSC
.EXAMPLE
   Example of how to use this cmdlet
.Note
   Last Edit : 26-09-2018
#>
Param(

    [Parameter(Mandatory=$false)]                       
    [string]$ComputerName      = "labdc01" ,                         
    
    [Parameter(Mandatory=$false)]  
    [string]$IPAddress         = "192.168.16.140/24",  
    
    [Parameter(Mandatory=$false)]               
    [array]$DnsIpAddress       = @("192.168.16.140","192.168.16.2") , 
    
    [Parameter(Mandatory=$false)]
    [string]$GatewayAddress    = "192.168.16.2", 
    
    [Parameter(Mandatory=$false)]                   
    [string]$InterfaceAlias    = "Ethernet0",
    
    [Parameter(Mandatory=$false)]                  
    [string]$DomainName        = "d2cit.it" ,
    
    [Parameter(Mandatory=$false)]                     
    [string]$CertificateFile   = "C:\scripts\Powershell\Cert\DscPublicKey.cer" , 
    
    [Parameter(Mandatory=$false)]
    [string]$DomainUsername    = "d2cit\administrator",
    
    [Parameter(Mandatory=$false)]
    [string]$DomainDN          = "DC=d2cit,DC=it" , 
      
    [Parameter(Mandatory=$false)]
    [string]$scriptfolder      = "c:\Scripts", 
    
    [switch]$ForceCreateSelfSignedCertificate,
    [Switch]$Reboot
    
)

Begin{
  
    ##############################################################
    #  DSC CONFIG
    ##############################################################
    configuration BuildDomainController  {

        Import-DscResource -ModuleName xActiveDirectory, xComputerManagement, xNetworking, xDnsServer, PSDesiredStateConfiguration

        Node localhost
        {
            LocalConfigurationManager {
                ActionAfterReboot = 'ContinueConfiguration'
                ConfigurationMode = 'ApplyOnly'
                RebootNodeIfNeeded = $true
            }

            ###########################################################################
            # Set IPAdress , Local Admin Password and Hostname
            ###########################################################################  
            xIPAddress NewIPAddress {
                IPAddress = $node.IPAddress
                InterfaceAlias = $node.InterfaceAlias
                AddressFamily = 'IPV4'
            }
            xDefaultGatewayAddress NewIPGateway {
                Address = $node.GatewayAddress
                InterfaceAlias = $node.InterfaceAlias
                AddressFamily = 'IPV4'
                DependsOn = '[xIPAddress]NewIPAddress'
            }
            xDnsServerAddress PrimaryDNSClient {
                Address = $node.DnsAddress
                InterfaceAlias = $node.InterfaceAlias
                AddressFamily = 'IPV4'
                DependsOn = '[xDefaultGatewayAddress]NewIPGateway'
            }

            User Administrator {
                Ensure    = 'Present'
                UserName  = 'Administrator'
                Password  = $domainCred
                DependsOn = '[xDnsServerAddress]PrimaryDNSClient'
            }
            xComputer NewComputerName {
                Name = $node.ThisComputerName
                DependsOn = '[User]Administrator'
            }

            ###########################################################################
            # Install Windows features
            ###########################################################################  
            WindowsFeature ADDSInstall {
                Ensure = 'Present'
                Name = 'AD-Domain-Services'
                DependsOn = '[xComputer]NewComputerName'
            }

            ###########################################################################
            # Create First Domain
            ###########################################################################
            xADDomain FirstDC {
                DomainName = $node.DomainName
                DomainAdministratorCredential = $domainCred
                SafemodeAdministratorPassword = $domainCred
                DatabasePath = $node.DCDatabasePath
                LogPath = $node.DCLogPath
                SysvolPath = $node.SysvolPath 
                DependsOn = '[WindowsFeature]ADDSInstall'
            }

            ###########################################################################
            # Create default OU structure
            ###########################################################################
            xADOrganizationalUnit D2C {
                Name = "D2C"  
                Path = "$($node.DomainDN)"          
                Description = "Root OU D2C"
                ProtectedFromAccidentalDeletion = $True
                DependsOn = '[xADDomain]FirstDC'
            }

            xADOrganizationalUnit Servers {
                Path = "OU=D2C,$($node.DomainDN)"
                Name = "Servers"            
                Description = "Server OU"
                ProtectedFromAccidentalDeletion = $True
                DependsOn = '[xADOrganizationalUnit]D2C'
            }
            xADOrganizationalUnit computers {
                Path = "OU=D2C,$($node.DomainDN)"
                Name = "computers"            
                Description = "Computer OU"
                ProtectedFromAccidentalDeletion = $True
                DependsOn = '[xADOrganizationalUnit]D2C'
            }
            xADOrganizationalUnit Users {
                Path = "OU=D2C,$($node.DomainDN)"
                Name = "Users"            
                Description = "users OU"
                ProtectedFromAccidentalDeletion = $True
                DependsOn = '[xADOrganizationalUnit]D2C'
            }
            xADOrganizationalUnit groups {
                Path = "OU=D2C,$($node.DomainDN)"
                Name = "Groups"            
                Description = "Groups OU"
                ProtectedFromAccidentalDeletion = $True
                DependsOn = '[xADOrganizationalUnit]D2C'
            }
        
            ###########################################################################
            # Create Users and add to the correct OU's
            ###########################################################################
            xADUser Adminmw {
                DomainName = $node.DomainName
                Path = "ou=Users,ou=D2C,$($node.DomainDN)"
                UserName = 'Adminmw'
                GivenName = 'Matthew'
                Surname = 'Water'
                DisplayName = 'Matthew Water'
                Enabled = $true
                Password = $domaincred
                DomainAdministratorCredential = $domainCred
                PasswordNeverExpires = $true
                DependsOn = '[xADOrganizationalUnit]Users'
            }
            xADUser AdminJM {
                DomainName = $node.DomainName
                Path = "ou=Users,ou=D2C,$($node.DomainDN)"
                UserName = 'AdminJM'
                GivenName = 'John'
                Surname = 'Zoo'
                DisplayName = 'John Zoo'
                Enabled = $true
                Password = $domaincred
                DomainAdministratorCredential = $domainCred
                PasswordNeverExpires = $true
                DependsOn = '[xADOrganizationalUnit]Users'
            }
            xADUser AdminDH {
                DomainName = $node.DomainName
                Path = "ou=Users,ou=D2C,$($node.DomainDN)"
                UserName = 'AdminMH'
                GivenName = 'Donna'
                Surname = 'Ho'
                DisplayName = 'Donna Ho'
                Enabled = $true
                Password = $domaincred
                DomainAdministratorCredential = $domainCred
                PasswordNeverExpires = $true
                DependsOn = '[xADOrganizationalUnit]Users'
            }
            xADUser AdminMH {
                DomainName = $node.DomainName
                Path = "OU=Users,OU=D2C,$($node.DomainDN)"
                UserName = 'AdminMH'
                GivenName = 'Monica'
                Surname = 'Beverly'
                DisplayName = 'Monica Beverly'
                Enabled = $true
                Password = $domaincred
                DomainAdministratorCredential = $domainCred
                PasswordNeverExpires = $true
                DependsOn = '[xADOrganizationalUnit]Users'
            }
            ###########################################################################
            # Create and configure Groups
            ###########################################################################
            xADGroup IT {
                GroupName = 'IT'
                Path = "OU=Groups,OU=D2C,$($node.DomainDN)"
                Category = 'Security'
                GroupScope = 'Global'
                MembersToInclude = 'AdminMH', 'AdminJM', 'AdminMW', 'AdminDH'
                DependsOn = '[xADOrganizationalUnit]groups'
            }
            xADGroup DomainAdmins {
                GroupName = 'Domain Admins'
                Path = "CN=Users,$($node.DomainDN)"
                Category = 'Security'
                GroupScope = 'Global'
                MembersToInclude = 'AdminJM', 'AdminMW'
                DependsOn = '[xADDomain]FirstDC'
            }
            xADGroup EnterpriseAdmins {
                GroupName = 'Enterprise Admins'
                Path = "CN=Users,$($node.DomainDN)"
                Category = 'Security'
                GroupScope = 'Universal'
                MembersToInclude = 'AdminMW'
                DependsOn = '[xADDomain]FirstDC'
            }
            xADGroup SchemaAdmins {
                GroupName = 'Schema Admins'
                Path = "CN=Users,$($node.DomainDN)"
                Category = 'Security'
                GroupScope = 'Universal'
                MembersToInclude = 'AdminMW'
                DependsOn = '[xADDomain]FirstDC'
            }
            xDnsServerADZone addReverseADZone {
                Name = '16.168.192.in-addr.arpa'
                DynamicUpdate = 'Secure'
                ReplicationScope = 'Forest'
                Ensure = 'Present'
                DependsOn = '[xADDomain]FirstDC'
            }
        }#Node
    }#configuration
    Configuration lcmconfigSecure        {
        #parameters
        param(
            [string[]]$computername,
            $CertificateID
        )

        #Target Node
        Node $computername {
            LocalconfigurationManager {
                ConfigurationMode              = "applyAndAutocorrect"
                ConfigurationModeFrequencyMins = 15
                CertificateID                  = $CertificateID
                RefreshMode                    = "Push"
                rebootNodeIfNeeded             = $true
            }
        }
     } #End PushedConfig

    # CREATE LOCAL SELFSIGNEDCERTIFICATE    
    if( !(test-path "$scriptfolder\Powershell\Cert\DscPublickey.cer") -or $ForceCreateSelfSignedCertificate){
        $cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp `
                                            -DnsName "DSCEncryptionCert_$($env:computername)" `
                                            -FriendlyName "Server Authentication" `
                                            -HashAlgorithm SHA256 
        $cert | Export-Certificate -FilePath $CertificateFile -Force
    }
    

}

Process {   
    #Change Directory to store DSC MOF Files 
    If(!(test-path $scriptfolder\powershell\dsc)){}
        set-location $scriptfolder\powershell\dsc
    }

    #Import Certificate
    $ImpCert = Import-Certificate -filepath $CertificateFile -CertStoreLocation cert:\localmachine\my

    # Create MOF LCM With Hashed Password in MOF         
    lcmconfigSecure -CertificateID $ImpCert.Thumbprint


    # Set paramaters for Config    
    $ConfigDataSecure = @{
        AllNodes = @(
            @{
                Nodename                    = "localhost"
                ThisComputerName            = $ComputerName
                IPAddress                   = $IPAddress 
                DnsAddress                  = $DnsIpAddress
                GatewayAddress              = $GatewayAddress
                InterfaceAlias              = $InterfaceAlias
                DomainName                  = $DomainName
                DomainDN                    = $DomainDN
                DCDatabasePath              = "C:\NTDS"
                DCLogPath                   = "C:\NTDS"
                SysvolPath                  = "C:\Sysvol"
                PSDscAllowPlainTextPassword = $false
                PSDscAllowDomainUser        = $true
                CertificateFile             = $CertificateFile
                Thumbprint                  = $ImpCert.Thumbprint
            }
        )#AllNodes
    }#ConfigData

    # Set Password
    $domainCred = Get-Credential -UserName $DomainUsername -Message "Please enter a new password for Domain Administrator."

    # Build MOF File
    BuildDomainController -ConfigurationData $ConfigDataSecure
   
    # Set LCM Manager
    Set-DscLocalConfigurationManager -path lcmconfigSecure -verbose

    # Push Configuration
    Start-DscConfiguration -Wait -Force -Path .\BuildDomainController -Verbose
}

End{
    #Script Finished
}
