# MonitorInventory.ps1 - PART 1

$ErrorActionPreference = "Stop"

Write-Host "=== Loading Display and Monitor Inventory Engine ==="
Write-Host "Compiling C# core components..."

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32;

public struct POINTL { public int x; public int y; }

public static class DisplayCore
{
    /* ------------------------------
       BASIC STRUCTS
       ------------------------------ */

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID { public uint LowPart; public int HighPart; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_RATIONAL { public uint Numerator; public uint Denominator; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_2DREGION { public uint cx; public uint cy; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_VIDEO_SIGNAL_INFO {
        public ulong pixelRate;
        public DISPLAYCONFIG_RATIONAL hSyncFreq;
        public DISPLAYCONFIG_RATIONAL vSyncFreq;
        public DISPLAYCONFIG_2DREGION activeSize;
        public DISPLAYCONFIG_2DREGION totalSize;
        public uint videoStandard;
        public uint scanLineOrdering;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_TARGET_MODE {
        public DISPLAYCONFIG_VIDEO_SIGNAL_INFO targetVideoSignalInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_SOURCE_MODE {
        public uint width;
        public uint height;
        public uint pixelFormat;
        public POINTL position;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_SOURCE_INFO {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public uint statusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_TARGET_INFO {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public uint outputTechnology;
        public uint rotation;
        public uint scaling;
        public DISPLAYCONFIG_RATIONAL refreshRate;
        public uint scanLineOrdering;
        public bool targetAvailable;
        public uint statusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_PATH_INFO {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_MODE_INFO {
        public uint infoType;
        public uint id;
        public LUID adapterId;
        public MODE_UNION modeInfo;

        [StructLayout(LayoutKind.Explicit)]
        public struct MODE_UNION {
            [FieldOffset(0)] public DISPLAYCONFIG_TARGET_MODE targetMode;
            [FieldOffset(0)] public DISPLAYCONFIG_SOURCE_MODE sourceMode;
        }
    }

    /* ------------------------------
       DEVMODE AND DISPLAY_DEVICE
       ------------------------------ */

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public POINTL dmPosition;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    /* ------------------------------
       EDID PARSER
       ------------------------------ */

    public class EdidInfo
    {
        public string VendorId = "Unknown";
        public string ProductId = "Unknown";
        public string Serial = "Unknown";
        public string Model = "Unknown";
        public int WidthMm = 0;
        public int HeightMm = 0;
        public double DiagonalInches = 0.0;
        public int ManufactureWeek = 0;
        public int ManufactureYear = 0;
        public string RegistryPath = "";
    }

    public static EdidInfo ReadEdid(string regPath)
    {
        try
        {
            RegistryKey key = Registry.LocalMachine.OpenSubKey(regPath);
            if (key == null) return null;

            byte[] edid = (byte[])key.GetValue("EDID", null);
            if (edid == null || edid.Length < 128) return null;

            EdidInfo info = new EdidInfo();
            info.RegistryPath = regPath;

            info.VendorId = "" + (char)(((edid[8] & 0x7C) / 4) + 64)
                                 + (char)(((edid[8] & 0x03) * 32) + ((edid[9] & 0xE0) / 32) + 64)
                                 + (char)((edid[9] & 0x1F) + 64);

            info.ProductId = ((edid[11] << 8) + edid[10]).ToString("X4");
            info.ManufactureWeek = edid[16];
            info.ManufactureYear = edid[17] + 1990;

            info.WidthMm = edid[21];
            info.HeightMm = edid[22];

            if (info.WidthMm > 0 && info.HeightMm > 0)
            {
                double w = info.WidthMm / 25.4;
                double h = info.HeightMm / 25.4;
                info.DiagonalInches = Math.Sqrt(w * w + h * h);
            }

            return info;
        }
        catch
        {
            return null;
        }
    }
/* ------------------------------
       DISPLAYCONFIG DLL IMPORTS
       ------------------------------ */

    [DllImport("user32.dll")]
    public static extern int GetDisplayConfigBufferSizes(
        uint flags,
        out uint numPathArrayElements,
        out uint numModeInfoArrayElements
    );

    [DllImport("user32.dll")]
    public static extern int QueryDisplayConfig(
        uint flags,
        ref uint numPathArrayElements,
        [Out] DISPLAYCONFIG_PATH_INFO[] pathInfoArray,
        ref uint numModeInfoArrayElements,
        [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray,
        IntPtr currentTopologyId
    );

    [DllImport("user32.dll")]
    public static extern int SetDisplayConfig(
        uint numPathArrayElements,
        DISPLAYCONFIG_PATH_INFO[] pathArray,
        uint numModeInfoArrayElements,
        DISPLAYCONFIG_MODE_INFO[] modeInfoArray,
        uint flags
    );
}
"@

Write-Host "C# core components loaded."

# MonitorInventory.ps1 - PART 2
# WMI monitor collection (ASCII only)

Write-Host "Loading WMI monitor data..."

function Get-WmiMonitorData {
    $result = @()

    # Query monitor identification (model, serial)
    try {
        $idData = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction SilentlyContinue
    } catch { $idData = @() }

    # Query monitor basic parameters (physical size)
    try {
        $basicData = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
    } catch { $basicData = @() }

    foreach ($item in $idData) {

        $manufacturer = ""
        $productCode = ""
        $serial = ""
        $userFriendly = ""

        if ($item.ManufacturerName) {
            $manufacturer = ($item.ManufacturerName | ForEach-Object { [char]$_ }) -join ""
        }

        if ($item.ProductCodeID) {
            $productCode = ($item.ProductCodeID | ForEach-Object { [char]$_ }) -join ""
        }

        if ($item.SerialNumberID) {
            $serial = ($item.SerialNumberID | ForEach-Object { [char]$_ }) -join ""
        }

        if ($item.UserFriendlyName) {
            $userFriendly = ($item.UserFriendlyName | ForEach-Object { [char]$_ }) -join ""
        }

        # Match the basic display params
        $basic = $basicData | Where-Object { $_.InstanceName -eq $item.InstanceName }

        $widthMm  = if ($basic) { $basic.MaxHorizontalImageSize } else { 0 }
        $heightMm = if ($basic) { $basic.MaxVerticalImageSize } else { 0 }

        $diagonalInches = 0
        if ($widthMm -gt 0 -and $heightMm -gt 0) {
            $wIn = $widthMm / 25.4
            $hIn = $heightMm / 25.4
            $diagonalInches = [math]::Round([math]::Sqrt(($wIn * $wIn) + ($hIn * $hIn)), 2)
        }

        $result += [PSCustomObject]@{
            InstanceName      = $item.InstanceName
            Manufacturer      = $manufacturer
            ProductCode       = $productCode
            SerialNumber      = $serial
            ModelName         = $userFriendly
            WidthMm           = $widthMm
            HeightMm          = $heightMm
            DiagonalInches    = $diagonalInches
        }
    }

    return $result
}

$Global:WmiMonitorInfo = Get-WmiMonitorData

Write-Host "WMI monitor data loaded."

# MonitorInventory.ps1 - PART 3
# EDID registry scanner (ASCII only)

Write-Host "Scanning EDID registry entries..."

function Get-EdidRegistryData {

    $result = @()

    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"

    if (-not (Test-Path $basePath)) {
        Write-Host "EDID registry path not found."
        return @()
    }

    # Enumerate vendor-product folders, for example:
    #   DISPLAY\DEL40A1
    #   DISPLAY\GSM5B09
    #   DISPLAY\HWP31A2
    $vendors = Get-ChildItem $basePath -ErrorAction SilentlyContinue

    foreach ($vendorKey in $vendors) {

        # Subkeys are usually like:
        #   5&10A58EDF&0&UID4352
        $instances = Get-ChildItem $vendorKey.PSPath -ErrorAction SilentlyContinue

        foreach ($instKey in $instances) {

            # Inside each instance, EDID is under
            #   Device Parameters
            $devParams = Join-Path $instKey.PSPath "Device Parameters"

            if (Test-Path $devParams) {

                $edid = [DisplayCore]::ReadEdid($devParams)

                if ($edid -ne $null) {

                    $result += [PSCustomObject]@{
                        VendorFolder    = $vendorKey.PSChildName
                        InstanceFolder  = $instKey.PSChildName
                        RegistryPath    = $edid.RegistryPath
                        VendorId        = $edid.VendorId
                        ProductId       = $edid.ProductId
                        Serial          = $edid.Serial
                        ManufactureWeek = $edid.ManufactureWeek
                        ManufactureYear = $edid.ManufactureYear
                        WidthMm         = $edid.WidthMm
                        HeightMm        = $edid.HeightMm
                        DiagonalInches  = $edid.DiagonalInches
                    }
                }
            }
        }
    }

    return $result
}

$Global:EdidRegistryInfo = Get-EdidRegistryData

Write-Host "EDID registry scan complete. Entries found: $($Global:EdidRegistryInfo.Count)"

# MonitorInventory.ps1 - PART 4
# DisplayConfig enumeration (ASCII only)

Write-Host "Enumerating DisplayConfig data..."

function Get-DisplayConfigInfo {

    # Load buffer size
    $QDC_ONLY_ACTIVE_PATHS = 0x00000002

    $pathCount = 0
    $modeCount = 0

    $result = [DisplayCore]::GetDisplayConfigBufferSizes($QDC_ONLY_ACTIVE_PATHS,
        [ref]$pathCount,
        [ref]$modeCount)

    if ($result -ne 0 -or $pathCount -le 0 -or $modeCount -le 0) {
        Write-Host "Unable to allocate DisplayConfig buffers."
        return @()
    }

    $paths = New-Object DisplayCore+DISPLAYCONFIG_PATH_INFO[] $pathCount
    $modes = New-Object DisplayCore+DISPLAYCONFIG_MODE_INFO[] $modeCount

    $result = [DisplayCore]::QueryDisplayConfig($QDC_ONLY_ACTIVE_PATHS,
        [ref]$pathCount,
        $paths,
        [ref]$modeCount,
        $modes,
        [IntPtr]::Zero)

    if ($result -ne 0) {
        Write-Host "QueryDisplayConfig failed with error code $result"
        return @()
    }

    $output = @()

    foreach ($path in $paths) {

        # Source info
        $src = $path.sourceInfo
        $tgt = $path.targetInfo

        # Find matching mode entries
        $sourceMode = $modes | Where-Object {
            $_.infoType -eq 1 -and $_.id -eq $src.id -and $_.adapterId.LowPart -eq $src.adapterId.LowPart
        }

        $targetMode = $modes | Where-Object {
            $_.infoType -eq 2 -and $_.id -eq $tgt.id -and $_.adapterId.LowPart -eq $tgt.adapterId.LowPart
        }

        # Extract source (resolution + position)
        $srcWidth  = $sourceMode.modeInfo.sourceMode.width
        $srcHeight = $sourceMode.modeInfo.sourceMode.height
        $srcPosX   = $sourceMode.modeInfo.sourceMode.position.x
        $srcPosY   = $sourceMode.modeInfo.sourceMode.position.y

        # Extract refresh rate
        $refresh = 0
        if ($tgt.refreshRate.Denominator -ne 0) {
            $refresh = [Math]::Round($tgt.refreshRate.Numerator / $tgt.refreshRate.Denominator, 2)
        }

        # Decode connector type
        $connector = switch ($tgt.outputTechnology) {
            0x80000000 { "UNDEFINED" }
            0          { "Other" }
            1          { "VGA" }
            2          { "SVIDEO" }
            3          { "Composite Video" }
            4          { "Component Video" }
            5          { "DVI" }
            6          { "HDMI" }
            8          { "LVDS" }
            10         { "DisplayPort External" }
            11         { "DisplayPort Embedded" }
            Default    { "Unknown" }
        }

        # Construct output object
        $output += [PSCustomObject]@{
            SourceId        = $src.id
            TargetId        = $tgt.id
            AdapterIdLow    = $src.adapterId.LowPart
            AdapterIdHigh   = $src.adapterId.HighPart
            Resolution      = "$srcWidth x $srcHeight"
            Width           = $srcWidth
            Height          = $srcHeight
            PositionX       = $srcPosX
            PositionY       = $srcPosY
            RefreshRateHz   = $refresh
            Rotation        = $tgt.rotation
            Scaling         = $tgt.scaling
            Connector       = $connector
            TargetAvailable = $tgt.targetAvailable
            ModeIndexSource = $src.modeInfoIdx
            ModeIndexTarget = $tgt.modeInfoIdx
            RawSource       = $src
            RawTarget       = $tgt
        }
    }

    return $output
}

$Global:DisplayConfigInfo = Get-DisplayConfigInfo

Write-Host "DisplayConfig enumeration complete. Entries found: $($Global:DisplayConfigInfo.Count)"

# MonitorInventory.ps1 - PART 5 (NEW)
# Data fusion engine using full WMI EDID + physical size + max resolution

Write-Host "Fusing monitor data using WMI EDID + physical size + max supported modes..."

function Get-DiagonalInInches {
    param(
        [int]$WidthMM,
        [int]$HeightMM
    )
    $diagMM = [math]::Sqrt(($WidthMM * $WidthMM) + ($HeightMM * $HeightMM))
    return [math]::Round(($diagMM / 25.4), 1)
}

function Get-WmiMonitorFullData {

    $result = @()

    $monitors        = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction SilentlyContinue
    $monitorParams   = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
    $supportedModes  = Get-WmiObject -Namespace root\wmi -Class WmiMonitorListedSupportedSourceModes -ErrorAction SilentlyContinue

    foreach ($monitor in $monitors) {

        $manufacturer = ""
        $productCode  = ""
        $serial       = ""
        $model        = ""

        if ($monitor.ManufacturerName) {
            $manufacturer = ($monitor.ManufacturerName | ForEach-Object { [char]$_ }) -join ""
        }
        if ($monitor.ProductCodeID) {
            $productCode = ($monitor.ProductCodeID | ForEach-Object { $_.ToString("X2") }) -join ""
        }
        if ($monitor.SerialNumberID) {
            $serial = ($monitor.SerialNumberID | ForEach-Object { [char]$_ }) -join ""
        }
        if ($monitor.UserFriendlyName) {
            $model = ($monitor.UserFriendlyName | ForEach-Object { [char]$_ }) -join ""
        }

        $instance = $monitor.InstanceName
        $param = $monitorParams  | Where-Object { $_.InstanceName -eq $instance }
        $modes = $supportedModes | Where-Object { $_.InstanceName -eq $instance }

        $widthMM  = if ($param) { $param.MaxHorizontalImageSize } else { 0 }
        $heightMM = if ($param) { $param.MaxVerticalImageSize }   else { 0 }
        $diagInches = Get-DiagonalInInches -WidthMM $widthMM -HeightMM $heightMM

        $maxRes = $null
        if ($modes -and $modes.MonitorSourceModes) {
            $maxRes = $modes.MonitorSourceModes |
                Sort-Object -Property HorizontalActivePixels, VerticalActivePixels -Descending |
                Select-Object -First 1
        }

        $maxResolution = if ($maxRes) {
            "$($maxRes.HorizontalActivePixels)x$($maxRes.VerticalActivePixels)"
        } else {
            "Unavailable"
        }

        $result += [PSCustomObject]@{
            InstanceName       = $instance
            Manufacturer       = $manufacturer
            ProductCode        = $productCode
            SerialNumber       = $serial
            Model              = $model
            WidthMM            = $widthMM
            HeightMM           = $heightMM
            DiagonalInches     = $diagInches
            MaxResolution      = $maxResolution
        }
    }

    return $result
}

$Global:WmiEdidFull = Get-WmiMonitorFullData

Write-Host "WMI EDID full entries found: $($Global:WmiEdidFull.Count)"


# ---------------------------------------------------------
# FUSION WITH DISPLAYCONFIG MONITOR DATA
# ---------------------------------------------------------

function Join-MonitorData {

    $final = @()

    foreach ($item in $Global:DisplayConfigInfo) {

        $match = $null

        # Match based on resolution in model string OR by instance manufacturer code
        foreach ($e in $Global:WmiEdidFull) {
            if ($e.Model -like "*$($item.Width)*" -or $e.Model -like "*$($item.Height)*") {
                $match = $e
                break
            }
        }

        # Fallback match by InstanceName pattern
        if (-not $match) {
            foreach ($e in $Global:WmiEdidFull) {
                if ($e.InstanceName -match $item.TargetId) {
                    $match = $e
                    break
                }
            }
        }

        # Final fallback
        if (-not $match) {
            $match = $Global:WmiEdidFull | Select-Object -First 1
        }

        $final += [PSCustomObject]@{
            SourceId        = $item.SourceId
            TargetId        = $item.TargetId
            AdapterIdLow    = $item.AdapterIdLow
            Resolution      = $item.Resolution
            Width           = $item.Width
            Height          = $item.Height
            PositionX       = $item.PositionX
            PositionY       = $item.PositionY
            RefreshRateHz   = $item.RefreshRateHz
            Rotation        = $item.Rotation
            Scaling         = $item.Scaling
            Connector       = $item.Connector

            Manufacturer    = $match.Manufacturer
            Model           = $match.Model
            ProductCode     = $match.ProductCode
            SerialNumber    = $match.SerialNumber
            InstanceName    = $match.InstanceName
            PhysicalWidthMm = $match.WidthMM
            PhysicalHeightMm= $match.HeightMM
            DiagonalInches  = $match.DiagonalInches
            MaxResolution   = $match.MaxResolution

            RawDisplayConfig = $item
            RawWmiEdidFull   = $match
        }
    }

    return $final
}

$Global:MonitorInventory = Join-MonitorData

Write-Host "Data fusion complete. Monitors processed: $($Global:MonitorInventory.Count)"

# MonitorInventory.ps1 - PART 6 (UPDATED)
# Human-readable console report (ASCII only)

Write-Host ""
Write-Host "=== Monitor Inventory Report ==="
Write-Host ""

foreach ($mon in $Global:MonitorInventory) {

    Write-Host "-------------------------------------------"
    Write-Host "Monitor Source ID        : $($mon.SourceId)"
    Write-Host "Monitor Target ID        : $($mon.TargetId)"
    Write-Host "GPU Adapter LUID Low     : $($mon.AdapterIdLow)"
    Write-Host ""

    # DisplayConfig geometry info
    Write-Host "Current Resolution       : $($mon.Resolution)"
    Write-Host "Max Supported Resolution : $($mon.MaxResolution)"
    Write-Host "Position (X,Y)           : $($mon.PositionX), $($mon.PositionY)"
    Write-Host "Refresh Rate (Hz)        : $($mon.RefreshRateHz)"
    Write-Host "Rotation                 : $($mon.Rotation)"
    Write-Host "Scaling                  : $($mon.Scaling)"
    Write-Host "Connector Type           : $($mon.Connector)"
    Write-Host ""

    # WMI EDID information (primary)
    Write-Host "EDID Manufacturer        : $($mon.Manufacturer)"
    Write-Host "EDID Model               : $($mon.Model)"
    Write-Host "EDID Product Code        : $($mon.ProductCode)"
    Write-Host "EDID Serial Number       : $($mon.SerialNumber)"
    Write-Host "WMI Instance Name        : $($mon.InstanceName)"
    Write-Host ""

    # Physical values (optional)
    Write-Host "Physical Width (mm)      : $($mon.PhysicalWidthMm)"
    Write-Host "Physical Height (mm)     : $($mon.PhysicalHeightMm)"
    Write-Host ""

    Write-Host "-------------------------------------------"
    Write-Host ""
}

Write-Host "Monitor inventory report completed."
Write-Host ""

# MonitorInventory.ps1 - PART 7
# JSON and CSV export (ASCII only)

Write-Host "Preparing JSON and CSV exports..."

# Ensure output directory exists
$exportDir = Join-Path -Path $PSScriptRoot -ChildPath "MonitorReports"
if (-not (Test-Path $exportDir)) {
    New-Item -Path $exportDir -ItemType Directory | Out-Null
}

# JSON export
$jsonPath = Join-Path $exportDir "monitor-inventory.json"
try {
    $Global:MonitorInventory | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding ASCII
    Write-Host "JSON export completed: $jsonPath"
}
catch {
    Write-Host "JSON export failed: $($_.Exception.Message)"
}

# CSV export
$csvPath = Join-Path $exportDir "monitor-inventory.csv"
try {
    $Global:MonitorInventory | Export-Csv -Path $csvPath -Encoding ASCII -NoTypeInformation
    Write-Host "CSV export completed: $csvPath"
}
catch {
    Write-Host "CSV export failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "=== All tasks completed successfully ==="
Write-Host "Monitor inventory is ready in folder: $exportDir"
Write-Host ""

# MonitorInventory.ps1 - PART 8
# PnP monitor enumeration and fusion (ASCII only)

Write-Host "Scanning PnP monitor devices..."

function Get-PnpMonitorData {

    $result = @()

    # Retrieve all PnP devices whose PNPClass is "Monitor"
    $pnp = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPClass -eq "Monitor" }

    # Also pull signed driver metadata
    $drivers = Get-WmiObject Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceClass -eq "MONITOR" }

    foreach ($dev in $pnp) {

        $matchingDriver = $drivers | Where-Object { $_.DeviceID -eq $dev.DeviceID }

        # Extract DISPLAY\XXXX### identifier
        $hardwareId = ""
        if ($dev.HardwareID -and $dev.HardwareID.Count -gt 0) {
            $hardwareId = $dev.HardwareID | Where-Object { $_ -like "DISPLAY*" } | Select-Object -First 1
        }

        # Parse Vendor/Product from DISPLAY\VENPROD
        $vendor = "Unknown"
        $product = "Unknown"

        if ($hardwareId -match "^DISPLAY\\([A-Za-z0-9]{3})([A-Za-z0-9]{4})") {
            $vendor = $matches[1]
            $product = $matches[2]
        }

        # Extract model name
        $model = $dev.Name
        if (-not $model -and $matchingDriver) {
            $model = $matchingDriver.DeviceName
        }

        $result += [PSCustomObject]@{
            DeviceID        = $dev.DeviceID
            Name            = $dev.Name
            HardwareID      = $hardwareId
            VendorCode      = $vendor
            ProductCode     = $product
            Manufacturer    = $dev.Manufacturer
            DriverName      = if ($matchingDriver) { $matchingDriver.DeviceName } else { "Unknown" }
            DriverVersion   = if ($matchingDriver) { $matchingDriver.DriverVersion } else { "Unknown" }
        }
    }

    return $result
}

$Global:PnpMonitorInfo = Get-PnpMonitorData

Write-Host "PnP monitor device scan complete. Entries found: $($Global:PnpMonitorInfo.Count)"


# ---------------------------------------------------------
# FUSION OF PNP DATA INTO FINAL MONITOR INVENTORY
# ---------------------------------------------------------
Write-Host "Merging PnP data with existing monitor inventory..."

foreach ($mon in $Global:MonitorInventory) {

    # Match PnP data by vendor/product codes
    $match = $Global:PnpMonitorInfo | Where-Object {
        ($_.VendorCode -eq $mon.EdidVendorId) -or
        ($_.ProductCode -eq $mon.EdidProductId) -or
        ($_.Name -like "*$($mon.Width)x$($mon.Height)*")
    } | Select-Object -First 1

    if (-not $match) {
        # Try alternative matching: resolution-based inference
        $match = $Global:PnpMonitorInfo | Where-Object {
            $_.Name -like "*$($mon.Width)*" -and $_.Name -like "*$($mon.Height)*"
        } | Select-Object -First 1
    }

    if ($match) {
        # Inject PnP metadata
        $mon | Add-Member -NotePropertyName PnpDeviceID      -NotePropertyValue $match.DeviceID
        $mon | Add-Member -NotePropertyName PnpName          -NotePropertyValue $match.Name
        $mon | Add-Member -NotePropertyName PnpManufacturer  -NotePropertyValue $match.Manufacturer
        $mon | Add-Member -NotePropertyName PnpDriverName    -NotePropertyValue $match.DriverName
        $mon | Add-Member -NotePropertyName PnpDriverVersion -NotePropertyValue $match.DriverVersion
        $mon | Add-Member -NotePropertyName PnpVendorCode    -NotePropertyValue $match.VendorCode
        $mon | Add-Member -NotePropertyName PnpProductCode   -NotePropertyValue $match.ProductCode
    }
    else {
        # Fallback fields
        $mon | Add-Member -NotePropertyName PnpDeviceID      -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpName          -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpManufacturer  -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpDriverName    -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpDriverVersion -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpVendorCode    -NotePropertyValue "Unknown"
        $mon | Add-Member -NotePropertyName PnpProductCode   -NotePropertyValue "Unknown"
    }
}

Write-Host "PnP fusion completed."

Read-Host "Press ENTER to exit"
