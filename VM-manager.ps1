
 #######################################################################,
#                                                                       #
#                                                                       #
#        Automatisation de la mise à niveau des outils VMware           #
#                                                                       #
#           au démarrage, de la compatibilité des machines              #
#                                                                       #
#           virtuelles et de la suppression des snapshots               #
#                                                                       #
#                                                                       #
 #######################################################################'                                                                                     HANAMI Abdel-had

 # Author : HANAMI Abdel-had
 # Date : 2020
 # From : Mayotte, FRANCE (Overseas Region)
 # contact : hanami.abdel.had@gmail.com
 # LinkedIn : https://www.linkedin.com/in/abdel-had-hanami/



Write-Host -ForegroundColor Yellow "Bonjour !

"

#Test et/ou installation du module VMWare pour Powershell

if (Get-Module -ListAvailable -Name VMware.PowerCLI) {
    Write-Host -ForegroundColor Green "Le module VMware.PowerCLI est déjà installé.
    
    "
} else {
    Write-Host -ForegroundColor Red "Un instant , j'installe le module : VMware.PowerCLI
    
    "

    Find-Module -Name VMware.PowerCLI
    Install-Module -Name VMware.PowerCLI -Scope CurrentUser
    # Refuser la participation et ignorer les certificats invalides pour tous les utilisateurs
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore -Confirm:$false

    Write-Host -ForegroundColor Green "C'est prêt !

"
}



# Liste des commandes disponibles dans le module
#Get-Command -Module *VMWare*

 
# Connexion au vCenter Server en saisissant les credentials une fois demandés
Write-Host -ForegroundColor Yellow "Vous allez maintenant vous connecter au pcc-X-XXX-XXX-XX

ATTENTION ! Le script s'arrête en cas d'erreur !"

Sleep -Seconds 3
         
Connect-VIServer pcc-X-XXX-XXX-XX.ovh.com -ErrorAction Stop

$mylogs = "C:\temp\log.txt"

Write-Host -ForegroundColor Yellow "

    Le fichier de log : $($mylogs)

"

Pause

