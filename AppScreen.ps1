# ScreenConfig-Final.ps1
$ErrorActionPreference = 'Stop'

# ========== CHARGEMENT DES ASSEMBLIES WPF ==========
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ========== INTÉGRATION DE DisplayApi ==========
$displayApiType = ([System.Management.Automation.PSTypeName]'DisplayApi').Type
If ($displayApiType -and -not $displayApiType.GetField('Version')) {
    # Un type déjà compilé ne peut pas être remplacé dans la même session PowerShell
    throw "Une ancienne version de DisplayApi est déjà chargée dans cette session PowerShell. Fermez-la puis relancez le script."
}
If (-not $displayApiType) {
    Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32;

public struct POINTL { public int x; public int y; }

public static class DisplayApi
{
    public const int Version = 2;

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
    public struct DISPLAYCONFIG_TARGET_MODE { public DISPLAYCONFIG_VIDEO_SIGNAL_INFO targetVideoSignalInfo; }

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

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_DEVICE_INFO_HEADER {
        public uint type;
        public uint size;
        public LUID adapterId;
        public uint id;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAYCONFIG_SOURCE_DEVICE_NAME {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string viewGdiDeviceName;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAYCONFIG_TARGET_DEVICE_NAME {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public uint flags;
        public uint outputTechnology;
        public ushort edidManufactureId;
        public ushort edidProductCodeId;
        public uint connectorInstance;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string monitorFriendlyDeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string monitorDevicePath;
    }

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

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [DllImport("user32.dll")]
    static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPathArrayElements, out uint numModeInfoArrayElements);

    [DllImport("user32.dll")]
    static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, [Out] DISPLAYCONFIG_PATH_INFO[] pathInfoArray,
                                         ref uint numModeInfoArrayElements, [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray, IntPtr currentTopologyId);

    [DllImport("user32.dll")]
    public static extern int SetDisplayConfig(uint numPathArrayElements, DISPLAYCONFIG_PATH_INFO[] pathArray,
                                              uint numModeInfoArrayElements, DISPLAYCONFIG_MODE_INFO[] modeInfoArray, uint flags);

    [DllImport("user32.dll")]
    static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_SOURCE_DEVICE_NAME requestPacket);

    [DllImport("user32.dll")]
    static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_DEVICE_NAME requestPacket);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool EnumDisplaySettingsEx(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode, int dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int ChangeDisplaySettingsEx(string lpszDeviceName, IntPtr lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool EnumDisplayDevices(string lpDevice, int iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, int dwFlags);

    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    const uint QDC_ONLY_ACTIVE_PATHS              = 0x00000002;
    const uint SDC_APPLY                          = 0x00000080;
    const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG    = 0x00000020;
    const uint SDC_NO_OPTIMIZATION                = 0x00000100;
    const uint SDC_SAVE_TO_DATABASE               = 0x00000200;
    const uint DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE = 1;
    const uint DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1;
    const uint DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2;

    const int ENUM_CURRENT_SETTINGS = -1;
    const int DM_POSITION           = 0x00000020;
    const int CDS_UPDATEREGISTRY    = 0x00000001;
    const int CDS_NORESET           = 0x10000000;
    const int CDS_SET_PRIMARY       = 0x00000010;
    const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x00000001;

    const uint SWP_NOZORDER   = 0x0004;
    const uint SWP_NOACTIVATE = 0x0010;

    private static int lastResult = 0;
    public static int LastResult { get { return lastResult; } }

    public class SourceInfo {
        public int IndexInModeArray;
        public uint Id;
        public int Width, Height;
        public int X, Y;
        public LUID Adapter;

        // Identifiant unique (carte graphique + source), stable entre deux appels
        public string Key = "";
        // Moniteur relié à la source
        public uint TargetId;
        public string GdiDeviceName = "";
        public string FriendlyName = "";
        public string DevicePath = "";
        public string PnpId = "";
        public EdidInfo Edid;

        // Windows place toujours l'écran principal à l'origine du bureau
        public bool IsPrimary { get { return X == 0 && Y == 0; } }
    }

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

    static string MakeKey(LUID adapter, uint id)
    {
        return adapter.HighPart.ToString("X8") + adapter.LowPart.ToString("X8") + ":" + id.ToString();
    }

    static bool SameAdapter(LUID a, LUID b)
    {
        return a.LowPart == b.LowPart && a.HighPart == b.HighPart;
    }

    static void FillMonitorInfo(SourceInfo info, DISPLAYCONFIG_PATH_INFO[] paths, uint pathCount)
    {
        try
        {
            var src = new DISPLAYCONFIG_SOURCE_DEVICE_NAME();
            src.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
            src.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME));
            src.header.adapterId = info.Adapter;
            src.header.id = info.Id;
            if (DisplayConfigGetDeviceInfo(ref src) == 0)
                info.GdiDeviceName = src.viewGdiDeviceName ?? "";

            for (int p = 0; p < pathCount && p < paths.Length; p++)
            {
                var si = paths[p].sourceInfo;
                if (si.id != info.Id || !SameAdapter(si.adapterId, info.Adapter)) continue;

                var ti = paths[p].targetInfo;
                info.TargetId = ti.id;

                var tgt = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
                tgt.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
                tgt.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
                tgt.header.adapterId = ti.adapterId;
                tgt.header.id = ti.id;
                if (DisplayConfigGetDeviceInfo(ref tgt) == 0)
                {
                    info.FriendlyName = (tgt.monitorFriendlyDeviceName ?? "").Trim();
                    info.DevicePath = tgt.monitorDevicePath ?? "";

                    // \\?\DISPLAY#DEL40A1#5&10a58edf&0&UID4352#{guid} -> Enum\DISPLAY\DEL40A1\5&10a58edf&0&UID4352
                    string[] parts = info.DevicePath.Split('#');
                    if (parts.Length >= 3)
                    {
                        info.PnpId = parts[1];
                        info.Edid = ReadEdid(@"SYSTEM\CurrentControlSet\Enum\DISPLAY\" + parts[1] + @"\" + parts[2] + @"\Device Parameters");
                    }
                }
                break;
            }
        }
        catch
        {
            // Informations facultatives : la géométrie reste exploitable
        }
    }

    public static List<SourceInfo> GetSources()
    {
        uint pathCount, modeCount;
        if (GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount) != 0) return null;
        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];
        if (QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero) != 0) return null;

        var list = new List<SourceInfo>();
        for (int i = 0; i < modes.Length; i++)
        {
            if (modes[i].infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE)
            {
                var sm = modes[i].modeInfo.sourceMode;
                var info = new SourceInfo();
                info.IndexInModeArray = i;
                info.Id = modes[i].id;
                info.Width = (int)sm.width;
                info.Height = (int)sm.height;
                info.X = sm.position.x;
                info.Y = sm.position.y;
                info.Adapter = modes[i].adapterId;
                info.Key = MakeKey(modes[i].adapterId, modes[i].id);
                FillMonitorInfo(info, paths, pathCount);
                list.Add(info);
            }
        }
        list.Sort((a, b) => {
            int c = a.Id.CompareTo(b.Id);
            if (c != 0) return c;
            c = a.Adapter.HighPart.CompareTo(b.Adapter.HighPart);
            if (c != 0) return c;
            return a.Adapter.LowPart.CompareTo(b.Adapter.LowPart);
        });
        return list;
    }

    static bool ApplyCore(Dictionary<UInt32, POINTL> positionsById, Dictionary<string, POINTL> positionsByKey)
    {
        uint pathCount, modeCount;
        if (GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount) != 0) { lastResult = -1; return false; }
        var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
        var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];
        if (QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero) != 0) { lastResult = -2; return false; }

        for (int i = 0; i < modes.Length; i++)
        {
            if (modes[i].infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE)
            {
                POINTL dest = new POINTL();
                bool found = false;
                if (positionsByKey != null)
                    found = positionsByKey.TryGetValue(MakeKey(modes[i].adapterId, modes[i].id), out dest);
                else if (positionsById != null)
                    found = positionsById.TryGetValue(modes[i].id, out dest);

                if (found)
                {
                    var sm = modes[i].modeInfo.sourceMode;
                    sm.position.x = dest.x;
                    sm.position.y = dest.y;
                    modes[i].modeInfo.sourceMode = sm;
                }
            }
        }

        int r = SetDisplayConfig(pathCount, paths, modeCount, modes,
                 SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_APPLY | SDC_NO_OPTIMIZATION | SDC_SAVE_TO_DATABASE);
        lastResult = r;
        return (r == 0);
    }

    public static bool ApplyPositions(Dictionary<UInt32, POINTL> positions)
    {
        return ApplyCore(positions, null);
    }

    // Même chose qu'ApplyPositions, mais sans ambiguïté quand plusieurs cartes graphiques ont des sources de même Id
    public static bool ApplyPositionsByKey(Dictionary<string, POINTL> positions)
    {
        return ApplyCore(null, positions);
    }

    public static bool TrySetPrimaryByPosition(int x, int y)
    {
        var devices = new List<string>();
        string target = null;
        for (int devNum = 0; ; devNum++)
        {
            DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevices(null, devNum, ref dd, 0))
                break;

            bool isDisplay = dd.DeviceName != null && dd.DeviceName.StartsWith(@"\\.\DISPLAY", StringComparison.OrdinalIgnoreCase);
            if (!isDisplay || (dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;

            DEVMODE dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (!EnumDisplaySettingsEx(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm, 0)) continue;

            devices.Add(dd.DeviceName);
            if (dm.dmPosition.x == x && dm.dmPosition.y == y)
                target = dd.DeviceName;
        }
        if (target == null) { lastResult = -3; return false; }

        // L'écran principal doit être en (0,0) : tous les écrans sont décalés de (-x, -y)
        foreach (string name in devices)
        {
            DEVMODE dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (!EnumDisplaySettingsEx(name, ENUM_CURRENT_SETTINGS, ref dm, 0)) continue;
            dm.dmPosition.x -= x;
            dm.dmPosition.y -= y;
            dm.dmFields = DM_POSITION;

            uint flags = (uint)(CDS_UPDATEREGISTRY | CDS_NORESET);
            if (name == target) flags |= (uint)CDS_SET_PRIMARY;
            int r1 = ChangeDisplaySettingsEx(name, ref dm, IntPtr.Zero, flags, IntPtr.Zero);
            if (r1 != 0) { lastResult = r1; return false; }
        }
        int r2 = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
        lastResult = r2;
        return (r2 == 0);
    }

    // Positionne une fenêtre en coordonnées écran du processus (même repère que System.Windows.Forms.Screen)
    public static bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height)
    {
        return SetWindowPos(hwnd, IntPtr.Zero, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    public static EdidInfo ReadEdid(string regPath)
    {
        try
        {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(regPath))
            {
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

                info.WidthMm = edid[21] * 10;
                info.HeightMm = edid[22] * 10;

                if (info.WidthMm > 0 && info.HeightMm > 0)
                {
                    double w = info.WidthMm / 25.4;
                    double h = info.HeightMm / 25.4;
                    info.DiagonalInches = Math.Sqrt(w * w + h * h);
                }

                // Descripteurs texte : 0xFC = nom du modèle, 0xFF = numéro de série
                for (int d = 54; d + 18 <= 126; d += 18)
                {
                    if (edid[d] != 0 || edid[d + 1] != 0 || edid[d + 2] != 0) continue;
                    byte tag = edid[d + 3];
                    if (tag != 0xFC && tag != 0xFF) continue;
                    string text = System.Text.Encoding.ASCII.GetString(edid, d + 5, 13);
                    int nl = text.IndexOf('\n');
                    if (nl >= 0) text = text.Substring(0, nl);
                    text = text.Trim();
                    if (text.Length == 0) continue;
                    if (tag == 0xFC) info.Model = text; else info.Serial = text;
                }

                return info;
            }
        }
        catch
        {
            return null;
        }
    }
}
"@
}

