Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Création de la fenêtre principale (agrandie)
$form = New-Object System.Windows.Forms.Form
$form.Text = "Outil de maintenance système crée par Zourit77 (https://github.com/zourit77)"
$form.Size = New-Object System.Drawing.Size(1100,720)
$form.StartPosition = "CenterScreen"

# Ajout du champ pour l'ordinateur distant
$remoteComputerLabel = New-Object System.Windows.Forms.Label
$remoteComputerLabel.Location = New-Object System.Drawing.Point(10,10)
$remoteComputerLabel.Size = New-Object System.Drawing.Size(250,20)
$remoteComputerLabel.Text = "Ordinateur distant (vide pour local) :"
$form.Controls.Add($remoteComputerLabel)

$remoteComputerTextBox = New-Object System.Windows.Forms.TextBox
$remoteComputerTextBox.Location = New-Object System.Drawing.Point(270,10)
$remoteComputerTextBox.Size = New-Object System.Drawing.Size(300,20)
$form.Controls.Add($remoteComputerTextBox)

# Bouton Ping
$pingButton = New-Object System.Windows.Forms.Button
$pingButton.Location = New-Object System.Drawing.Point(580,10)
$pingButton.Size = New-Object System.Drawing.Size(75,23)
$pingButton.Text = "Ping"
$form.Controls.Add($pingButton)

# Message d'état pour la connectivité
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10,40)
$statusLabel.Size = New-Object System.Drawing.Size(600,20)
$statusLabel.ForeColor = [System.Drawing.Color]::Red
$form.Controls.Add($statusLabel)

# Fonction pour créer une case à cocher
function New-CheckBox {
    param($text, $y)
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Location = New-Object System.Drawing.Point(10,$y)
    $checkBox.Size = New-Object System.Drawing.Size(600,24)
    $checkBox.Text = $text
    $checkBox.Enabled = $false  # Désactivé par défaut
    $form.Controls.Add($checkBox)
    return $checkBox
}

# Création des cases à cocher (y compris la maintenance spool complète + Bureau à distance)
$checkBoxes = @(
    New-CheckBox "Arrêter et désactiver le service 'Windows Network Data Usage Monitoring'" 70
    New-CheckBox "Arrêter et désactiver le service 'SysMain'" 100
    New-CheckBox "Mettre en oeuvre la préconisation McAfee" 130
    New-CheckBox "Nettoyer le cache du Branchcache" 160
    New-CheckBox "Supprimer les fichiers temporaires" 190
    New-CheckBox "Désactiver les applications d'accès en arrière-plan" 220
    New-CheckBox "Exécuter DISM" 250
    New-CheckBox "Exécuter SFC" 280
    New-CheckBox "Vider les fichiers temporaires de tous les utilisateurs" 310
    New-CheckBox "Purger les GPO orphelins" 340
    New-CheckBox "Exécuter gpupdate" 370
    New-CheckBox "Exécuter gpupdate /force" 400
    New-CheckBox "Redémarrer le système après les opérations" 430
    New-CheckBox "Désactiver la mise en veille de l'ordinateur" 460
    New-CheckBox "Maintenance complète du spool (Désactiver+Supprimer+Réactiver)" 490
    New-CheckBox "Activer le Bureau à distance (RDP)" 520
)

# Création du bouton d'exécution
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(10,600)
$button.Size = New-Object System.Drawing.Size(100,30)
$button.Text = "Exécuter"
$button.Enabled = $false # Désactivé par défaut au départ.
$form.Controls.Add($button)

# Création de la zone de texte pour l'affichage des tâches (à droite, agrandie)
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(650,70)
$outputBox.Size = New-Object System.Drawing.Size(420,550)
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$form.Controls.Add($outputBox)

# Création de la barre de progression (agrandie)
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,650)
$progressBar.Size = New-Object System.Drawing.Size(1060,23)
$form.Controls.Add($progressBar)

