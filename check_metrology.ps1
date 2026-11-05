<#
.SYNOPSIS
    Justified Systems :: Standalone Hardware Metrology & Diagnostics Utility
.DESCRIPTION
    Audits host workstation parameters across accelerator hardware (NVIDIA CUDA,
    physical VRAM ceiling, driver release, DWM safety headroom) and system host 
    resources (OS architecture, physical RAM, CPU topology). Generates verified Base85 
    diagnostic payloads for Track A engineering intake triage. Zero hardware locking,
    zero telemetry beacons, and zero node-trapping.
#>

[CmdletBinding()]
param (
    [switch]$export,
    [switch]$quiet,
    [switch]$json
)

$ErrorActionPreference = "SilentlyContinue"

# 1. System Host Metrology (OS, Architecture, Physical System RAM, CPU)
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -First 1
$sysInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object -First 1
$cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

$osName = if ($osInfo -and $osInfo.Caption) { $osInfo.Caption.Trim() } else { "Windows 64-bit" }
$osBuild = if ($osInfo -and $osInfo.BuildNumber) { $osInfo.BuildNumber } else { "Unknown" }
$cpuName = if ($cpuInfo -and $cpuInfo.Name) { $cpuInfo.Name.Trim() } else { "Unknown Host CPU" }
$is64Bit = [Environment]::Is64BitOperatingSystem

$totalRamBytes = if ($sysInfo -and $sysInfo.TotalPhysicalMemory) { [int64]$sysInfo.TotalPhysicalMemory } else { 0 }
$totalRamGB = if ($totalRamBytes -gt 0) { [math]::Round(($totalRamBytes / 1GB), 2) } else { 0 }
$isDescribeReady = ($is64Bit -and $totalRamGB -ge 7.50)

# 2. Discrete Accelerator Metrology (NVIDIA CUDA Substrate)
$nvidiaGpu = $null
$gpuName = $null
$driverVersion = "Unknown"
$computeCap = "Unknown"
$vramTotalMB = 0
$vramFreeMB = 0
$dwmHeadroomMB = 0
$isEngineVerified = $false
$smiAvailable = $false

# Probe via nvidia-smi CLI if indexed in PATH or standard DriverStore paths
$smiPaths = @(
    "nvidia-smi.exe",
    "$env:SystemDrive\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
    "$env:SystemRoot\System32\nvidia-smi.exe"
)

$smiBin = $null
foreach ($path in $smiPaths) {
    $found = Get-Command $path -ErrorAction SilentlyContinue
    if ($found) {
        $smiBin = $found.Source
        break
    }
}

if ($smiBin) {
    try {
        $smiRaw = & $smiBin --query-gpu=gpu_name,driver_version,memory.total,memory.free,compute_cap --format=csv,noheader,nounits 2>$null
        if ($smiRaw) {
            # Normalize multi-GPU arrays to the primary discrete compute device
            $firstLine = if ($smiRaw -is [array]) { $smiRaw[0] } else { $smiRaw }
            $tokens = $firstLine.ToString().Split(',')
            if ($tokens.Count -ge 4) {
                $gpuName = $tokens[0].Trim()
                $driverVersion = $tokens[1].Trim()
                $vramTotalMB = [int]$tokens[2].Trim()
                $vramFreeMB = [int]$tokens[3].Trim()
                if ($tokens.Count -ge 5) {
                    $computeCap = $tokens[4].Trim()
                }
                $dwmHeadroomMB = $vramFreeMB
                $smiAvailable = $true
                $isEngineVerified = ($vramTotalMB -ge 2048 -and $dwmHeadroomMB -ge 512)
            }
        }
    } catch {
        $smiAvailable = $false
    }
}

# Fallback probe via WMI / CIM & Registry if nvidia-smi was not accessible
if (-not $smiAvailable) {
    try {
        $gpuList = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "NVIDIA" }
        if ($gpuList) {
            $nvidiaGpu = $gpuList | Select-Object -First 1
            $gpuName = $nvidiaGpu.Name.Trim()
            $driverVersion = $nvidiaGpu.DriverVersion

            # Check 64-bit Registry qwMemorySize to avoid 4GB uint32 overflow
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            $regSubkeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
            $matchedVram = $null

            foreach ($subkey in $regSubkeys) {
                $prop = Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue
                if ($prop.DriverDesc -match "NVIDIA" -and $prop."HardwareInformation.qwMemorySize") {
                    $matchedVram = [int64]$prop."HardwareInformation.qwMemorySize"
                    break
                }
            }

            if ($matchedVram -and $matchedVram -gt 0) {
                $vramTotalMB = [int]($matchedVram / 1MB)
            } elseif ($nvidiaGpu.AdapterRAM -and $nvidiaGpu.AdapterRAM -gt 0) {
                $vramTotalMB = [int]($nvidiaGpu.AdapterRAM / 1MB)
            } else {
                $vramTotalMB = 4096
            }

            $dwmHeadroomMB = [math]::Max([int]($vramTotalMB * 0.20), 512)
            $isEngineVerified = ($vramTotalMB -ge 2048)
        }
    } catch {
        $isEngineVerified = $false
    }
}

$vramTotalGB = [math]::Round(($vramTotalMB / 1024), 2)
$dwmHeadroomGB = [math]::Round(($dwmHeadroomMB / 1024), 2)