Function Wait-ExtendedDesktop {
    param(
        [int]$TimeoutSeconds = 10,
        [int]$MinScreens = 2
    )
    DisplaySwitch.exe /extend
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 500
        $sources = [DisplayApi]::GetSources()
    } while ((-not $sources -or $sources.Count -lt $MinScreens) -and (Get-Date) -lt $deadline)
    if (-not $sources -or $sources.Count -lt $MinScreens) {
        throw "Extended desktop not ready after ${TimeoutSeconds}s. Found $( if ($sources) { $sources.Count } else { 0 } ) source(s)."
    }
    return $sources
}

Function New-PointLDictionary {
    param([type]$KeyType = [System.UInt32])
    $pointType = [DisplayApi].Assembly.GetType('POINTL')
    if (-not $pointType) { throw "POINTL type not found." }
    $dictType = [System.Collections.Generic.Dictionary``2].MakeGenericType($KeyType, $pointType)
    return [Activator]::CreateInstance($dictType)
}

Function New-PointL {
    param([int]$X, [int]$Y)
    $pointType = [DisplayApi].Assembly.GetType('POINTL')
    $p = [Activator]::CreateInstance($pointType)
    $p.x = $X; $p.y = $Y
    return $p
}

# Renvoie les sources physiques affectées à chaque emplacement du layout (SourceMap[emplacement] = index de source)
Function Resolve-SlotSources {
    param(
        $Sources,
        [int[]]$SourceMap,
        [int]$SlotCount
    )

    if (-not $SourceMap -or $SourceMap.Count -lt $SlotCount) { throw "Invalid SourceMap: $SlotCount entries expected." }
    $seen = @{}
    $result = @()
    for ($i = 0; $i -lt $SlotCount; $i++) {
        $idx = $SourceMap[$i]
        if ($idx -lt 0 -or $idx -ge $Sources.Count) { throw "Screen $($idx + 1) not found ($($Sources.Count) screen(s) detected)." }
        if ($seen.ContainsKey($idx)) { throw "Screen $($idx + 1) is used twice in the layout." }
        $seen[$idx] = $true
        $result += $Sources[$idx]
    }
    return $result
}