# Fonction pour vérifier la connectivité via un ping
function Test-Ping {
    param($computerName)
    if ([string]::IsNullOrWhiteSpace($computerName)) {
        return $true # Considérer la machine locale comme toujours en ligne.
    }
    try {
        Test-Connection -ComputerName $computerName -Count 1 -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Fonction pour activer/désactiver les éléments en fonction du ping.
function Update-ControlState {
    param($isOnline)
    if ($isOnline) {
        foreach ($checkBox in $checkBoxes) {
            $checkBox.Enabled = $true # Activer les cases si en ligne.
        }
        $button.Enabled = $true # Activer le bouton Exécuter.
        $statusLabel.Text = "Ordinateur en ligne."
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        foreach ($checkBox in $checkBoxes) {
            $checkBox.Enabled = $false # Désactiver les cases si hors ligne.
        }
        $button.Enabled = $false # Désactiver le bouton Exécuter.
        $statusLabel.Text = "Ordinateur hors ligne. Veuillez vérifier la connectivité."
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# Action du bouton Ping.
$pingButton.Add_Click({
    Update-ControlState -isOnline:(Test-Ping -computerName $remoteComputerTextBox.Text)
})

# Fonction pour mettre à jour la zone de texte (affichage des tâches).
function Update-OutputBox {
    param($message)
    $outputBox.AppendText("$message`r`n")
}

# Fonction pour exécuter une commande sur un ordinateur distant ou local.
function Invoke-RemoteCommand {
    param (
        [string]$ComputerName,
        [scriptblock]$ScriptBlock
    )
    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        & $ScriptBlock
    } else {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock
    }
}

# Action du bouton Exécuter.
$button.Add_Click({
    $outputBox.Clear()
    $progressBar.Value = 0

    # Compter les tâches sélectionnées.
    $totalTasks = ($checkBoxes | Where-Object { $_.Checked }).Count 
    if ($totalTasks -eq 0) {
        Update-OutputBox "Aucune tâche sélectionnée."
        return 
    }

    # Exécution des tâches cochées.
    $completedTasks = 0

    foreach ($checkBox in $checkBoxes) {
        if ($checkBox.Checked) {
            $taskName = $checkBox.Text
            Update-OutputBox "Exécution de la tâche : $taskName"
            
            switch ($taskName) {
                "Exécuter DISM" {
                    Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                        DISM /Online /Cleanup-Image /RestoreHealth
                    } | ForEach { Update-OutputBox $_ }
                }
                "Exécuter SFC" {
                    Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                        sfc /scannow 
                    } | ForEach { Update-OutputBox $_ }
                }
                "Exécuter gpupdate" {
                    Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                        gpupdate 
                    } | ForEach { Update-OutputBox $_ }
                }
                "Exécuter gpupdate /force" {
                    Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                        gpupdate /force 
                    } | ForEach { Update-OutputBox $_ }
                }
                "Désactiver la mise en veille de l'ordinateur" {
                    Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                        powercfg /change standby-timeout-ac 0; powercfg /change standby-timeout-dc 0 
                    }
                    Update-OutputBox "Mise en veille désactivée avec succès."
                }
                "Maintenance complète du spool (Désactiver+Supprimer+Réactiver)" {
                    try {
                        # 1. Désactivation du service Spooler
                        Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                            Stop-Service -Name Spooler -Force
                            Set-Service -Name Spooler -StartupType Disabled
                        }
                        Update-OutputBox "Service Spooler désactivé."

                        # 2. Suppression des fichiers dans spool\PRINTERS
                        $targetPC = $remoteComputerTextBox.Text
                        $folderPath = if ([string]::IsNullOrWhiteSpace($targetPC)) {
                            "$env:SystemRoot\System32\spool\PRINTERS\*"
                        } else {
                            "\\$targetPC\c$\Windows\System32\spool\PRINTERS\*"
                        }
                        try {
                            Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
                            Update-OutputBox "Fichiers supprimés dans $folderPath."
                        } catch {
                            Update-OutputBox "Erreur lors de la suppression : $_"
                        }

                        # 3. Réactivation du service Spooler
                        Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                            Set-Service -Name Spooler -StartupType Automatic
                            Start-Service -Name Spooler
                        }
                        Update-OutputBox "Service Spooler réactivé."
                    } catch {
                        Update-OutputBox "Erreur lors de la maintenance du spool : $_"
                    }
                }
                "Activer le Bureau à distance (RDP)" {
                    try {
                        # 1. Active le RDP via le registre
                        Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
                        }
                        Update-OutputBox "Bureau à distance activé dans le registre."

                        # 2. Active la règle de pare-feu selon la langue du système ou crée une règle personnalisée
                        Invoke-RemoteCommand -ComputerName $remoteComputerTextBox.Text -ScriptBlock {
                            $frGroup = "Bureau à distance"
                            $enGroup = "Remote Desktop"
                            $rules = Get-NetFirewallRule -DisplayGroup $frGroup -ErrorAction SilentlyContinue
                            if (-not $rules) {
                                $rules = Get-NetFirewallRule -DisplayGroup $enGroup -ErrorAction SilentlyContinue
                            }
                            if ($rules) {
                                Enable-NetFirewallRule -DisplayGroup $frGroup -ErrorAction SilentlyContinue
                                Enable-NetFirewallRule -DisplayGroup $enGroup -ErrorAction SilentlyContinue
                            } else {
                                New-NetFirewallRule -DisplayName "AllowRDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow
                            }
                        }
                        Update-OutputBox "Pare-feu configuré pour le Bureau à distance."
                    } catch {
                        Update-OutputBox "Erreur lors de l'activation du Bureau à distance : $_"
                    }
                }
                "Redémarrer le système après les opérations" {
                    try {
                        if ([string]::IsNullOrWhiteSpace($remoteComputerTextBox.Text)) {
                            Restart-Computer -Force
                        } else {
                            Restart-Computer -ComputerName $remoteComputerTextBox.Text -Force
                        }
                        Update-OutputBox "Commande de redémarrage envoyée."
                    } catch {
                        Update-OutputBox "Erreur lors du redémarrage : $_"
                    }
                }
                default {
                    Start-Sleep -Seconds 1
                }
            }

            Update-OutputBox "Tâche terminée : $taskName"
            $completedTasks++
            $progressBar.Value = [int](($completedTasks / $totalTasks) * 100)
        }
    }

    Update-OutputBox "Toutes les tâches sélectionnées ont été exécutées."
})

# Affichage de la fenêtre principale.
$form.ShowDialog()