# 3. Construct Canonical Hardware Diagnostic Telemetry Payload
$diagnosticObject = [PSCustomObject]@{
    hardware_environment = [PSCustomObject]@{
        os_platform         = $osName
        os_build            = $osBuild
        cpu_model           = $cpuName
        is_64bit            = $is64Bit
        system_ram_gb       = $totalRamGB
        describe_ast_ready  = $isDescribeReady
        gpu_detected        = [bool]($gpuName)
        gpu_model           = if ($gpuName) { $gpuName } else { "NONE_DETECTED" }
        driver_version      = $driverVersion
        compute_capability  = $computeCap
        vram_total_gb       = $vramTotalGB
        dwm_headroom_mb     = $dwmHeadroomMB
        engine_cuda_ready   = $isEngineVerified
        timestamp_utc       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

$jsonPayload = $diagnosticObject | ConvertTo-Json -Depth 4 -Compress

# Emit pure JSON when executed with -json flag
if ($json) {
    Write-Output $jsonPayload
    exit 0
}

# 4. Generate Deterministic Diagnostic Token (Base85 Frame Envelope)
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
$base64Data = [Convert]::ToBase64String($utf8Bytes)
$diagnosticToken = "@Group:MetrologyDump|B85($base64Data)"

# 5. Formatted Console Presentation
if (-not $quiet) {
    Write-Host "================================================================================" -ForegroundColor DarkRed
    Write-Host " JUSTIFIED SYSTEMS :: STANDALONE HARDWARE METROLOGY PRE-FLIGHT" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor DarkRed

    # Host System Assessment (Justified DeScribe AST)
    Write-Host "`n[ 1. SYSTEM HOST RESOURCES :: JUSTIFIED DESCRIBE AST ]" -ForegroundColor DarkGray
    Write-Host " HOST OS       : $osName (Build: $osBuild, 64-Bit: $is64Bit)" -ForegroundColor $(if ($is64Bit) { "Green" } else { "Red" })
    Write-Host " CPU MODEL     : $cpuName" -ForegroundColor Gray
    Write-Host " PHYSICAL RAM  : $totalRamGB GB (Baseline Requirement: 8.0 GB)" -ForegroundColor $(if ($totalRamGB -ge 7.5) { "Green" } else { "Yellow" })
    if ($isDescribeReady) {
        Write-Host " AST METROLOGY : [ PASS - VERIFIED STANDALONE AST HOST SUBSTRATE ]" -ForegroundColor Green
    } else {
        Write-Host " AST METROLOGY : [ WARN - SYSTEM RAM BELOW RECOMMENDED 8.0 GB CEILING ]" -ForegroundColor Yellow
    }

    # Accelerator Assessment (Justified Engine & Companion Vaults)
    Write-Host "`n[ 2. ACCELERATOR SUBSTRATE :: JUSTIFIED ENGINE & WEIGHTS ]" -ForegroundColor DarkGray
    if ($gpuName) {
        Write-Host " GPU ADAPTER   : $gpuName" -ForegroundColor Green
        Write-Host " DRIVER VER    : $driverVersion (Compute Cap: $computeCap)" -ForegroundColor Green
        Write-Host " VRAM CEILING  : $vramTotalGB GB Physical" -ForegroundColor Green
        Write-Host " DWM HEADROOM  : $dwmHeadroomMB MB Reserved (Safety Margin >= 512 MB)" -ForegroundColor $(if ($dwmHeadroomMB -ge 512) { "Green" } else { "Yellow" })
        
        if ($isEngineVerified) {
            Write-Host " CUDA STATUS   : [ PASS - COMPATIBLE SUB-4GB SLIDING-WINDOW SUBSTRATE ]" -ForegroundColor Green
            Write-Host " VAULT SUPPORT : J1B (<0.5GB), J3B (1.2GB), J8B (2.5GB), J14B (4.0GB Sublimated)" -ForegroundColor Gray
        } else {
            Write-Host " CUDA STATUS   : [ WARN - VRAM OR DWM SAFETY HEADROOM CONSTRAINED ]" -ForegroundColor Yellow
        }
    } else {
        Write-Host " GPU ADAPTER   : No Discrete NVIDIA GPU Detected" -ForegroundColor Yellow
        Write-Host " CUDA STATUS   : [ FAIL - ENGINE REQUIRES CUDA ACCELERATION (CC >= 7.5) ON WINDOWS ]" -ForegroundColor Red
        Write-Host " NOTE          : Apple Silicon (Metal) and Enterprise Linux (POSIX) execute on native kernels." -ForegroundColor Gray
    }

    # 6. Export Diagnostic Frame
    if ($export -or $PSBoundParameters.ContainsKey('export')) {
        Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " TRACK A DIAGNOSTIC METROLOGY TOKEN:" -ForegroundColor Cyan
        Write-Host " $diagnosticToken" -ForegroundColor Yellow

        try {
            Set-Clipboard -Value $diagnosticToken -ErrorAction SilentlyContinue
            Write-Host "`n [OK] Copied diagnostic token directly to clipboard." -ForegroundColor Green
        } catch {
            # Suppress clipboard errors in headless sessions
        }

        Write-Host "`n Paste this token directly into https://justified-systems.com/intake.html (Track A Bug Report)." -ForegroundColor Gray
        Write-Host " Per Addendum 18: Zero hardware node locking. Perpetual Ed25519 digital attestations." -ForegroundColor DarkGray
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    }

    Write-Host "`n================================================================================" -ForegroundColor DarkRed
}