# Place les écrans non prévus par le layout, puis décale tout pour mettre l'écran principal en (0,0)
Function Complete-LayoutPositions {
    param(
        $Positions,
        $Sources,
        [int]$PrimaryIndex
    )

    if ($PrimaryIndex -lt 0 -or $PrimaryIndex -ge $Sources.Count) { throw "Primary index $PrimaryIndex out of range." }

    # Écrans en trop (4e et suivants) : à la suite, collés au bord droit de la disposition
    foreach ($src in $Sources) {
        if ($Positions.Contains($src.Key)) { continue }
        $anchor = $null
        $right = [int]::MinValue
        foreach ($placed in $Sources) {
            if (-not $Positions.Contains($placed.Key)) { continue }
            $edge = $Positions[$placed.Key][0] + $placed.Width
            if ($edge -gt $right) { $right = $edge; $anchor = $placed }
        }
        $Positions[$src.Key] = @($right, $Positions[$anchor.Key][1])
    }

    # SetDisplayConfig fait de l'écran situé en (0,0) l'écran principal
    $origin = $Positions[$Sources[$PrimaryIndex].Key]
    $dx = $origin[0]; $dy = $origin[1]

    $result = New-PointLDictionary -KeyType ([string])
    foreach ($key in @($Positions.Keys)) {
        $p = $Positions[$key]
        $result.Add($key, (New-PointL -X ($p[0] - $dx) -Y ($p[1] - $dy)))
    }
    return $result
}

Function Apply-LayoutPositions {
    param(
        $Positions,
        $Sources,
        [int]$PrimaryIndex,
        [string]$LayoutName
    )

    $script:LastLayoutWarning = $null

    $final = Complete-LayoutPositions -Positions $Positions -Sources $Sources -PrimaryIndex $PrimaryIndex
    $ok = [DisplayApi]::ApplyPositionsByKey($final)
    if (-not $ok) {
        Write-Warning "SetDisplayConfig returned code: $([DisplayApi]::LastResult)"
        return $false
    }
    Write-Host "$LayoutName layout applied." -ForegroundColor Green

    $primary = $Sources[$PrimaryIndex]
    $current = [DisplayApi]::GetSources() | Where-Object { $_.Key -eq $primary.Key } | Select-Object -First 1
    if ($current -and -not $current.IsPrimary -and -not [DisplayApi]::TrySetPrimaryByPosition($current.X, $current.Y)) {
        $script:LastLayoutWarning = "Could not set primary display (code $([DisplayApi]::LastResult))."
        Write-Warning $script:LastLayoutWarning
    } else {
        Write-Host "Primary set to screen index $PrimaryIndex (ID $($primary.Id))." -ForegroundColor Green
    }

    return $true
}

Function Set-LayoutTShape {
    param(
        [int]$PrimaryIndex = 0,
        [int[]]$SourceMap = @(1, 2, 0)
    )

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }

    # Emplacements : 0 = haut gauche, 1 = haut droite, 2 = bas centré
    $slots = Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount 3
    $srcB = $slots[0]; $srcC = $slots[1]; $srcA = $slots[2]

    $topWidth = $srcB.Width + $srcC.Width
    [int]$xA = [Math]::Floor(($topWidth - $srcA.Width) / 2.0)
    [int]$yA = [Math]::Max($srcB.Height, $srcC.Height)

    $positions = [ordered]@{}
    $positions[$srcB.Key] = @(0, 0)
    $positions[$srcC.Key] = @($srcB.Width, 0)
    $positions[$srcA.Key] = @($xA, $yA)

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "T-shape"
}

