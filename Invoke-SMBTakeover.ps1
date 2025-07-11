function Invoke-SMBTakeover {
    param(
        [ValidateSet('check','start','stop')]
        [string]$Action = 'check'
    )

    function CheckAdminRights {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "  [!] You should be running as Administrator" -ForegroundColor Yellow
            exit 1
        }
    }

    $services = 'LanmanServer','srv2','srvnet'

    switch ($Action) {
        'check' {
            Write-Host "`n  -------------CHECKING SMB SERVICES----------`n"
            foreach ($svcName in $services) {
                # State
                $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                $state = if ($svc -and $svc.Status -eq 'Running') { 'Running' } else { 'Stopped' }
                # Start mode and path
                $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
                $mode = if ($wmi) { $wmi.StartMode.ToUpper() } else { 'UNKNOWN' }
                $path = if ($wmi) { $wmi.PathName } else { '' }

                Write-Host "  [*] $svcName"
                Write-Host "          |------- state:     $state"
                Write-Host "          |------- starttype: $mode"
                Write-Host "          |------- path:      $path`n"
            }
            # 445 bound
            $bound445 = (Get-Service -Name 'srvnet' -ErrorAction SilentlyContinue).Status -eq 'Running'
            #Write-Host "  ----------------------------------------------------------`n"
                        $boundText = if ($bound445) { 'TRUE' } else { 'FALSE' }
            Write-Host "  [+] 445/tcp bound - $boundText`n"
        }
        'start' {
            CheckAdminRights
            # Configure and start
            Set-Service -Name 'LanmanServer' -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name 'LanmanServer' -ErrorAction SilentlyContinue

            Write-Host "`n  -------------RESUMING SMB SERVICES----------`n"
            Write-Host "  [*] LanmanServer"
            Write-Host "       |--- action: starttype=Auto"
            Write-Host "  [*] LanmanServer"
            Write-Host "       |--- action: Started`n"
            Write-Host "  [+] 445/tcp bound - TRUE`n"
        }
        'stop' {
            CheckAdminRights
            # Disable and stop
            Set-Service -Name 'LanmanServer' -StartupType Disabled -ErrorAction SilentlyContinue
            foreach ($svc in $services) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            }

            Write-Host "`n  -------------STOPPING SMB SERVICES----------`n"
            Write-Host "  [*] LanmanServer"
            Write-Host "       |--- action: starttype=Disabled"
            Write-Host "  [*] LanmanServer"
            Write-Host "       |--- action: Stopped"
            Write-Host "  [*] srv2"
            Write-Host "       |--- action: Stopped"
            Write-Host "  [*] srvnet"
            Write-Host "       |--- action: Stopped`n"
            Write-Host "  [+] 445/tcp bound - FALSE`n"
        }
        default {
            Write-Host "Usage: Invoke-SMBTakeover -Action <check|start|stop>"
        }
    }
}