# Définition de la LISTE ROUGE - machines à ne pas toucher
$exeptions = @(`

"prod-vm-name" ,`
"dev-vm-name" ,`
"rec-vm-name"
)
# Liste des VM Off hors RedList
$VMTargeted = `
Get-VM | ? {($_.PowerState -eq "PoweredOff") -and ($_.Name -notin $exeptions)}

Write-Host "VM à ne pas affecter
$(Get-VM | ? {$_ -notin $VMTargeted})"



#--------------------LOGs-------------------#

#Je crée mon fichier de log. Et s'il en existe déjà un je le date et je l'archive avant.
if ((test-path $mylogs) -eq $false)
   {
       ni $mylogs -Force

   } else {
              
       mv $mylogs "$($mylogs)_avant_le_$(Get-Date -Format ddMMyyyy_hhmmss)"
       ni $mylogs -Force
   }

## Formatage du tableau - initialisation
function Add-Table{
    param( # HANAMI Abdel-had
        [string]$Machine,
        [string]$Etat,
        [string]$HardwareVersion,
        [string]$Snapshots,
        [string]$Etat_VM_Tools,
        [string]$ToolsUpgradePolicy

    )
    $Tableau = New-Object PSObject
    $Tableau | Add-Member -Name Machine -MemberType NoteProperty -Value $Machine
    $Tableau | Add-Member -Name Etat -MemberType NoteProperty -Value $Etat
    $Tableau | Add-Member -Name Version -MemberType NoteProperty -Value $HardwareVersion
    $Tableau | Add-Member -Name Snapshots -MemberType NoteProperty -Value $Snapshots
    $Tableau | Add-Member -Name Etat_VM_Tools -MemberType NoteProperty -Value $Etat_VM_Tools
    $Tableau | Add-Member -Name ToolsUpgradePolicy -MemberType NoteProperty -Value $ToolsUpgradePolicy
    return $Tableau
}


## Remlpissage du tableau
$Tableau=@()
foreach ($VM in $VMTargeted) {

    # Etat des VM Tools pour chaque VM
    $ToolStatus = get-view $VM.id | select @{Name=“ToolStatus”; Expression={$_.Guest.ToolsVersionStatus}}
    
    # Check déclancheur de mise à niveau des VM Tools
    $ToolsUpgradePolicy = $VM | Get-View | select @{N='ToolsUpgradePolicy';E={$_.Config.Tools.ToolsUpgradePolicy }}
    
    # Comptage du nombre de Snapshots
    $Snapshots = Get-VM $VM | Get-Snapshot

    # Création du tableau
    $Tableau += Add-Table -Machine $VM.Name -Etat $VM.PowerState -HardwareVersion $VM.HardwareVersion -Snapshots `
    $Snapshots.count -Etat_VM_Tools $ToolStatus.ToolStatus -ToolsUpgradePolicy $ToolsUpgradePolicy.ToolsUpgradePolicy 
}

# Ecriture de logs - j'annonce la prochaine action # Etats des VMs avant changement
Add-Content -Path $mylogs -Value "$(Get-Date)

Premier change : activation de la mise à jour des VM Ware Tools au démarrage.

$($Tableau | Format-Table | Out-String)"

Write-Host "Liste des VM à traiter 
$($VMTargeted)
"

# Activation de la mise à niveau automatique des outils VMware au démarrage

Write-Host "Activation de la mise à niveau automatique des outils VMware au démarrage 
"

try {  

$ManualUpdateVMs = $VMTargeted | Get-View | Where-Object {$_.Config.Tools.ToolsUpgradePolicy -like "manual"}|select name,@{N='ToolsUpgradePolicy';E={$_.Config.Tools.ToolsUpgradePolicy } }
 
Foreach ($VM in ($ManualUpdateVMs)) {
$VMConfig = Get-View -VIObject $VM.Name
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
$VMConfig.ReconfigVM($vmConfigSpec)

}       
      
} 
catch { 
           
   #En cas d'erreur je n'affiche que le message, je log et j'arrête le script
   
   Write-Warning -Message "$($_.Exception.Message)"
   Add-Content -Path $mylogs -Value "$($_.Exception.Message)"
   Write-Host "
   Le script va s'arrêter. Au revoir !"
   Pause ; Exit
}

Add-Content -Path $mylogs -Value "$(Get-Date)

Second change : mise à niveau des versions de compatibilités vers le version 15.

$($Tableau | Format-Table | Out-String)"


# Mise à niveau des versions de compatibilités des machines virtuelles ciblées, HANAMI Abdel-had
Write-Host "Mise à niveau des versions de compatibilités
"

try {            
      
      
Foreach ($VM in ($VMTargeted)) { 
  $VMConfig = Get-View -VIObject $VM.Name
  $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
  $vmConfigSpec.ScheduledHardwareUpgradeInfo = New-Object -TypeName VMware.Vim.ScheduledHardwareUpgradeInfo
  $vmConfigSpec.ScheduledHardwareUpgradeInfo.UpgradePolicy = "always" 
  $vmConfigSpec.ScheduledHardwareUpgradeInfo.VersionKey = "vmx-15"
  $VMConfig.ReconfigVM($vmConfigSpec)
}
} 
catch {   
         
   Write-Warning -Message "$($_.Exception.Message)"
   Add-Content -Path $mylogs -Value "$($_.Exception.Message)"
   Write-Host "
   Le script va s'arrêter. Au revoir !"
   Pause ; Exit
}

Add-Content -Path $mylogs -Value "$(Get-Date)

Troisième change : suppression des snapshots

$($Tableau | Format-Table | Out-String)"


# Suppression des snapshots
Write-Host "Suppression des snapshots
"

try {            
    
    Foreach ($VM in ($VMTargeted)) {
    $VM | Get-Snapshot | Remove-Snapshot
      
    }

}
catch {   
         
   Write-Warning -Message "$($_.Exception.Message)"
   Add-Content -Path $mylogs -Value "$($_.Exception.Message)"
   Write-Host "
   Le script va s'arrêter. Au revoir !"
   Pause ; Exit

}

Add-Content -Path $mylogs -Value "$(Get-Date)

$($Tableau | Format-Table | Out-String)"

Write-Host -ForegroundColor Green "Terminé !"

Pause