Function Set-LayoutHorizontal {
    param(
        [int]$MinScreens = 3,
        [int]$PrimaryIndex = 2,
        [int[]]$SourceMap = @()
    )

    $sources = Wait-ExtendedDesktop -MinScreens $MinScreens
    if ($sources.Count -lt $MinScreens) { throw "Need at least $MinScreens screens, found $($sources.Count)." }

    # Ordre de gauche à droite : écrans du SourceMap, puis les autres dans l'ordre des Id
    $ordered = @()
    if ($SourceMap.Count -gt 0) {
        $ordered += Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount $SourceMap.Count
    }
    $usedKeys = @($ordered | ForEach-Object { $_.Key })
    foreach ($src in $sources) {
        if ($usedKeys -notcontains $src.Key) { $ordered += $src }
    }

    $positions = [ordered]@{}
    $xOffset = 0
    foreach ($src in $ordered) {
        $positions[$src.Key] = @($xOffset, 0)
        $xOffset += $src.Width
    }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Horizontal"
}

Function Set-LayoutLineOut {
    param(
        [int]$PrimaryIndex = 0,
        [int[]]$SourceMap = @(0, 1, 2)
    )

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }

    # Emplacements : 0 = gauche, 1 = centre, 2 = petit écran à droite aligné en bas
    $slots = Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount 3
    $srcA = $slots[0]; $srcB = $slots[1]; $srcC = $slots[2]

    $mainHeight = [Math]::Max($srcA.Height, $srcB.Height)
    [int]$yC = $mainHeight - $srcC.Height

    $positions = [ordered]@{}
    $positions[$srcA.Key] = @(0, 0)
    $positions[$srcB.Key] = @($srcA.Width, 0)
    $positions[$srcC.Key] = @(($srcA.Width + $srcB.Width), $yC)

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Line-out"
}

# ========== DONNÉES DES LAYOUTS ==========
# SourceMap[i] = index (dans [DisplayApi]::GetSources()) de l'écran placé dans l'emplacement i ; Screens[i].Id = SourceMap[i] + 1
$script:Layouts = @(
    @{
        Name      = "T-shape"
        LayoutKey = "T"
        Favorite  = $true
        SourceMap = @(1, 2, 0)
        Screens   = @(
            @{ Id = 2; X = 0;   Y = 0;   W = 140; H = 90; Primary = $false }
            @{ Id = 3; X = 140; Y = 0;   W = 140; H = 90; Primary = $false }
            @{ Id = 1; X = 70;  Y = 90;  W = 140; H = 90; Primary = $true  }
        )
    },
    @{
        Name      = "Full line"
        LayoutKey = "Horizontal"
        Favorite  = $false
        SourceMap = @(0, 1, 2)
        Screens   = @(
            @{ Id = 1; X = 0;   Y = 0; W = 120; H = 90; Primary = $false }
            @{ Id = 2; X = 120; Y = 0; W = 120; H = 90; Primary = $false }
            @{ Id = 3; X = 240; Y = 0; W = 120; H = 90; Primary = $true  }
        )
    },
    @{
        Name      = "Line-out"
        LayoutKey = "LineOut"
        Favorite  = $false
        SourceMap = @(0, 1, 2)
        Screens   = @(
            @{ Id = 1; X = 0;   Y = 0;  W = 140; H = 90; Primary = $true  }
            @{ Id = 2; X = 140; Y = 0;  W = 140; H = 90; Primary = $false }
            @{ Id = 3; X = 310; Y = 30; W = 80;  H = 60; Primary = $false }
        )
    }
)

# ========== PRÉFÉRENCES (favoris, échanges, écran principal) ==========
$script:SettingsPath = Join-Path $env:APPDATA "ScreenConfig\settings.json"

Function Save-Settings {
    Try {
        $saved = @(ForEach ($layout In $script:Layouts) {
            $primarySlot = -1
            For ($i = 0; $i -lt $layout.Screens.Count; $i++) {
                If ($layout.Screens[$i].Primary) { $primarySlot = $i; break }
            }
            @{
                LayoutKey   = $layout.LayoutKey
                Favorite    = [bool]$layout.Favorite
                SourceMap   = @($layout.SourceMap)
                PrimarySlot = $primarySlot
            }
        })
        $dir = Split-Path -Parent $script:SettingsPath
        If (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($script:SettingsPath, (@{ Layouts = $saved } | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
    }
    Catch {
        Write-Warning "Préférences non enregistrées : $($_.Exception.Message)"
    }
}

Function Import-Settings {
    If (-not (Test-Path -LiteralPath $script:SettingsPath)) { return }
    Try {
        $data = [System.IO.File]::ReadAllText($script:SettingsPath) | ConvertFrom-Json
        ForEach ($saved In @($data.Layouts)) {
            $layout = $script:Layouts | Where-Object { $_.LayoutKey -eq $saved.LayoutKey } | Select-Object -First 1
            If (-not $layout) { continue }

            $layout.Favorite = [bool]$saved.Favorite

            # Le SourceMap enregistré doit être une permutation de celui d'origine
            $count = $layout.SourceMap.Count
            $map = @($saved.SourceMap | ForEach-Object { [int]$_ })
            $expected = (@($layout.SourceMap | Sort-Object) -join ',')
            If ($map.Count -ne $count -or (@($map | Sort-Object) -join ',') -ne $expected) { continue }

            For ($i = 0; $i -lt $count; $i++) {
                $layout.SourceMap[$i] = $map[$i]
                $layout.Screens[$i].Id = $map[$i] + 1
            }
            $primarySlot = [int]$saved.PrimarySlot
            If ($primarySlot -ge 0 -and $primarySlot -lt $count) {
                For ($i = 0; $i -lt $count; $i++) { $layout.Screens[$i].Primary = ($i -eq $primarySlot) }
            }
        }
    }
    Catch {
        Write-Warning "Préférences ignorées : $($_.Exception.Message)"
    }
}

Import-Settings

# Index du layout sélectionné (par défaut : le premier favoris)
$script:SelectedLayoutIndex = 0
for ($i = 0; $i -lt $script:Layouts.Count; $i++) {
    if ($script:Layouts[$i].Favorite) {
        $script:SelectedLayoutIndex = $i
        break
    }
}
$script:ShowFavoritesOnly = $false
$script:SelectedSwapIndex = -1
$script:LastLayoutWarning = $null

# ========== ÉCRANS CONNECTÉS ==========
$script:Displays = @()

Function Update-DisplayInfo {
    Try { $list = [DisplayApi]::GetSources() } Catch { $list = $null }
    $script:Displays = @(If ($list) { $list })
}

# Nom + résolution de l'écran d'index $Index (même numérotation que les layouts : Id = index + 1)
Function Get-DisplayLabel {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "Non détecté" }
    $d = $script:Displays[$Index]
    $name = $d.FriendlyName
    If (-not $name -and $d.Edid -and $d.Edid.Model -ne "Unknown") { $name = $d.Edid.Model }
    If (-not $name -and $d.PnpId) { $name = $d.PnpId }
    If (-not $name) { $name = "Écran" }
    return "$name`n$($d.Width) × $($d.Height)"
}

Update-DisplayInfo

# ========== XAML DE L'INTERFACE ==========
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Configuration écran"
    Width="1050" Height="700"
    MinWidth="800" MinHeight="600"
    WindowStartupLocation="CenterScreen"
    Background="#1B1B2F">

    <Window.Resources>
        <Style x:Key="SectionTitle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#EEEEEE"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="16,12,16,8"/>
        </Style>
        <Style x:Key="BtnApply" TargetType="Button">
            <Setter Property="Background" Value="#E63946"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="24,10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Grid Grid.Row="0" Margin="16,8,16,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="Sélectionner votre configuration"
                       Style="{StaticResource SectionTitle}" Margin="0,8,0,4"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,8,8,0">
                <TextBlock Text="Favoris" Foreground="#CCCCCC" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
                <TextBlock x:Name="txtFavStar" Text="★" Foreground="#888888" FontSize="18" VerticalAlignment="Center" Cursor="Hand"/>
            </StackPanel>
        </Grid>

        <!-- Layout cards -->
        <StackPanel x:Name="pnlCards" Grid.Row="1" Orientation="Horizontal" Margin="8,0,8,8"/>

        <!-- Preview title -->
        <TextBlock x:Name="txtPreviewTitle" Grid.Row="2" Text="Ma configuration personnalisée"
                   Style="{StaticResource SectionTitle}"/>

        <!-- Preview canvas -->
        <Border Grid.Row="3" Background="#15151F" CornerRadius="8" Margin="16,0,16,8">
            <Canvas x:Name="cvPreview" ClipToBounds="True"/>
        </Border>

		<Grid Grid.Row="4" Margin="16,0,16,12">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="Auto"/>  <!-- Bouton Identifier -->
				<ColumnDefinition Width="Auto"/>  <!-- Bouton Appliquer -->
			</Grid.ColumnDefinitions>
			<TextBlock x:Name="txtStatus" Grid.Column="0" Foreground="#888888" FontSize="12"
					   VerticalAlignment="Center" Text="Prêt"/>
			<Button x:Name="btnIdentify" Grid.Column="1" Content="Identifier" Style="{StaticResource BtnApply}" Margin="0,0,8,0"/>
			<Button x:Name="btnApply" Grid.Column="2" Content="Appliquer" Style="{StaticResource BtnApply}"/>
		</Grid>
    </Grid>
</Window>
"@

# ========== CHARGEMENT DE LA FENÊTRE ==========
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Récupération des éléments XAML
$pnlCards        = $window.FindName("pnlCards")
$cvPreview       = $window.FindName("cvPreview")
$btnApply        = $window.FindName("btnApply")
$btnIdentify     = $window.FindName("btnIdentify")
$txtStatus       = $window.FindName("txtStatus")
$txtFavStar      = $window.FindName("txtFavStar")
$txtPreviewTitle = $window.FindName("txtPreviewTitle")

# ========== FONCTIONS D'AFFICHAGE ==========
Function Set-Status {
    param([string]$Text, [string]$Color)
    $txtStatus.Text = $Text
    $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

Function Swap-ScreenSlots {
    param([int]$IndexA, [int]$IndexB)
    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    $screens = $layout.Screens

    $tmpId = $screens[$IndexA].Id
    $screens[$IndexA].Id = $screens[$IndexB].Id
    $screens[$IndexB].Id = $tmpId

    $tmpPrimary = $screens[$IndexA].Primary
    $screens[$IndexA].Primary = $screens[$IndexB].Primary
    $screens[$IndexB].Primary = $tmpPrimary

    $tmpSrc = $layout.SourceMap[$IndexA]
    $layout.SourceMap[$IndexA] = $layout.SourceMap[$IndexB]
    $layout.SourceMap[$IndexB] = $tmpSrc
}

Function Draw-ScreenRect {
    param(
        $Canvas,
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [string]$Label,
        [bool]$Primary,
        [bool]$Mini,
        [int]$ScreenId = -1,
        [int]$ScreenIndex = -1,
        [string]$SubLabel = ""
    )

    $isSwapSelected = (-not $Mini -and $ScreenIndex -ge 0 -and $ScreenIndex -eq $script:SelectedSwapIndex)
    $fill = If ($Primary) { "#E63946" } Else { "#3A3A5C" }
    If ($isSwapSelected) {
        $stroke = "#FFD700"
    } ElseIf ($Primary) {
        $stroke = "#FF4D5A"
    } Else {
        $stroke = "#555577"
    }
    $fontSize = If ($Mini) { 10 } Else { 28 }

    $rect = [System.Windows.Shapes.Rectangle]::new()
    $rect.Width  = $W
    $rect.Height = $H
    $rect.Fill   = [System.Windows.Media.BrushConverter]::new().ConvertFromString($fill)
    $rect.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString($stroke)
    $rect.StrokeThickness = If ($Mini) { 1 } ElseIf ($isSwapSelected) { 3 } Else { 2 }
    $rect.RadiusX = 4
    $rect.RadiusY = 4

    If (-not $Mini -and $ScreenId -ge 0) {
        $rect.Cursor = [System.Windows.Input.Cursors]::Hand

        $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
        $mi = [System.Windows.Controls.MenuItem]::new()
        $mi.Header = "Mettre en principal"
        $mi.Tag = $ScreenId
        $mi.Add_Click({
            param($sender, $e)
            $clickedId = $sender.Tag
            $layout = $script:Layouts[$script:SelectedLayoutIndex]
            ForEach ($s In $layout.Screens) {
                $s.Primary = ($s.Id -eq $clickedId)
            }
            Save-Settings
            Update-Preview
            Build-Cards
        })
        $ctxMenu.Items.Add($mi) | Out-Null
        $rect.ContextMenu = $ctxMenu

        $rect.Tag = $ScreenIndex
        $rect.Add_MouseLeftButtonDown({
            param($sender, $e)
            $clickedIdx = $sender.Tag
            If ($script:SelectedSwapIndex -lt 0) {
                $script:SelectedSwapIndex = $clickedIdx
                $selId = $script:Layouts[$script:SelectedLayoutIndex].Screens[$clickedIdx].Id
                Set-Status ([string]::Format("Écran {0} sélectionné. Cliquez sur un autre écran pour échanger.", $selId)) "#FFD700"
                Update-Preview
            } ElseIf ($script:SelectedSwapIndex -eq $clickedIdx) {
                $script:SelectedSwapIndex = -1
                Set-Status "Prêt" "#888888"
                Update-Preview
            } Else {
                Swap-ScreenSlots -IndexA $script:SelectedSwapIndex -IndexB $clickedIdx
                $script:SelectedSwapIndex = -1
                Save-Settings
                Set-Status "Écrans échangés." "#4CAF50"
                Update-Preview
                Build-Cards
            }
        })
    }

    [System.Windows.Controls.Canvas]::SetLeft($rect, $X)
    [System.Windows.Controls.Canvas]::SetTop($rect, $Y)
    $Canvas.Children.Add($rect) | Out-Null

    $tb = [System.Windows.Controls.TextBlock]::new()
    $tb.Text = $Label
    $tb.Foreground = [System.Windows.Media.Brushes]::White
    $tb.FontSize = $fontSize
    $tb.FontWeight = [System.Windows.FontWeights]::SemiBold
    $tb.HorizontalAlignment = "Center"
    $tb.VerticalAlignment = "Center"
    $tb.IsHitTestVisible = $false

    # Nom et résolution de l'écran sous le numéro (aperçu principal uniquement)
    $content = $tb
    If (-not $Mini -and $SubLabel -and $H -ge 60) {
        $sub = [System.Windows.Controls.TextBlock]::new()
        $sub.Text = $SubLabel
        $sub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#DDDDDD")
        $sub.FontSize = 11
        $sub.TextAlignment = "Center"
        $sub.HorizontalAlignment = "Center"
        $sub.TextTrimming = "CharacterEllipsis"
        $sub.MaxWidth = [Math]::Max($W - 8, 0)

        $content = [System.Windows.Controls.StackPanel]::new()
        $content.IsHitTestVisible = $false
        $content.Children.Add($tb) | Out-Null
        $content.Children.Add($sub) | Out-Null
    }

    $content.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))
    $tbW = $content.DesiredSize.Width
    $tbH = $content.DesiredSize.Height

    [System.Windows.Controls.Canvas]::SetLeft($content, $X + ($W - $tbW) / 2)
    [System.Windows.Controls.Canvas]::SetTop($content, $Y + ($H - $tbH) / 2)
    $Canvas.Children.Add($content) | Out-Null
}

Function Draw-LayoutPreview {
    param(
        $Canvas,
        $Screens,
        [bool]$Mini = $false
    )

    $Canvas.Children.Clear()

    $minX = ($Screens | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
    $minY = ($Screens | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
    $maxX = ($Screens | ForEach-Object { $_.X + $_.W }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    $maxY = ($Screens | ForEach-Object { $_.Y + $_.H }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

    $rawW = $maxX - $minX
    $rawH = $maxY - $minY

    $cW = $Canvas.ActualWidth
    $cH = $Canvas.ActualHeight
    If ($cW -le 0) { $cW = 400 }
    If ($cH -le 0) { $cH = 250 }

    $padding = 20
    $availW = $cW - (2 * $padding)
    $availH = $cH - (2 * $padding)

    If ($rawW -gt 0 -and $rawH -gt 0) {
        $scale = [Math]::Min($availW / $rawW, $availH / $rawH)
    } Else {
        $scale = 1.0
    }

    $totalW = $rawW * $scale
    $totalH = $rawH * $scale

    $offsetX = ($cW - $totalW) / 2
    $offsetY = ($cH - $totalH) / 2

    For ($idx = 0; $idx -lt $Screens.Count; $idx++) {
        $s = $Screens[$idx]
        $sx = (($s.X - $minX) * $scale) + $offsetX
        $sy = (($s.Y - $minY) * $scale) + $offsetY
        $sw = $s.W * $scale
        $sh = $s.H * $scale
        $subLabel = If ($Mini) { "" } Else { Get-DisplayLabel -Index ($s.Id - 1) }
        Draw-ScreenRect -Canvas $Canvas -X $sx -Y $sy -W $sw -H $sh -Label "$($s.Id)" -Primary $s.Primary -Mini $Mini -ScreenId $s.Id -ScreenIndex $idx -SubLabel $subLabel
    }
}

Function Build-Cards {
    $pnlCards.Children.Clear()

    If ($script:ShowFavoritesOnly -and -not $script:Layouts[$script:SelectedLayoutIndex].Favorite) {
        For ($j = 0; $j -lt $script:Layouts.Count; $j++) {
            If ($script:Layouts[$j].Favorite) { $script:SelectedLayoutIndex = $j; break }
        }
    }

    For ($i = 0; $i -lt $script:Layouts.Count; $i++) {
        $layout = $script:Layouts[$i]
        If ($script:ShowFavoritesOnly -and -not $layout.Favorite) { continue }
        $idx = $i

        $isSelected = ($i -eq $script:SelectedLayoutIndex)

        $border = [System.Windows.Controls.Border]::new()
        $border.Width = 300
        $border.Height = 180
        $border.Margin = [System.Windows.Thickness]::new(8)
        $border.Padding = [System.Windows.Thickness]::new(8)
        $border.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $border.Cursor = [System.Windows.Input.Cursors]::Hand
        $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A3D")

        If ($isSelected) {
            $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E63946")
            $border.BorderThickness = [System.Windows.Thickness]::new(3)
        } Else {
            $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3A3A5C")
            $border.BorderThickness = [System.Windows.Thickness]::new(2)
        }

        $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
        $miFav = [System.Windows.Controls.MenuItem]::new()
        If ($layout.Favorite) {
            $miFav.Header = "Retirer des favoris"
        } Else {
            $miFav.Header = "Ajouter aux favoris"
        }
        $miFav.Tag = $idx
        $miFav.Add_Click({
            param($sender, $e)
            $layoutIdx = $sender.Tag
            $script:Layouts[$layoutIdx].Favorite = -not $script:Layouts[$layoutIdx].Favorite
            Save-Settings
            Build-Cards
            Update-Preview
        })
        $ctxMenu.Items.Add($miFav) | Out-Null
        $border.ContextMenu = $ctxMenu

        $stack = [System.Windows.Controls.StackPanel]::new()

        $miniCanvas = [System.Windows.Controls.Canvas]::new()
        $miniCanvas.Height = 120
        $miniCanvas.IsHitTestVisible = $false
        $stack.Children.Add($miniCanvas) | Out-Null

        $labelRow = [System.Windows.Controls.Grid]::new()
        $col1 = [System.Windows.Controls.ColumnDefinition]::new()
        $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = [System.Windows.Controls.ColumnDefinition]::new()
        $col2.Width = [System.Windows.GridLength]::Auto
        $labelRow.ColumnDefinitions.Add($col1)
        $labelRow.ColumnDefinitions.Add($col2)

        $lbl = [System.Windows.Controls.TextBlock]::new()
        $lbl.Text = $layout.Name
        $lbl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CCCCCC")
        $lbl.FontSize = 13
        $lbl.Margin = [System.Windows.Thickness]::new(4, 6, 0, 0)
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $labelRow.Children.Add($lbl) | Out-Null

        If ($layout.Favorite) {
            $star = [System.Windows.Controls.TextBlock]::new()
            $star.Text = "★"
            $star.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFD700")
            $star.FontSize = 16
            $star.VerticalAlignment = "Center"
            $star.Margin = [System.Windows.Thickness]::new(0, 4, 4, 0)
            [System.Windows.Controls.Grid]::SetColumn($star, 1)
            $labelRow.Children.Add($star) | Out-Null
        }

        $stack.Children.Add($labelRow) | Out-Null
        $border.Child = $stack

        $border.Tag = $idx
        $border.Add_MouseLeftButtonDown({
            param($sender, $e)
            $script:SelectedLayoutIndex = $sender.Tag
            $script:SelectedSwapIndex = -1
            Build-Cards
            Update-Preview
        })

        $pnlCards.Children.Add($border) | Out-Null
        $miniCanvas.Tag = $layout.Screens
        $miniCanvas.Add_Loaded({
            param($sender, $e)
            $screens = $sender.Tag
            Draw-LayoutPreview -Canvas $sender -Screens $screens -Mini $true
        })
    }
}

Function Update-Preview {
    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    $txtPreviewTitle.Text = "Ma configuration personnalisée - $($layout.Name)"
    Draw-LayoutPreview -Canvas $cvPreview -Screens $layout.Screens -Mini $false
}

Function Set-LayoutFromGui {
    $currentLayout = $script:Layouts[$script:SelectedLayoutIndex]

    Set-Status "Application en cours..." "#FFD700"

    # Trouver l'index de l'écran principal dans le layout
    $primaryScreenIdx = 0
    For ($i = 0; $i -lt $currentLayout.Screens.Count; $i++) {
        If ($currentLayout.Screens[$i].Primary) { $primaryScreenIdx = $i; break }
    }

    # Récupérer l'index dans SourceMap pour l'écran principal
    $primarySourceIdx = $currentLayout.SourceMap[$primaryScreenIdx]
    $sourceMap = [int[]]$currentLayout.SourceMap

    Try {
        switch ($currentLayout.LayoutKey) {
            "T" {
                $result = Set-LayoutTShape -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap
            }
            "Horizontal" {
                $result = Set-LayoutHorizontal -MinScreens 3 -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap
            }
            "LineOut" {
                $result = Set-LayoutLineOut -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap
            }
            default {
                throw "Layout non supporté : $($currentLayout.LayoutKey)"
            }
        }

        $applied = @($result)
        If ($applied.Count -eq 0 -or $applied[-1] -ne $true) {
            Set-Status "Échec de l'application de $($currentLayout.Name) (code $([DisplayApi]::LastResult))." "#E63946"
        } ElseIf ($script:LastLayoutWarning) {
            Set-Status "Configuration $($currentLayout.Name) appliquée, mais l'écran principal n'a pas pu être défini." "#FFA500"
        } Else {
            Set-Status "Configuration $($currentLayout.Name) appliquée." "#4CAF50"
        }
    }
    Catch {
        Set-Status "Erreur: $($_.Exception.Message)" "#E63946"
    }

    Update-DisplayInfo
    Update-Preview
}

# ========== FONCTION POUR IDENTIFIER LES ÉCRANS ==========
$script:IdentifyWindows = @()
$script:IdentifyTimer = $null
$script:IdentifySeconds = 4

Function Close-IdentifyOverlays {
    param([string]$Message)

    If ($script:IdentifyTimer) {
        $script:IdentifyTimer.Stop()
        $script:IdentifyTimer = $null
    }
    ForEach ($w In $script:IdentifyWindows) { $w.Close() }
    $script:IdentifyWindows = @()
    If ($Message) { Set-Status $Message "#4CAF50" }
}

Function Show-IdentifyOverlays {
    Close-IdentifyOverlays

    # Numérotation identique à l'aperçu : écran N = source N-1 de [DisplayApi]::GetSources()
    Update-DisplayInfo
    Update-Preview
    If ($script:Displays.Count -eq 0) {
        Set-Status "Aucun écran détecté." "#E63946"
        return
    }

    if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.Screen').Type) {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    }
    $formsScreens = @([System.Windows.Forms.Screen]::AllScreens)

    For ($i = 0; $i -lt $script:Displays.Count; $i++) {
        $d = $script:Displays[$i]

        # Rectangle de l'écran dans le repère du processus (tient compte de la mise à l'échelle Windows)
        $fs = $formsScreens | Where-Object { $_.DeviceName -eq $d.GdiDeviceName } | Select-Object -First 1
        If ($fs) {
            $bx = $fs.Bounds.X; $by = $fs.Bounds.Y; $bw = $fs.Bounds.Width; $bh = $fs.Bounds.Height
        } Else {
            $bx = $d.X; $by = $d.Y; $bw = $d.Width; $bh = $d.Height
        }

        $ovl = [System.Windows.Window]::new()
        $ovl.WindowStyle = [System.Windows.WindowStyle]::None
        $ovl.AllowsTransparency = $true
        $ovl.Background = [System.Windows.Media.Brushes]::Transparent
        $ovl.Topmost = $true
        $ovl.ShowInTaskbar = $false
        $ovl.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual

        $number = [System.Windows.Controls.TextBlock]::new()
        $number.Text = ($i + 1).ToString()
        $number.FontSize = [Math]::Max([Math]::Min($bh / 4, 200), 48)
        $number.Foreground = [System.Windows.Media.Brushes]::White
        $number.HorizontalAlignment = "Center"
        $number.FontWeight = [System.Windows.FontWeights]::Bold

        $name = [System.Windows.Controls.TextBlock]::new()
        $name.Text = Get-DisplayLabel -Index $i
        $name.FontSize = 22
        $name.Foreground = [System.Windows.Media.Brushes]::White
        $name.HorizontalAlignment = "Center"
        $name.TextAlignment = "Center"

        $panel = [System.Windows.Controls.StackPanel]::new()
        $panel.HorizontalAlignment = "Center"
        $panel.VerticalAlignment = "Center"
        $panel.Children.Add($number) | Out-Null
        $panel.Children.Add($name) | Out-Null

        $border = [System.Windows.Controls.Border]::new()
        $border.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(180, 0, 0, 0))
        $border.CornerRadius = [System.Windows.CornerRadius]::new(20)
        $border.Padding = [System.Windows.Thickness]::new(40)
        $border.Child = $panel

        $ovl.Content = $border

        # Fermer au clic
        $ovl.Add_MouseLeftButtonDown({
            Close-IdentifyOverlays -Message "Identification terminée"
        })

        # Placement en pixels sur l'écran visé, puis plein écran sur ce même écran
        $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($ovl).EnsureHandle()
        [DisplayApi]::MoveWindow($hwnd, $bx, $by, $bw, $bh) | Out-Null
        $ovl.Show()
        $ovl.WindowState = [System.Windows.WindowState]::Maximized

        $script:IdentifyWindows += $ovl
    }

    # Fermer après quelques secondes si non cliqué
    $script:IdentifyTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:IdentifyTimer.Interval = [System.TimeSpan]::FromSeconds($script:IdentifySeconds)
    $script:IdentifyTimer.Add_Tick({
        Close-IdentifyOverlays -Message "Identification terminée (timeout)"
    })
    $script:IdentifyTimer.Start()

    Set-Status "Cliquez sur un numéro ou attendez $($script:IdentifySeconds) secondes..." "#FFD700"
}

# ========== ÉVÉNEMENTS ==========
$btnApply.Add_Click({
    Set-LayoutFromGui
})

$btnIdentify.Add_Click({
    Show-IdentifyOverlays
})

$txtFavStar.Add_MouseLeftButtonDown({
    $script:ShowFavoritesOnly = -not $script:ShowFavoritesOnly
    If ($script:ShowFavoritesOnly) {
        $txtFavStar.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFD700")
    } Else {
        $txtFavStar.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    }
    Build-Cards
    Update-Preview
})

$window.Add_ContentRendered({
    Build-Cards
    Update-Preview
})

$cvPreview.Add_SizeChanged({
    Update-Preview
})

$window.Add_Closed({
    Close-IdentifyOverlays
})

# ========== AFFICHER LA FENÊTRE ==========
$window.ShowDialog() | Out-Null
