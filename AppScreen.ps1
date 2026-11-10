# ScreenConfig-Final.ps1
$ErrorActionPreference = 'Stop'

# ========== CHARGEMENT DES ASSEMBLIES WPF ==========
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ========== INTÉGRATION DE DisplayApi ==========
$displayApiType = ([System.Management.Automation.PSTypeName]'DisplayApi').Type
If ($displayApiType -and (-not $displayApiType.GetField('Version') -or $displayApiType.GetField('Version').GetValue($null) -lt 9)) {
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
    public const int Version = 9;

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

    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAYCONFIG_TARGET_PREFERRED_MODE {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public uint width;
        public uint height;
        public DISPLAYCONFIG_TARGET_MODE targetMode;
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

    [DllImport("user32.dll")]
    static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_PREFERRED_MODE requestPacket);

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

    [DllImport("user32.dll")]
    static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

    [DllImport("shell32.dll")]
    static extern int GetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] out string appId);

    // Identité propre dans la barre des tâches : la fenêtre n'est plus regroupée avec powershell.exe
    // et Windows affiche son icône à elle. À appeler avant d'ouvrir la fenêtre.
    public static bool SetAppId(string appId)
    {
        return SetCurrentProcessExplicitAppUserModelID(appId) == 0;
    }

    public static string GetAppId()
    {
        string appId;
        return GetCurrentProcessExplicitAppUserModelID(out appId) == 0 ? appId : null;
    }

    const uint QDC_ALL_PATHS                      = 0x00000001;
    const uint QDC_ONLY_ACTIVE_PATHS              = 0x00000002;
    const uint DISPLAYCONFIG_PATH_ACTIVE          = 0x00000001;
    const int  ERROR_INSUFFICIENT_BUFFER          = 122;
    const uint SDC_APPLY                          = 0x00000080;
    const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG    = 0x00000020;
    const uint SDC_NO_OPTIMIZATION                = 0x00000100;
    const uint SDC_SAVE_TO_DATABASE               = 0x00000200;
    const uint DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE = 1;
    const uint DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1;
    const uint DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2;
    const uint DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE = 3;

    const int ENUM_CURRENT_SETTINGS = -1;
    const int DM_POSITION           = 0x00000020;
    const int DM_BITSPERPEL         = 0x00040000;
    const int DM_PELSWIDTH          = 0x00080000;
    const int DM_PELSHEIGHT         = 0x00100000;
    const int DM_DISPLAYFREQUENCY   = 0x00400000;
    const int DM_INTERLACED         = 0x00000002;
    const int CDS_UPDATEREGISTRY    = 0x00000001;
    const int CDS_NORESET           = 0x10000000;
    const int CDS_SET_PRIMARY       = 0x00000010;
    const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x00000001;
    const int DISPLAY_DEVICE_PRIMARY_DEVICE      = 0x00000004;

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
        // Résolution native du moniteur (celle "recommandée" par Windows), 0 si inconnue
        public int PreferredWidth, PreferredHeight;
        // Type de connexion (DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY)
        public uint OutputTechnology;

        // Écran principal selon Windows (indicateur GDI) ; à défaut de nom GDI, celui placé à l'origine du bureau
        public bool IsPrimary;

        public bool IsInternal { get { return IsInternalTechnology(OutputTechnology); } }
    }

    // Moniteur branché, qu'il soit allumé ou non par Windows
    public class MonitorInfo {
        public string Key = "";
        public uint TargetId;
        public LUID Adapter;
        public uint OutputTechnology;
        public string FriendlyName = "";
        public string DevicePath = "";
        public string PnpId = "";
        public EdidInfo Edid;
        public int PreferredWidth, PreferredHeight;
        public bool IsActive;

        public bool IsInternal { get { return IsInternalTechnology(OutputTechnology); } }
    }

    // Dalle d'ordinateur portable : connexion interne, LVDS ou DisplayPort / UDI intégré
    public static bool IsInternalTechnology(uint outputTechnology)
    {
        return outputTechnology == 0x80000000 || outputTechnology == 6 || outputTechnology == 11 || outputTechnology == 13;
    }

    public class ResolutionChange {
        public string GdiDeviceName = "";
        public uint SourceId;
        public int OldWidth, OldHeight, OldFrequency;
        public int NewWidth, NewHeight, NewFrequency;
        public bool NeedsChange;
        public bool Changed;
        public int Result;
        public DEVMODE Mode;
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

    // Nom, chemin, EDID et résolution native du moniteur relié à une cible d'affichage
    static MonitorInfo ReadMonitor(DISPLAYCONFIG_PATH_TARGET_INFO ti)
    {
        var monitor = new MonitorInfo();
        monitor.Key = MakeKey(ti.adapterId, ti.id);
        monitor.TargetId = ti.id;
        monitor.Adapter = ti.adapterId;
        monitor.OutputTechnology = ti.outputTechnology;
        try
        {
            var pref = new DISPLAYCONFIG_TARGET_PREFERRED_MODE();
            pref.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE;
            pref.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_PREFERRED_MODE));
            pref.header.adapterId = ti.adapterId;
            pref.header.id = ti.id;
            if (DisplayConfigGetDeviceInfo(ref pref) == 0)
            {
                monitor.PreferredWidth = (int)pref.width;
                monitor.PreferredHeight = (int)pref.height;
            }

            var tgt = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
            tgt.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
            tgt.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
            tgt.header.adapterId = ti.adapterId;
            tgt.header.id = ti.id;
            if (DisplayConfigGetDeviceInfo(ref tgt) == 0)
            {
                monitor.FriendlyName = (tgt.monitorFriendlyDeviceName ?? "").Trim();
                monitor.DevicePath = tgt.monitorDevicePath ?? "";

                // \\?\DISPLAY#DEL40A1#5&10a58edf&0&UID4352#{guid} -> Enum\DISPLAY\DEL40A1\5&10a58edf&0&UID4352
                string[] parts = monitor.DevicePath.Split('#');
                if (parts.Length >= 3)
                {
                    monitor.PnpId = parts[1];
                    monitor.Edid = ReadEdid(@"SYSTEM\CurrentControlSet\Enum\DISPLAY\" + parts[1] + @"\" + parts[2] + @"\Device Parameters");
                }
            }
        }
        catch
        {
            // Informations facultatives
        }
        return monitor;
    }

    // Moniteurs branchés, allumés ou non (ex. dalle du portable coupée par "Deuxième écran uniquement")
    public static List<MonitorInfo> GetConnectedMonitors()
    {
        for (int attempt = 0; attempt < 3; attempt++)
        {
            uint pathCount, modeCount;
            if (GetDisplayConfigBufferSizes(QDC_ALL_PATHS, out pathCount, out modeCount) != 0) return null;
            var paths = new DISPLAYCONFIG_PATH_INFO[pathCount];
            var modes = new DISPLAYCONFIG_MODE_INFO[modeCount];
            int r = QueryDisplayConfig(QDC_ALL_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
            if (r == ERROR_INSUFFICIENT_BUFFER) continue; // la configuration a changé entre les deux appels
            if (r != 0) return null;

            // Un même moniteur apparaît dans plusieurs chemins (un par source possible) : dédoublonnage par cible
            var list = new List<MonitorInfo>();
            var seen = new Dictionary<string, MonitorInfo>();
            for (int p = 0; p < pathCount && p < paths.Length; p++)
            {
                var ti = paths[p].targetInfo;
                if (!ti.targetAvailable) continue;
                bool active = (paths[p].flags & DISPLAYCONFIG_PATH_ACTIVE) != 0;

                MonitorInfo existing;
                string key = MakeKey(ti.adapterId, ti.id);
                if (seen.TryGetValue(key, out existing))
                {
                    if (active) existing.IsActive = true;
                    continue;
                }
                var monitor = ReadMonitor(ti);
                monitor.IsActive = active;
                seen[key] = monitor;
                list.Add(monitor);
            }
            return list;
        }
        return null;
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
                var monitor = ReadMonitor(ti);
                info.TargetId = ti.id;
                info.OutputTechnology = ti.outputTechnology;
                info.PreferredWidth = monitor.PreferredWidth;
                info.PreferredHeight = monitor.PreferredHeight;
                info.FriendlyName = monitor.FriendlyName;
                info.DevicePath = monitor.DevicePath;
                info.PnpId = monitor.PnpId;
                info.Edid = monitor.Edid;
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
                info.IsPrimary = string.IsNullOrEmpty(info.GdiDeviceName)
                    ? (info.X == 0 && info.Y == 0)
                    : IsPrimaryDisplay(info.GdiDeviceName);
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

    // Passe le thread en mode "DPI par écran" : les API GDI d'affichage renvoient alors des coordonnées physiques,
    // sans la virtualisation appliquée quand les écrans n'ont pas la même mise à l'échelle (ex. portable 150 %, écran 100 %)
    static IntPtr EnterPhysicalCoordinates()
    {
        try
        {
            IntPtr old = SetThreadDpiAwarenessContext(new IntPtr(-4));            // PER_MONITOR_AWARE_V2
            if (old == IntPtr.Zero) old = SetThreadDpiAwarenessContext(new IntPtr(-3)); // PER_MONITOR_AWARE
            return old;
        }
        catch (EntryPointNotFoundException)
        {
            return IntPtr.Zero;
        }
    }

    static void LeavePhysicalCoordinates(IntPtr oldContext)
    {
        if (oldContext == IntPtr.Zero) return;
        try { SetThreadDpiAwarenessContext(oldContext); } catch (EntryPointNotFoundException) { }
    }

    // Écrans GDI rattachés au bureau (\\.\DISPLAYn) avec leur mode courant
    static void GetAttachedDisplays(List<string> names, List<DEVMODE> modes)
    {
        for (int devNum = 0; ; devNum++)
        {
            DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevices(null, devNum, ref dd, 0))
                break;

            bool isDisplay = dd.DeviceName != null && dd.DeviceName.StartsWith(@"\\.\DISPLAY", StringComparison.OrdinalIgnoreCase);
            if (!isDisplay || (dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;

            DEVMODE dm = NewDevMode();
            if (!EnumDisplaySettingsEx(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm, 0)) continue;

            names.Add(dd.DeviceName);
            modes.Add(dm);
        }
    }

    // Écran principal tel que Windows le considère réellement (indicateur GDI)
    public static bool IsPrimaryDisplay(string gdiDeviceName)
    {
        if (string.IsNullOrEmpty(gdiDeviceName)) return false;
        for (int devNum = 0; ; devNum++)
        {
            DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevices(null, devNum, ref dd, 0)) return false;
            if (string.Equals(dd.DeviceName, gdiDeviceName, StringComparison.OrdinalIgnoreCase))
                return (dd.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0;
        }
    }

    // Fait de l'écran \\.\DISPLAYn l'écran principal en gardant la disposition : il passe en (0,0), les autres sont décalés d'autant
    public static bool SetPrimaryDisplay(string gdiDeviceName)
    {
        if (IsPrimaryDisplay(gdiDeviceName)) { lastResult = 0; return true; }

        IntPtr oldContext = EnterPhysicalCoordinates();
        try
        {
            var names = new List<string>();
            var modes = new List<DEVMODE>();
            GetAttachedDisplays(names, modes);

            int target = names.FindIndex(n => string.Equals(n, gdiDeviceName, StringComparison.OrdinalIgnoreCase));
            if (target < 0) { lastResult = -3; return false; }

            int dx = modes[target].dmPosition.x;
            int dy = modes[target].dmPosition.y;

            // Le futur écran principal d'abord, puis les autres
            var order = new List<int>();
            order.Add(target);
            for (int i = 0; i < names.Count; i++) if (i != target) order.Add(i);

            foreach (int i in order)
            {
                DEVMODE dm = modes[i];
                dm.dmPosition.x -= dx;
                dm.dmPosition.y -= dy;
                dm.dmFields = DM_POSITION;

                uint flags = (uint)(CDS_UPDATEREGISTRY | CDS_NORESET);
                if (i == target) flags |= (uint)CDS_SET_PRIMARY;
                int r1 = ChangeDisplaySettingsEx(names[i], ref dm, IntPtr.Zero, flags, IntPtr.Zero);
                if (r1 != 0) { lastResult = r1; return false; }
            }
            int r2 = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
            lastResult = r2;
            return (r2 == 0) && IsPrimaryDisplay(gdiDeviceName);
        }
        finally
        {
            LeavePhysicalCoordinates(oldContext);
        }
    }

    public static bool TrySetPrimaryByPosition(int x, int y)
    {
        IntPtr oldContext = EnterPhysicalCoordinates();
        string target = null;
        try
        {
            var names = new List<string>();
            var modes = new List<DEVMODE>();
            GetAttachedDisplays(names, modes);
            for (int i = 0; i < names.Count; i++)
            {
                if (modes[i].dmPosition.x == x && modes[i].dmPosition.y == y) { target = names[i]; break; }
            }
        }
        finally
        {
            LeavePhysicalCoordinates(oldContext);
        }
        if (target == null) { lastResult = -3; return false; }
        return SetPrimaryDisplay(target);
    }

    /* ------------------------------
       ICÔNES DU BUREAU
       Explorer range les icônes à partir du coin haut-gauche de l'ensemble du bureau, et non de l'écran principal :
       quand l'écran principal n'est pas en haut à gauche, les icônes restent sur un autre écran.
       Elles sont replacées via les interfaces COM officielles du shell (IShellWindows -> IShellBrowser -> IFolderView).
       ------------------------------ */

    [ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
    interface IShellWindows
    {
        int Count { get; }
        [return: MarshalAs(UnmanagedType.IDispatch)] object Item([MarshalAs(UnmanagedType.Struct)] object index);
        [return: MarshalAs(UnmanagedType.IUnknown)] object _NewEnum();
        void Register([MarshalAs(UnmanagedType.IDispatch)] object pid, int hwnd, int swClass, out int plCookie);
        void RegisterPending(int lThreadId, [MarshalAs(UnmanagedType.Struct)] ref object pvarloc, [MarshalAs(UnmanagedType.Struct)] ref object pvarlocRoot, int swClass, out int plCookie);
        void Revoke(int lCookie);
        void OnNavigate(int lCookie, [MarshalAs(UnmanagedType.Struct)] ref object pvarLoc);
        void OnActivated(int lCookie, bool fActive);
        [return: MarshalAs(UnmanagedType.IDispatch)]
        object FindWindowSW([MarshalAs(UnmanagedType.Struct)] ref object pvarLoc, [MarshalAs(UnmanagedType.Struct)] ref object pvarLocRoot, int swClass, out int pHWND, int swfwOptions);
    }

    [ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IComServiceProvider
    {
        [PreserveSig]
        int QueryService(ref Guid guidService, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppvObject);
    }

    // Seules les méthodes utilisées sont appelées ; les autres réservent leur place dans la table virtuelle
    [ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellBrowser
    {
        void GetWindow(out IntPtr phwnd);
        void ContextSensitiveHelp(bool fEnterMode);
        void InsertMenusSB();
        void SetMenuSB();
        void RemoveMenusSB();
        void SetStatusTextSB();
        void EnableModelessSB();
        void TranslateAcceleratorSB();
        void BrowseObject();
        void GetViewStateStream();
        void GetControlWindow();
        void SendControlMsg();
        void QueryActiveShellView([MarshalAs(UnmanagedType.Interface)] out IShellView ppshv);
    }

    [ComImport, Guid("000214E3-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellView
    {
        void GetWindow(out IntPtr phwnd);
    }

    [ComImport, Guid("CDE725B0-CCC9-4519-917E-325D72FAB4CE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IFolderView
    {
        void GetCurrentViewMode(out uint pViewMode);
        void SetCurrentViewMode(uint viewMode);
        void GetFolder(ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
        void Item(int iItemIndex, out IntPtr ppidl);
        void ItemCount(uint uFlags, out int pcItems);
        void Items(uint uFlags, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
        void GetSelectionMarkedItem(out int piItem);
        void GetFocusedItem(out int piItem);
        void GetItemPosition(IntPtr pidl, out POINTL ppt);
        void GetSpacing(out POINTL ppt);
        void GetDefaultSpacing(out POINTL ppt);
        [PreserveSig] int GetAutoArrange();
        void SelectItem(int iItem, uint dwFlags);
        void SelectAndPositionItems(uint cidl, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl,
                                    [MarshalAs(UnmanagedType.LPArray)] POINTL[] apt, uint dwFlags);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string className, string windowName);

    [DllImport("user32.dll")]
    static extern bool ClientToScreen(IntPtr hWnd, ref POINTL point);

    [DllImport("user32.dll")]
    static extern bool SystemParametersInfo(uint action, uint uiParam, ref RECT pvParam, uint winIni);

    [DllImport("user32.dll")]
    static extern IntPtr MonitorFromPoint(POINTL pt, uint flags);

    [DllImport("user32.dll")]
    static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);

    const int  CSIDL_DESKTOP           = 0;
    const int  SWC_DESKTOP             = 8;
    const int  SWFO_NEEDDISPATCH       = 1;
    const uint SVGIO_ALLVIEW           = 2;
    const uint SVSI_POSITIONITEM       = 0x80;
    const uint SPI_GETWORKAREA         = 0x0030;
    const uint MONITOR_DEFAULTTONEAREST = 2;

    private static string lastIconMessage = "";
    public static string LastIconMessage { get { return lastIconMessage; } }

    static IFolderView GetDesktopFolderView(out IntPtr listView)
    {
        listView = IntPtr.Zero;
        Type shellWindowsType = Type.GetTypeFromCLSID(new Guid("9BA05972-F6A8-11CF-A442-00A0C90A8F39"));
        var shellWindows = (IShellWindows)Activator.CreateInstance(shellWindowsType);
        object location = CSIDL_DESKTOP;
        object root = null;
        int hwnd;
        object desktop = shellWindows.FindWindowSW(ref location, ref root, SWC_DESKTOP, out hwnd, SWFO_NEEDDISPATCH);
        if (desktop == null) return null;

        Guid topLevelBrowser = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837");
        Guid browserId = typeof(IShellBrowser).GUID;
        object browserObject;
        if (((IComServiceProvider)desktop).QueryService(ref topLevelBrowser, ref browserId, out browserObject) != 0) return null;

        IShellView view;
        ((IShellBrowser)browserObject).QueryActiveShellView(out view);
        IntPtr defView;
        view.GetWindow(out defView);
        listView = FindWindowEx(defView, IntPtr.Zero, "SysListView32", null);
        return (IFolderView)view;
    }

    // Déplace les icônes du bureau sur l'écran principal. Renvoie le nombre d'icônes déplacées,
    // 0 si elles y sont déjà, -1 si la réorganisation automatique est active, -2 si le bureau est introuvable, -3 en cas d'erreur
    public static int MoveDesktopIconsToPrimary()
    {
        IntPtr oldContext = EnterPhysicalCoordinates();
        var pidls = new List<IntPtr>();
        try
        {
            IntPtr listView;
            IFolderView view = GetDesktopFolderView(out listView);
            if (view == null) { lastIconMessage = "bureau introuvable"; return -2; }
            if (view.GetAutoArrange() == 0) { lastIconMessage = "réorganisation automatique active : Windows place lui-même les icônes"; return -1; }

            int count;
            view.ItemCount(SVGIO_ALLVIEW, out count);
            if (count == 0) { lastIconMessage = "aucune icône sur le bureau"; return 0; }

            // Repère : coordonnées de la vue -> coordonnées écran (pixels physiques)
            POINTL origin = new POINTL();
            if (listView != IntPtr.Zero) ClientToScreen(listView, ref origin);

            RECT work = new RECT();
            SystemParametersInfo(SPI_GETWORKAREA, 0, ref work, 0);
            POINTL spacing;
            view.GetSpacing(out spacing);
            if (spacing.x <= 0 || spacing.y <= 0) { spacing.x = 75; spacing.y = 100; }

            var positions = new List<POINTL>();
            for (int i = 0; i < count; i++)
            {
                IntPtr pidl;
                view.Item(i, out pidl);
                POINTL p;
                view.GetItemPosition(pidl, out p);
                pidls.Add(pidl);
                p.x += origin.x;
                p.y += origin.y;
                positions.Add(p);
            }

            bool allOnPrimary = true;
            int minX = int.MaxValue, minY = int.MaxValue, maxX = int.MinValue, maxY = int.MinValue;
            foreach (POINTL p in positions)
            {
                int cx = p.x + spacing.x / 2, cy = p.y + spacing.y / 2;
                if (cx < work.Left || cx > work.Right || cy < work.Top || cy > work.Bottom) allOnPrimary = false;
                minX = Math.Min(minX, p.x); minY = Math.Min(minY, p.y);
                maxX = Math.Max(maxX, p.x + spacing.x); maxY = Math.Max(maxY, p.y + spacing.y);
            }
            if (allOnPrimary) { lastIconMessage = count + " icône(s) déjà sur l'écran principal"; return 0; }

            // Le groupe d'icônes est déplacé tel quel, en gardant son décalage par rapport au coin de son écran d'origine
            POINTL corner = new POINTL();
            corner.x = minX; corner.y = minY;
            MONITORINFO source = new MONITORINFO();
            source.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
            GetMonitorInfo(MonitorFromPoint(corner, MONITOR_DEFAULTTONEAREST), ref source);
            int offsetX = Math.Max(0, Math.Min(minX - source.rcWork.Left, spacing.x));
            int offsetY = Math.Max(0, Math.Min(minY - source.rcWork.Top, spacing.y));
            int dx = work.Left + offsetX - minX;
            int dy = work.Top + offsetY - minY;

            var target = new POINTL[count];
            if (maxX + dx <= work.Right && maxY + dy <= work.Bottom)
            {
                for (int i = 0; i < count; i++) { target[i].x = positions[i].x + dx; target[i].y = positions[i].y + dy; }
            }
            else
            {
                // Trop d'icônes pour garder la disposition : rangement en colonnes, dans l'ordre actuel (gauche à droite, haut en bas)
                var order = new List<int>();
                for (int i = 0; i < count; i++) order.Add(i);
                order.Sort((a, b) => positions[a].x != positions[b].x ? positions[a].x.CompareTo(positions[b].x) : positions[a].y.CompareTo(positions[b].y));
                int x = work.Left + offsetX, y = work.Top + offsetY;
                foreach (int i in order)
                {
                    target[i].x = x; target[i].y = y;
                    y += spacing.y;
                    if (y + spacing.y > work.Bottom) { y = work.Top + offsetY; x += spacing.x; }
                }
            }

            // Retour en coordonnées de la vue
            for (int i = 0; i < count; i++) { target[i].x -= origin.x; target[i].y -= origin.y; }
            view.SelectAndPositionItems((uint)count, pidls.ToArray(), target, SVSI_POSITIONITEM);
            lastIconMessage = count + " icône(s) replacée(s) sur l'écran principal";
            return count;
        }
        catch (Exception ex)
        {
            lastIconMessage = "erreur : " + ex.Message;
            return -3;
        }
        finally
        {
            foreach (IntPtr pidl in pidls) Marshal.FreeCoTaskMem(pidl);
            LeavePhysicalCoordinates(oldContext);
        }
    }

    static DEVMODE NewDevMode()
    {
        DEVMODE dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        return dm;
    }

    static bool IsBetterMode(DEVMODE dm, DEVMODE best, int currentFrequency)
    {
        long area = (long)dm.dmPelsWidth * dm.dmPelsHeight;
        long bestArea = (long)best.dmPelsWidth * best.dmPelsHeight;
        if (area != bestArea) return area > bestArea;
        if (dm.dmPelsWidth != best.dmPelsWidth) return dm.dmPelsWidth > best.dmPelsWidth;
        // Même résolution : garder la fréquence actuelle si elle existe, sinon la plus haute
        bool keeps = dm.dmDisplayFrequency == currentFrequency;
        bool bestKeeps = best.dmDisplayFrequency == currentFrequency;
        if (keeps != bestKeeps) return keeps;
        return dm.dmDisplayFrequency > best.dmDisplayFrequency;
    }

    // Calcule, sans rien modifier, la résolution maximale de chaque écran actif (plafonnée à sa résolution native)
    public static List<ResolutionChange> GetMaxResolutionPlan()
    {
        var sources = GetSources();
        if (sources == null) return null;

        var plan = new List<ResolutionChange>();
        foreach (var src in sources)
        {
            if (string.IsNullOrEmpty(src.GdiDeviceName)) continue;
            DEVMODE cur = NewDevMode();
            if (!EnumDisplaySettingsEx(src.GdiDeviceName, ENUM_CURRENT_SETTINGS, ref cur, 0)) continue;

            // Résolution native exprimée dans l'orientation actuelle (portrait = 90° ou 270°)
            int capW = src.PreferredWidth, capH = src.PreferredHeight;
            if (cur.dmDisplayOrientation == 1 || cur.dmDisplayOrientation == 3) { int t = capW; capW = capH; capH = t; }

            // Sans EDS_ROTATEDMODE, seuls les modes de l'orientation actuelle sont listés
            DEVMODE best = cur;
            bool found = false;
            for (int i = 0; ; i++)
            {
                DEVMODE dm = NewDevMode();
                if (!EnumDisplaySettingsEx(src.GdiDeviceName, i, ref dm, 0)) break;
                if (dm.dmBitsPerPel != cur.dmBitsPerPel) continue;
                if ((dm.dmDisplayFlags & DM_INTERLACED) != 0) continue;
                if (capW > 0 && capH > 0 && (dm.dmPelsWidth > capW || dm.dmPelsHeight > capH)) continue;
                if (!found || IsBetterMode(dm, best, cur.dmDisplayFrequency)) { best = dm; found = true; }
            }
            if (!found) continue;

            var change = new ResolutionChange();
            change.GdiDeviceName = src.GdiDeviceName;
            change.SourceId = src.Id;
            change.OldWidth = cur.dmPelsWidth;
            change.OldHeight = cur.dmPelsHeight;
            change.OldFrequency = cur.dmDisplayFrequency;
            change.NewWidth = best.dmPelsWidth;
            change.NewHeight = best.dmPelsHeight;
            change.NewFrequency = best.dmDisplayFrequency;
            change.NeedsChange = best.dmPelsWidth != cur.dmPelsWidth
                              || best.dmPelsHeight != cur.dmPelsHeight
                              || best.dmDisplayFrequency != cur.dmDisplayFrequency;
            change.Mode = best;
            plan.Add(change);
        }
        return plan;
    }

    // Passe chaque écran actif à sa résolution maximale ; les écrans déjà au maximum ne sont pas touchés
    public static List<ResolutionChange> SetMaxResolutions()
    {
        var plan = GetMaxResolutionPlan();
        if (plan == null) { lastResult = -1; return null; }

        bool pending = false;
        foreach (var change in plan)
        {
            if (!change.NeedsChange) continue;
            DEVMODE dm = change.Mode;
            dm.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY;
            change.Result = ChangeDisplaySettingsEx(change.GdiDeviceName, ref dm, IntPtr.Zero, (uint)(CDS_UPDATEREGISTRY | CDS_NORESET), IntPtr.Zero);
            if (change.Result == 0) { change.Changed = true; pending = true; }
        }

        lastResult = 0;
        if (pending)
        {
            lastResult = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
            if (lastResult != 0)
            {
                foreach (var change in plan)
                {
                    if (change.Changed) { change.Changed = false; change.Result = lastResult; }
                }
            }
        }
        return plan;
    }

    // Positionne une fenêtre en coordonnées écran du processus (même repère que System.Windows.Forms.Screen)
    public static bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height)
    {
        return SetWindowPos(hwnd, IntPtr.Zero, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MARGINS { public int Left, Right, Top, Bottom; }

    [DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    [DllImport("dwmapi.dll")]
    static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS margins);

    const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    const int DWMWA_SYSTEMBACKDROP_TYPE     = 38;
    const int DWMSBT_MAINWINDOW             = 2;

    // Barre de titre claire ou sombre selon le thème Windows ; renvoie true si le fond Mica (Windows 11) est actif
    public static bool ApplyWindowStyle(IntPtr hwnd, bool dark, bool mica)
    {
        try
        {
            int value = dark ? 1 : 0;
            DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref value, sizeof(int));
            if (!mica) return false;

            int backdrop = DWMSBT_MAINWINDOW;
            if (DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, sizeof(int)) != 0) return false;

            MARGINS margins = new MARGINS();
            margins.Left = margins.Right = margins.Top = margins.Bottom = -1;
            return DwmExtendFrameIntoClientArea(hwnd, ref margins) == 0;
        }
        catch
        {
            return false;
        }
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

# Identité propre dans la barre des tâches (icône de l'app au lieu du logo PowerShell)
Try { [void][DisplayApi]::SetAppId("ScreenConfig.ConfigurationEcrans") } Catch { }

# ========== JOURNAL DE DIAGNOSTIC ==========
# Réécrit à chaque application : écrans vus, rôles attribués, codes de retour de Windows
$script:DiagnosticPath = Join-Path $env:APPDATA "ScreenConfig\diagnostic.log"

Function Start-DiagnosticLog {
    param([string]$Title)
    Try {
        $dir = Split-Path -Parent $script:DiagnosticPath
        If (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($script:DiagnosticPath, "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Title`r`n", [System.Text.Encoding]::UTF8)
    } Catch { }
}

Function Write-DiagnosticLog {
    param([string]$Message)
    Try {
        [System.IO.File]::AppendAllText($script:DiagnosticPath, "$(Get-Date -Format 'HH:mm:ss.fff') $Message`r`n", [System.Text.Encoding]::UTF8)
    } Catch { }
}

Function Format-SourceForLog {
    param($Source)
    $name = if ($Source.FriendlyName) { $Source.FriendlyName } elseif ($Source.PnpId) { $Source.PnpId } else { "?" }
    return "{0} {1} [{2}] interne={3} tech=0x{4:X} pos={5},{6} taille={7}x{8} principal={9}" -f `
        $Source.GdiDeviceName, $name, $Source.Key, $Source.IsInternal, $Source.OutputTechnology,
        $Source.X, $Source.Y, $Source.Width, $Source.Height, $Source.IsPrimary
}

Function Write-SourcesToLog {
    param([string]$Label)
    $list = [DisplayApi]::GetSources()
    Write-DiagnosticLog "$Label :"
    foreach ($s in @(if ($list) { $list })) { Write-DiagnosticLog "  $(Format-SourceForLog -Source $s)" }
}

# Le mode d'affichage demandé est-il déjà en place ? (évite de relancer DisplaySwitch inutilement)
Function Test-DisplayModeReady {
    param([string]$Mode, [int]$MinScreens)

    $list = [DisplayApi]::GetSources()
    $sources = @(if ($list) { $list })
    if ($sources.Count -lt $MinScreens) { return $false }
    if ($Mode -eq 'external') { return (@($sources | Where-Object { $_.IsInternal }).Count -eq 0) }

    # Étendu : chaque moniteur branché est allumé et a sa propre source (pas de duplication d'écran)
    $connected = [DisplayApi]::GetConnectedMonitors()
    $monitors = @(if ($connected) { $connected })
    $active = @($monitors | Where-Object { $_.IsActive }).Count
    return ($monitors.Count -gt 0 -and $active -eq $monitors.Count -and $sources.Count -eq $monitors.Count)
}

Function Wait-ExtendedDesktop {
    param(
        [int]$TimeoutSeconds = 10,
        [int]$MinScreens = 2,
        # extend = Étendre ; external = Deuxième écran uniquement (la dalle du portable est coupée)
        [ValidateSet('extend', 'external')]
        [string]$Mode = 'extend'
    )

    # DisplaySwitch applique le mode en arrière-plan et peut réappliquer l'ancienne disposition enregistrée :
    # il n'est lancé que si nécessaire, et on attend qu'il ait terminé avant de placer les écrans
    if (Test-DisplayModeReady -Mode $Mode -MinScreens $MinScreens) {
        Write-DiagnosticLog "Mode $Mode déjà actif : DisplaySwitch non lancé"
    } else {
        Write-DiagnosticLog "Lancement de DisplaySwitch /$Mode"
        $process = Start-Process -FilePath "DisplaySwitch.exe" -ArgumentList "/$Mode" -PassThru -WindowStyle Hidden
        if (-not $process.WaitForExit(5000)) { Write-DiagnosticLog "DisplaySwitch toujours actif après 5 s" }
    }

    # Attente d'un affichage prêt et stable (deux relevés identiques consécutifs)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $previous = $null
    do {
        Start-Sleep -Milliseconds 500
        $sources = [DisplayApi]::GetSources()
        $ready = $sources -and $sources.Count -ge $MinScreens -and
                 ($Mode -ne 'external' -or @($sources | Where-Object { $_.IsInternal }).Count -eq 0)
        $signature = if ($sources) { (@($sources | ForEach-Object { "$($_.Key)@$($_.X),$($_.Y),$($_.Width)x$($_.Height)" }) -join ';') } else { "" }
        $stable = $ready -and $signature -eq $previous
        $previous = $signature
    } while (-not $stable -and (Get-Date) -lt $deadline)
    if (-not $ready) {
        throw "Extended desktop not ready after ${TimeoutSeconds}s. Found $( if ($sources) { $sources.Count } else { 0 } ) source(s)."
    }
    return $sources
}

# Passe chaque écran à sa résolution maximale (plafonnée à la résolution native), puis relit les sources
Function Set-MaxResolution {
    param([int]$MinScreens = 1)

    $script:LastResolutionChanges = @()
    $changes = [DisplayApi]::SetMaxResolutions()
    if ($null -eq $changes) { throw "Could not read display modes." }
    $script:LastResolutionChanges = @($changes)

    foreach ($c in $changes) {
        if ($c.Changed) {
            Write-Host "$($c.GdiDeviceName): $($c.OldWidth)x$($c.OldHeight)@$($c.OldFrequency)Hz -> $($c.NewWidth)x$($c.NewHeight)@$($c.NewFrequency)Hz" -ForegroundColor Green
        } elseif ($c.NeedsChange) {
            Write-Warning "$($c.GdiDeviceName): could not set $($c.NewWidth)x$($c.NewHeight)@$($c.NewFrequency)Hz (code $($c.Result))."
        }
    }

    $sources = [DisplayApi]::GetSources()
    if (-not $sources -or $sources.Count -lt $MinScreens) {
        throw "Only $( if ($sources) { $sources.Count } else { 0 } ) screen(s) found after resolution change."
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
    foreach ($key in $final.Keys) { Write-DiagnosticLog "Position demandée [$key] = $($final[$key].x),$($final[$key].y)" }
    $ok = [DisplayApi]::ApplyPositionsByKey($final)
    Write-DiagnosticLog "SetDisplayConfig : code $([DisplayApi]::LastResult)"
    if (-not $ok) {
        Write-Warning "SetDisplayConfig returned code: $([DisplayApi]::LastResult)"
        return $false
    }
    Write-Host "$LayoutName layout applied." -ForegroundColor Green
    Write-SourcesToLog -Label "Après placement"

    # Windows ne fait pas toujours de l'écran placé en (0,0) l'écran principal, et peut réappliquer une ancienne
    # disposition juste après : l'écran principal réel est vérifié plusieurs fois et corrigé par son nom GDI
    # jusqu'à être confirmé deux fois de suite
    $primary = $Sources[$PrimaryIndex]
    Write-DiagnosticLog "Écran principal voulu : $($primary.GdiDeviceName) [$($primary.Key)]"
    $confirmations = 0
    for ($attempt = 0; $attempt -lt 8 -and $confirmations -lt 2; $attempt++) {
        if ($attempt -gt 0) { Start-Sleep -Milliseconds 500 }
        $current = [DisplayApi]::GetSources() | Where-Object { $_.Key -eq $primary.Key } | Select-Object -First 1
        if (-not $current) {
            Write-DiagnosticLog "Écran principal voulu introuvable"
            break
        }
        if ($current.IsPrimary) {
            $confirmations++
            continue
        }
        $confirmations = 0
        if ($current.GdiDeviceName) {
            $set = [DisplayApi]::SetPrimaryDisplay($current.GdiDeviceName)
        } else {
            $set = [DisplayApi]::TrySetPrimaryByPosition($current.X, $current.Y)
        }
        Write-DiagnosticLog "Correction de l'écran principal ($($current.GdiDeviceName)) : $set, code $([DisplayApi]::LastResult)"
    }
    $isPrimary = $confirmations -ge 2
    Write-SourcesToLog -Label "État final"

    # Icônes du bureau : Explorer les laisse dans le coin haut-gauche de l'ensemble du bureau, qui n'est pas
    # forcément l'écran principal. On lui laisse le temps de prendre en compte la nouvelle disposition, puis on
    # les replace sur l'écran principal ; une seconde vérification rattrape un éventuel replacement par Explorer.
    $script:LastIconsMoved = 0
    if ($isPrimary) {
        foreach ($delay in 1000, 1500) {
            Start-Sleep -Milliseconds $delay
            $moved = [DisplayApi]::MoveDesktopIconsToPrimary()
            Write-DiagnosticLog "Icônes du bureau : $([DisplayApi]::LastIconMessage)"
            if ($moved -gt 0) { $script:LastIconsMoved = $moved }
            if ($moved -lt 0) { break }
        }
    }

    if ($isPrimary) {
        Write-Host "Primary set to screen index $PrimaryIndex (ID $($primary.Id))." -ForegroundColor Green
    } else {
        $script:LastLayoutWarning = "Could not set primary display (code $([DisplayApi]::LastResult))."
        Write-Warning $script:LastLayoutWarning
    }

    return $true
}

# Positions (x, y) de chaque emplacement d'une disposition, à partir de la taille des écrans placés dans ces emplacements
Function Get-LayoutGeometry {
    param(
        [string]$LayoutKey,
        $Slots
    )

    $result = @()
    switch ($LayoutKey) {
        "T" {
            # Emplacements : 0 = haut gauche, 1 = haut droite, 2 = bas centré
            $srcB = $Slots[0]; $srcC = $Slots[1]; $srcA = $Slots[2]
            $topWidth = $srcB.Width + $srcC.Width
            [int]$xA = [Math]::Floor(($topWidth - $srcA.Width) / 2.0)
            [int]$yA = [Math]::Max($srcB.Height, $srcC.Height)
            $result = @( @(0, 0), @([int]$srcB.Width, 0), @($xA, $yA) )
        }
        "Horizontal" {
            # Tous les écrans côte à côte, de gauche à droite
            $xOffset = 0
            foreach ($src in $Slots) {
                $result += , @($xOffset, 0)
                $xOffset += $src.Width
            }
        }
        "LineOut" {
            # Emplacements : 0 = gauche, 1 = centre, 2 = petit écran à droite aligné en bas
            $srcA = $Slots[0]; $srcB = $Slots[1]; $srcC = $Slots[2]
            $mainHeight = [Math]::Max($srcA.Height, $srcB.Height)
            [int]$yC = $mainHeight - $srcC.Height
            $result = @( @(0, 0), @([int]$srcA.Width, 0), @([int]($srcA.Width + $srcB.Width), $yC) )
        }
        "Below" {
            # Emplacements : 0 = grand écran, 1 = écran centré juste en dessous
            $top = $Slots[0]; $bottom = $Slots[1]
            [int]$xBottom = [Math]::Floor(($top.Width - $bottom.Width) / 2.0)
            $result = @( @(0, 0), @($xBottom, [int]$top.Height) )
        }
        "BelowRight" {
            # Emplacements : 0 = grand écran, 1 = écran juste en dessous, aligné sur son bord droit
            $top = $Slots[0]; $bottom = $Slots[1]
            $result = @( @(0, 0), @([int]($top.Width - $bottom.Width), [int]$top.Height) )
        }
        default {
            throw "Unknown layout: $LayoutKey"
        }
    }
    return , $result
}

Function Set-LayoutTShape {
    param(
        [int]$PrimaryIndex = 0,
        [int[]]$SourceMap = @(1, 2, 0),
        [switch]$MaxResolution
    )

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }
    if ($MaxResolution) { $sources = Set-MaxResolution -MinScreens 3 }

    $slots = Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount 3
    $geometry = Get-LayoutGeometry -LayoutKey "T" -Slots $slots

    $positions = [ordered]@{}
    for ($i = 0; $i -lt 3; $i++) { $positions[$slots[$i].Key] = $geometry[$i] }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "T-shape"
}

Function Set-LayoutHorizontal {
    param(
        [int]$MinScreens = 3,
        [int]$PrimaryIndex = 2,
        [int[]]$SourceMap = @(),
        [switch]$MaxResolution
    )

    $sources = Wait-ExtendedDesktop -MinScreens $MinScreens
    if ($sources.Count -lt $MinScreens) { throw "Need at least $MinScreens screens, found $($sources.Count)." }
    if ($MaxResolution) { $sources = Set-MaxResolution -MinScreens $MinScreens }

    # Ordre de gauche à droite : écrans du SourceMap, puis les autres dans l'ordre des Id
    $ordered = @()
    if ($SourceMap.Count -gt 0) {
        $ordered += Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount $SourceMap.Count
    }
    $usedKeys = @($ordered | ForEach-Object { $_.Key })
    foreach ($src in $sources) {
        if ($usedKeys -notcontains $src.Key) { $ordered += $src }
    }

    $geometry = Get-LayoutGeometry -LayoutKey "Horizontal" -Slots $ordered
    $positions = [ordered]@{}
    for ($i = 0; $i -lt $ordered.Count; $i++) { $positions[$ordered[$i].Key] = $geometry[$i] }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Horizontal"
}

Function Set-LayoutLineOut {
    param(
        [int]$PrimaryIndex = 0,
        [int[]]$SourceMap = @(0, 1, 2),
        [switch]$MaxResolution
    )

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }
    if ($MaxResolution) { $sources = Set-MaxResolution -MinScreens 3 }

    $slots = Resolve-SlotSources -Sources $sources -SourceMap $SourceMap -SlotCount 3
    $geometry = Get-LayoutGeometry -LayoutKey "LineOut" -Slots $slots

    $positions = [ordered]@{}
    for ($i = 0; $i -lt 3; $i++) { $positions[$slots[$i].Key] = $geometry[$i] }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Line-out"
}

# ========== RÔLES DES ÉCRANS ==========
# Écran du portable : la dalle interne ; à défaut (aucune dalle interne), le plus petit écran
Function Find-LaptopScreen {
    param($Sources)

    $internal = @($Sources | Where-Object { $_.IsInternal })
    if ($internal.Count -gt 0) { return $internal[0] }

    $withSize = @($Sources | Where-Object { $_.Edid -and $_.Edid.DiagonalInches -gt 0 })
    if ($withSize.Count -eq @($Sources).Count) {
        return ($Sources | Sort-Object { $_.Edid.DiagonalInches } | Select-Object -First 1)
    }
    return ($Sources | Sort-Object { $_.Width * $_.Height } | Select-Object -First 1)
}

# L = écran du portable, M1 / M2 = écrans externes de gauche à droite (ordre des Id, inversable)
Function Get-ScreenRoles {
    param(
        $Sources,
        [bool]$WithLaptop = $true,
        [bool]$SwapExternal = $false
    )

    $all = @($Sources)
    $laptop = $null
    if ($WithLaptop -and $all.Count -ge 2) { $laptop = Find-LaptopScreen -Sources $all }

    if ($laptop) {
        $externals = @($all | Where-Object { $_.Key -ne $laptop.Key })
    } else {
        # Sans portable (fermé) : écrans externes d'abord, dalle interne éventuelle en dernier
        $externals = @($all | Where-Object { -not $_.IsInternal }) + @($all | Where-Object { $_.IsInternal })
    }
    if ($SwapExternal -and $externals.Count -ge 2) {
        $tmp = $externals[0]; $externals[0] = $externals[1]; $externals[1] = $tmp
    }

    return @{
        L  = $laptop
        M1 = $(if ($externals.Count -gt 0) { $externals[0] } else { $null })
        M2 = $(if ($externals.Count -gt 1) { $externals[1] } else { $null })
    }
}

# Applique une configuration : mode étendu, résolution maximale éventuelle, placement et écran principal
Function Invoke-ScreenConfiguration {
    param(
        $Config,
        [switch]$MaxResolution,
        [switch]$SwapExternal
    )

    Start-DiagnosticLog -Title "Configuration $($Config.Name) (résolution max : $([bool]$MaxResolution), inversion : $([bool]$SwapExternal))"
    Write-SourcesToLog -Label "État initial"

    $mode = if ($Config.DisplayMode) { $Config.DisplayMode } else { 'extend' }
    try {
        $sources = @(Wait-ExtendedDesktop -MinScreens $Config.MinScreens -Mode $mode)
    } catch {
        Write-DiagnosticLog "Écrans attendus introuvables : $($_.Exception.Message)"
        throw "La configuration $($Config.Name) n'a pas trouvé les écrans attendus : $($Config.MissingHint)."
    }
    if ($MaxResolution) { $sources = @(Set-MaxResolution -MinScreens $Config.MinScreens) }
    Write-SourcesToLog -Label "Écrans utilisés"

    # Portable fermé : seuls les deux écrans externes sont actifs
    $plan = $Config
    $withLaptop = $true
    if ($sources.Count -lt $Config.Slots.Count) {
        if (-not $Config.Fallback) { throw "La configuration $($Config.Name) demande $($Config.Slots.Count) écrans actifs, $($sources.Count) détecté(s)." }
        $plan = $Config.Fallback
        $withLaptop = $false
    }

    $roles = Get-ScreenRoles -Sources $sources -WithLaptop $withLaptop -SwapExternal ([bool]$SwapExternal)
    foreach ($role in "L", "M1", "M2") {
        $label = if ($roles[$role]) { "$($roles[$role].GdiDeviceName) [$($roles[$role].Key)]" } else { "-" }
        Write-DiagnosticLog "Rôle $role (L = portable, M = externe) : $label"
    }
    $slots = New-Object object[] $plan.Slots.Count
    for ($i = 0; $i -lt $plan.Slots.Count; $i++) {
        $slots[$i] = $roles[$plan.Slots[$i]]
        if (-not $slots[$i]) { throw "Impossible d'attribuer les écrans de la configuration $($Config.Name)." }
    }

    $geometry = Get-LayoutGeometry -LayoutKey $plan.Geometry -Slots $slots
    $positions = [ordered]@{}
    for ($i = 0; $i -lt $slots.Count; $i++) { $positions[$slots[$i].Key] = $geometry[$i] }

    $primaryKey = $roles[$plan.Primary].Key
    $primaryIndex = 0
    for ($i = 0; $i -lt $sources.Count; $i++) {
        if ($sources[$i].Key -eq $primaryKey) { $primaryIndex = $i; break }
    }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $primaryIndex -LayoutName $Config.Name
}

# ========== CONFIGURATIONS ==========
# Postes de travail : les configurations sont regroupées par poste dans l'interface
$script:Devices = @(
    @{ Key = "Dual"; Name = "Poste à deux écrans" },
    @{ Key = "UW34"; Name = "Poste avec écran 34 pouces" },
    @{ Key = "M27"; Name = "Poste avec écran 27 pouces" }
)

# Device : poste concerné ; Slots : rôles placés dans chaque emplacement de la géométrie (L = portable, M1 / M2 = écrans externes)
# Primary : rôle de l'écran principal ; Fallback : disposition utilisée quand le portable est fermé
# MinScreens / MinExternal : écrans actifs nécessaires ; DisplayMode external : seul l'écran externe reste allumé
$script:Configs = @(
    @{
        Key = "TOpen"; Name = "T ouvert"; Device = "Dual"; Image = "t-ouvert.png"; Favorite = $true
        Description = "Portable ouvert sous les deux écrans"
        PrimaryLabel = "l'écran du portable"
        Geometry = "T"; Slots = @("M1", "M2", "L"); Primary = "L"; MinScreens = 3; MinExternal = 2
        MissingHint = "ouvrez l'ordinateur portable et vérifiez que les deux écrans sont branchés"
    },
    @{
        Key = "LineRightClosed"; Name = "Ligne D fermé"; Device = "Dual"; Image = "ligne-d-ferme.png"; Favorite = $false
        Description = "Portable fermé à droite des deux écrans"
        PrimaryLabel = "l'écran externe de gauche"
        Geometry = "LineOut"; Slots = @("M1", "M2", "L"); Primary = "M1"; MinScreens = 2; MinExternal = 2
        Fallback = @{ Geometry = "Horizontal"; Slots = @("M1", "M2"); Primary = "M1" }
        MissingHint = "vérifiez que les deux écrans sont branchés"
    },
    @{
        Key = "LineRightOpen"; Name = "Ligne D ouvert"; Device = "Dual"; Image = "ligne-d-ouvert.png"; Favorite = $false
        Description = "Portable ouvert à droite des deux écrans"
        PrimaryLabel = "l'écran du portable"
        Geometry = "Horizontal"; Slots = @("M1", "M2", "L"); Primary = "L"; MinScreens = 3; MinExternal = 2
        MissingHint = "ouvrez l'ordinateur portable et vérifiez que les deux écrans sont branchés"
    },
    @{
        Key = "LineLeftOpen"; Name = "Ligne G ouvert"; Device = "Dual"; Image = "ligne-g-ouvert.png"; Favorite = $false
        Description = "Portable ouvert à gauche des deux écrans"
        PrimaryLabel = "l'écran du portable"
        Geometry = "Horizontal"; Slots = @("L", "M1", "M2"); Primary = "L"; MinScreens = 3; MinExternal = 2
        MissingHint = "ouvrez l'ordinateur portable et vérifiez que les deux écrans sont branchés"
    },
    @{
        Key = "UW34Open"; Name = "34″ ouvert"; Device = "UW34"; Image = "34-ouvert.png"; Favorite = $false
        Description = "Portable ouvert sous l'écran 34 pouces"
        PrimaryLabel = "l'écran du portable"
        Geometry = "Below"; Slots = @("M1", "L"); Primary = "L"; MinScreens = 2; MinExternal = 1
        MissingHint = "ouvrez l'ordinateur portable et vérifiez que l'écran 34 pouces est branché"
    },
    @{
        Key = "UW34Closed"; Name = "34″ fermé"; Device = "UW34"; Image = "34-ferme.png"; Favorite = $false
        Description = "Écran 34 pouces seul, portable fermé"
        PrimaryLabel = "l'écran 34 pouces, seul écran utilisé"
        Geometry = "Horizontal"; Slots = @("M1"); Primary = "M1"; MinScreens = 1; MinExternal = 1; DisplayMode = "external"
        MissingHint = "vérifiez que l'écran 34 pouces est branché"
    },
    @{
        Key = "M27Open"; Name = "27″ ouvert"; Device = "M27"; Image = "27-ouvert.png"; Favorite = $false
        Description = "Portable ouvert en bas à droite de l'écran 27 pouces"
        PrimaryLabel = "l'écran du portable"
        Geometry = "BelowRight"; Slots = @("M1", "L"); Primary = "L"; MinScreens = 2; MinExternal = 1
        MissingHint = "ouvrez l'ordinateur portable et vérifiez que l'écran 27 pouces est branché"
    }
)

$script:AppRoot = If ($PSScriptRoot) { $PSScriptRoot } Else { (Get-Location).Path }
$script:ImageDir = Join-Path $script:AppRoot "images"

# ========== PRÉFÉRENCES (favoris, résolution maximale, inversion des écrans externes) ==========
$script:SettingsPath = Join-Path $env:APPDATA "ScreenConfig\settings.json"
$script:UseMaxResolution = $true
$script:SwapExternal = $false

Function Save-Settings {
    Try {
        $data = @{
            Favorites     = @($script:Configs | Where-Object { $_.Favorite } | ForEach-Object { $_.Key })
            MaxResolution = [bool]$script:UseMaxResolution
            SwapExternal  = [bool]$script:SwapExternal
        }
        $dir = Split-Path -Parent $script:SettingsPath
        If (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($script:SettingsPath, ($data | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
    }
    Catch {
        Write-Warning "Préférences non enregistrées : $($_.Exception.Message)"
    }
}

Function Import-Settings {
    If (-not (Test-Path -LiteralPath $script:SettingsPath)) { return }
    Try {
        $data = [System.IO.File]::ReadAllText($script:SettingsPath) | ConvertFrom-Json
        If ($null -ne $data.MaxResolution) { $script:UseMaxResolution = [bool]$data.MaxResolution }
        If ($null -ne $data.SwapExternal) { $script:SwapExternal = [bool]$data.SwapExternal }

        If ($null -ne $data.Favorites) {
            $favorites = @($data.Favorites)
        } ElseIf ($null -ne $data.Layouts) {
            # Ancien format : favoris des dispositions T-shape / Line-out / Full line
            $oldToNew = @{ T = "TOpen"; LineOut = "LineRightClosed"; Horizontal = "LineRightOpen" }
            $favorites = @($data.Layouts | Where-Object { $_.Favorite -and $oldToNew.ContainsKey([string]$_.LayoutKey) } | ForEach-Object { $oldToNew[[string]$_.LayoutKey] })
        } Else {
            return
        }
        ForEach ($config In $script:Configs) { $config.Favorite = ($favorites -contains $config.Key) }
    }
    Catch {
        Write-Warning "Préférences ignorées : $($_.Exception.Message)"
    }
}

Import-Settings

$script:SelectedLayoutIndex = 0
$script:ShowFavoritesOnly = $false
$script:LastLayoutWarning = $null
$script:LastResolutionChanges = @()

# ========== ÉCRANS CONNECTÉS ==========
# Displays : écrans allumés (sources du bureau) ; Monitors : moniteurs branchés, allumés ou non
$script:Displays = @()
$script:Monitors = @()
$script:DisplaySignature = ""

Function Update-DisplayInfo {
    Try { $list = [DisplayApi]::GetSources() } Catch { $list = $null }
    $script:Displays = @(If ($list) { $list })
    Try { $connected = [DisplayApi]::GetConnectedMonitors() } Catch { $connected = $null }
    $script:Monitors = @(If ($connected) { $connected })

    # Empreinte de l'état des écrans : sert à ne rafraîchir l'interface que si quelque chose a changé
    $script:DisplaySignature = (@($script:Monitors | ForEach-Object { "$($_.Key):$($_.IsActive)" }) +
                                @($script:Displays | ForEach-Object { "$($_.Key)@$($_.X),$($_.Y),$($_.Width)x$($_.Height)" })) -join ';'
}

# Moniteurs branchés ; à défaut (API indisponible), les écrans allumés
Function Get-ConnectedScreens {
    If ($script:Monitors.Count -gt 0) { return $script:Monitors }
    return $script:Displays
}

Function Get-ScreenName {
    param($Screen)

    $name = $Screen.FriendlyName
    If (-not $name -and $Screen.Edid -and $Screen.Edid.Model -ne "Unknown") { $name = $Screen.Edid.Model }
    If (-not $name -and $Screen.PnpId) { $name = $Screen.PnpId }
    If (-not $name) { $name = "Écran" }
    return $name
}

Function Get-DisplayName {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "Non détecté" }
    return Get-ScreenName -Screen $script:Displays[$Index]
}

# Nom + résolution de l'écran d'index $Index
Function Get-DisplayLabel {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "Non détecté" }
    $d = $script:Displays[$Index]
    return "$(Get-DisplayName -Index $Index)`n$($d.Width) × $($d.Height)"
}

# Poste reconnu d'après les écrans externes branchés (allumés ou non) : deux écrans, un écran 34 pouces (ultra-large) ou un écran 27 pouces
Function Get-DetectedDevice {
    $externals = @(Get-ConnectedScreens | Where-Object { -not $_.IsInternal })
    If ($externals.Count -ge 2) { return "Dual" }
    If ($externals.Count -eq 1) {
        $d = $externals[0]
        $diagonal = If ($d.Edid) { $d.Edid.DiagonalInches } Else { 0 }
        $width = If ($d.PreferredWidth) { $d.PreferredWidth } Else { $d.Width }
        $height = If ($d.PreferredHeight) { $d.PreferredHeight } Else { $d.Height }
        $ratio = If ($height -gt 0) { $width / $height } Else { 0 }
        If ($diagonal -ge 30 -or $ratio -ge 2.1) { return "UW34" }
        return "M27"
    }
    return $null
}

# Configurations proposées : celles du poste détecté, ou toutes si aucun poste n'est reconnu
Function Get-CompatibleConfigIndexes {
    For ($i = 0; $i -lt $script:Configs.Count; $i++) {
        If (-not $script:DetectedDevice -or $script:Configs[$i].Device -eq $script:DetectedDevice) { $i }
    }
}

# Sélectionne la première favorite compatible, sinon la première configuration compatible ;
# avec -KeepCurrent, la sélection actuelle est conservée si elle reste compatible
Function Select-CompatibleConfig {
    param([switch]$KeepCurrent)

    $candidates = @(Get-CompatibleConfigIndexes)
    If ($KeepCurrent -and $candidates -contains $script:SelectedLayoutIndex) { return }
    $favorites = @($candidates | Where-Object { $script:Configs[$_].Favorite })
    If ($favorites.Count -gt 0) {
        $script:SelectedLayoutIndex = $favorites[0]
    } ElseIf ($candidates.Count -gt 0) {
        $script:SelectedLayoutIndex = $candidates[0]
    }
}

Update-DisplayInfo
$script:DetectedDevice = Get-DetectedDevice
Select-CompatibleConfig

# ========== THÈME WINDOWS (clair / sombre, couleur d'accent) ==========
Function Get-WindowsUsesLightTheme {
    Try {
        return [bool](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme).AppsUseLightTheme
    } Catch {
        return $true
    }
}

# Nuancier d'accent Windows : 0..2 = clairs, 3 = accent, 4..6 = foncés
Function Get-AccentPalette {
    $palette = @('#99EBFF', '#4CC2FF', '#0091F8', '#0078D4', '#0067C0', '#003E92', '#001A68')
    Try {
        $bytes = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' -Name AccentPalette).AccentPalette
        If ($bytes -and $bytes.Length -ge 28) {
            $palette = @(For ($i = 0; $i -lt 7; $i++) { '#{0:X2}{1:X2}{2:X2}' -f $bytes[$i * 4], $bytes[$i * 4 + 1], $bytes[$i * 4 + 2] })
        }
    } Catch { }
    return , $palette
}

$script:IsDark = -not (Get-WindowsUsesLightTheme)
$script:UseMica = $false
Try { $script:UseMica = ([int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild) -ge 22621 } Catch { }

$accentPalette = Get-AccentPalette
# Couleurs Fluent de Windows 11 ; les surfaces sont translucides pour laisser passer le fond Mica
# Illustration : fond clair dans les deux thèmes, les images étant dessinées en noir sur fond transparent
If ($script:IsDark) {
    $accent = $accentPalette[1]
    $C = @{
        Bg = '#202020'; Text = '#FFFFFF'; TextSecondary = '#CFCFCF'
        Card = '#0DFFFFFF'; CardHover = '#15FFFFFF'; CardBorder = '#19000000'; Footer = '#0DFFFFFF'
        ControlFill = '#0FFFFFFF'; ControlHover = '#15FFFFFF'; ControlPressed = '#08FFFFFF'; ControlStroke = '#17FFFFFF'
        Subtle = '#0FFFFFFF'; SubtlePressed = '#0AFFFFFF'; Flyout = '#2C2C2C'
        Illustration = '#E9E9E9'
        AccentText = '#000000'
        InfoBg = '#08FFFFFF'; SuccessBg = '#393D1B'; SuccessFg = '#6CCB5F'
        WarningBg = '#433519'; WarningFg = '#FCE100'; ErrorBg = '#442726'; ErrorFg = '#FF99A4'
    }
} Else {
    $accent = $accentPalette[4]
    $C = @{
        Bg = '#F3F3F3'; Text = '#1A1A1A'; TextSecondary = '#5F5F5F'
        Card = '#B3FFFFFF'; CardHover = '#80F9F9F9'; CardBorder = '#0F000000'; Footer = '#B3FFFFFF'
        ControlFill = '#B3FFFFFF'; ControlHover = '#80F9F9F9'; ControlPressed = '#4DF9F9F9'; ControlStroke = '#1A000000'
        Subtle = '#0A000000'; SubtlePressed = '#06000000'; Flyout = '#F9F9F9'
        Illustration = '#FFFFFF'
        AccentText = '#FFFFFF'
        InfoBg = '#80F6F6F6'; SuccessBg = '#DFF6DD'; SuccessFg = '#0F7B0F'
        WarningBg = '#FFF4CE'; WarningFg = '#9D5D00'; ErrorBg = '#FDE7E9'; ErrorFg = '#C42B1C'
    }
}
$C.Accent = $accent
$C.AccentHover = '#E6' + $accent.Substring(1)
$C.AccentPressed = '#CC' + $accent.Substring(1)

$script:IconFont = "Segoe Fluent Icons, Segoe MDL2 Assets"
$script:BrushConverter = [System.Windows.Media.BrushConverter]::new()

Function New-Brush {
    param([string]$Color)
    $brush = $script:BrushConverter.ConvertFromString($Color)
    $brush.Freeze()
    return $brush
}

# ========== XAML DE L'INTERFACE ==========
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Configuration des écrans"
    Width="1000" Height="860"
    MinWidth="720" MinHeight="560"
    WindowStartupLocation="CenterScreen"
    Background="$($C.Bg)" Foreground="$($C.Text)"
    FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="14"
    UseLayoutRounding="True">

    <Window.Resources>
        <Style x:Key="FocusRing">
            <Setter Property="Control.Template">
                <Setter.Value>
                    <ControlTemplate>
                        <Rectangle Margin="-3" RadiusX="6" RadiusY="6" Stroke="$($C.Text)" StrokeThickness="2"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="Icon" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="$($script:IconFont)"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>

        <Style x:Key="SectionTitle" TargetType="TextBlock">
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,28,0,8"/>
        </Style>

        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="$($C.Card)"/>
            <Setter Property="BorderBrush" Value="$($C.CardBorder)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="6"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
        </Style>

        <Style x:Key="BtnStandard" TargetType="Button">
            <Setter Property="Foreground" Value="$($C.Text)"/>
            <Setter Property="Background" Value="$($C.ControlFill)"/>
            <Setter Property="BorderBrush" Value="$($C.ControlStroke)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,5"/>
            <Setter Property="MinHeight" Value="32"/>
            <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4"
                                Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($C.ControlHover)"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="$($C.ControlPressed)"/>
                    <Setter Property="Foreground" Value="$($C.TextSecondary)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="BtnAccent" TargetType="Button" BasedOn="{StaticResource BtnStandard}">
            <Setter Property="Foreground" Value="$($C.AccentText)"/>
            <Setter Property="Background" Value="$($C.Accent)"/>
            <Setter Property="BorderBrush" Value="$($C.Accent)"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($C.AccentHover)"/>
                    <Setter Property="BorderBrush" Value="$($C.AccentHover)"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="$($C.AccentPressed)"/>
                    <Setter Property="BorderBrush" Value="$($C.AccentPressed)"/>
                    <Setter Property="Foreground" Value="$($C.AccentText)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="BtnIcon" TargetType="Button" BasedOn="{StaticResource BtnStandard}">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="MinHeight" Value="0"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($C.Subtle)"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="$($C.SubtlePressed)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Bouton bascule en forme de pastille (filtre favoris) -->
        <Style x:Key="Chip" TargetType="ToggleButton">
            <Setter Property="Foreground" Value="$($C.Text)"/>
            <Setter Property="Background" Value="$($C.ControlFill)"/>
            <Setter Property="BorderBrush" Value="$($C.ControlStroke)"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,5"/>
            <Setter Property="MinHeight" Value="32"/>
            <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4"
                                Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$($C.ControlHover)"/>
                </Trigger>
                <Trigger Property="IsChecked" Value="True">
                    <Setter Property="Background" Value="$($C.Accent)"/>
                    <Setter Property="BorderBrush" Value="$($C.Accent)"/>
                    <Setter Property="Foreground" Value="$($C.AccentText)"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Interrupteur Activé / Désactivé façon Paramètres Windows -->
        <Style x:Key="ToggleSwitch" TargetType="CheckBox">
            <Setter Property="Foreground" Value="$($C.Text)"/>
            <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" Background="Transparent">
                            <TextBlock x:Name="lbl" Text="Désactivé" VerticalAlignment="Center" Margin="0,0,12,0"/>
                            <Grid Width="40" Height="20" VerticalAlignment="Center">
                                <Border x:Name="track" CornerRadius="10" BorderThickness="1"
                                        BorderBrush="$($C.TextSecondary)" Background="Transparent"/>
                                <Ellipse x:Name="knob" Width="12" Height="12" Fill="$($C.TextSecondary)"
                                         HorizontalAlignment="Left" Margin="4,0,0,0"/>
                            </Grid>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="lbl" Property="Text" Value="Activé"/>
                                <Setter TargetName="track" Property="Background" Value="$($C.Accent)"/>
                                <Setter TargetName="track" Property="BorderBrush" Value="$($C.Accent)"/>
                                <Setter TargetName="knob" Property="Fill" Value="$($C.AccentText)"/>
                                <Setter TargetName="knob" Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="knob" Property="Margin" Value="0,0,4,0"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="knob" Property="Width" Value="14"/>
                                <Setter TargetName="knob" Property="Height" Value="14"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Barre de défilement fine -->
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="MinWidth" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Track x:Name="PART_Track" IsDirectionReversed="True">
                            <Track.Thumb>
                                <Thumb>
                                    <Thumb.Template>
                                        <ControlTemplate TargetType="Thumb">
                                            <Border CornerRadius="3" Background="$($C.TextSecondary)" Opacity="0.45" Margin="3,2"/>
                                        </ControlTemplate>
                                    </Thumb.Template>
                                </Thumb>
                            </Track.Thumb>
                        </Track>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="$($C.Flyout)"/>
            <Setter Property="Foreground" Value="$($C.Text)"/>
            <Setter Property="BorderBrush" Value="$($C.ControlStroke)"/>
        </Style>

        <Style TargetType="ContextMenu">
            <Setter Property="Background" Value="$($C.Flyout)"/>
            <Setter Property="Foreground" Value="$($C.Text)"/>
            <Setter Property="BorderBrush" Value="$($C.ControlStroke)"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Focusable="False">
            <StackPanel Margin="40,28,40,28">
                <TextBlock Text="Configuration des écrans" FontFamily="Segoe UI Variable Display, Segoe UI" FontSize="28" FontWeight="SemiBold"/>
                <TextBlock Text="Choisissez la configuration qui correspond à votre bureau, puis cliquez sur Appliquer."
                           Foreground="$($C.TextSecondary)" Margin="0,4,0,0" TextWrapping="Wrap"/>

                <!-- Configuration sélectionnée -->
                <TextBlock x:Name="txtPreviewTitle" Style="{StaticResource SectionTitle}" Text="Aperçu"/>
                <Border Style="{StaticResource Card}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="270"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Border x:Name="bdPreview" Background="$($C.Illustration)" CornerRadius="5,5,0,0" Padding="32,24"/>
                        <Grid Grid.Row="1" Margin="16,12,16,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="txtPreviewIcon" Style="{StaticResource Icon}" Text="&#xE80F;" FontSize="20" Margin="4,0,16,0"/>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock x:Name="txtPrimaryInfo" TextWrapping="Wrap"/>
                                <TextBlock x:Name="txtDetect" FontSize="12" Foreground="$($C.TextSecondary)" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Grid>
                    </Grid>
                </Border>

                <!-- Choix de la configuration -->
                <Grid Margin="0,28,0,8">
                    <TextBlock Text="Configurations" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    <ToggleButton x:Name="tglFavorites" Style="{StaticResource Chip}" HorizontalAlignment="Right" ToolTip="N'afficher que les configurations favorites">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Style="{StaticResource Icon}" Text="&#xE734;" FontSize="12" Margin="0,0,8,0"/>
                            <TextBlock Text="Favoris uniquement" FontSize="13" VerticalAlignment="Center"/>
                        </StackPanel>
                    </ToggleButton>
                </Grid>
                <StackPanel x:Name="pnlCards"/>
                <TextBlock x:Name="txtNoFavorites" Visibility="Collapsed" Foreground="$($C.TextSecondary)" Margin="0,4,0,0" TextWrapping="Wrap"
                           Text="Aucune configuration favorite. Cliquez sur l'étoile d'une configuration pour l'ajouter aux favoris."/>

                <!-- Paramètres -->
                <TextBlock Style="{StaticResource SectionTitle}" Text="Paramètres"/>
                <Border Style="{StaticResource Card}" Padding="16,12" MinHeight="68" Margin="0,0,0,4">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Style="{StaticResource Icon}" Text="&#xE740;" FontSize="20" Margin="4,0,20,0"/>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock Text="Résolution maximale"/>
                            <TextBlock Text="Lors de l'application, chaque écran passe à sa meilleure résolution (résolution native)."
                                       FontSize="12" Foreground="$($C.TextSecondary)" TextWrapping="Wrap"/>
                        </StackPanel>
                        <CheckBox x:Name="chkMaxRes" Grid.Column="2" Style="{StaticResource ToggleSwitch}" VerticalAlignment="Center" Margin="16,0,0,0"/>
                    </Grid>
                </Border>
                <Border x:Name="bdSwapExternal" Style="{StaticResource Card}" Padding="16,12" MinHeight="68">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Style="{StaticResource Icon}" Text="&#xE8AB;" FontSize="20" Margin="4,0,20,0"/>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock Text="Inverser les écrans externes"/>
                            <TextBlock Text="À activer si la souris ne passe pas naturellement d'un écran externe à l'autre après l'application."
                                       FontSize="12" Foreground="$($C.TextSecondary)" TextWrapping="Wrap"/>
                        </StackPanel>
                        <CheckBox x:Name="chkSwapExternal" Grid.Column="2" Style="{StaticResource ToggleSwitch}" VerticalAlignment="Center" Margin="16,0,0,0"/>
                    </Grid>
                </Border>
            </StackPanel>
        </ScrollViewer>

        <!-- Barre d'action -->
        <Border Grid.Row="1" Background="$($C.Footer)" BorderBrush="$($C.CardBorder)" BorderThickness="0,1,0,0" Padding="40,14,40,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="bdStatus" Visibility="Collapsed" CornerRadius="4" BorderThickness="1" BorderBrush="$($C.CardBorder)"
                        Padding="12,7" Margin="0,0,16,0" HorizontalAlignment="Left" VerticalAlignment="Center">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="txtStatusIcon" Style="{StaticResource Icon}" Margin="0,0,10,0"/>
                        <TextBlock x:Name="txtStatus" Grid.Column="1" TextWrapping="Wrap" VerticalAlignment="Center"/>
                    </Grid>
                </Border>
                <Button x:Name="btnApply" Grid.Column="1" Style="{StaticResource BtnAccent}" Content="Appliquer" MinWidth="130" VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# ========== CHARGEMENT DE LA FENÊTRE ==========
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Récupération des éléments XAML
$pnlCards        = $window.FindName("pnlCards")
$bdPreview       = $window.FindName("bdPreview")
$btnApply        = $window.FindName("btnApply")
$txtStatus       = $window.FindName("txtStatus")
$txtStatusIcon   = $window.FindName("txtStatusIcon")
$bdStatus        = $window.FindName("bdStatus")
$txtPreviewTitle = $window.FindName("txtPreviewTitle")
$txtPreviewIcon  = $window.FindName("txtPreviewIcon")
$txtPrimaryInfo  = $window.FindName("txtPrimaryInfo")
$txtDetect       = $window.FindName("txtDetect")
$tglFavorites    = $window.FindName("tglFavorites")
$txtNoFavorites  = $window.FindName("txtNoFavorites")
$chkMaxRes       = $window.FindName("chkMaxRes")
$chkSwapExternal = $window.FindName("chkSwapExternal")
$bdSwapExternal  = $window.FindName("bdSwapExternal")

# ========== FONCTIONS D'AFFICHAGE ==========
$script:StatusStyles = @{
    Info    = @{ Glyph = [string][char]0xE946; Bg = $C.InfoBg;    Fg = $C.Accent }
    Busy    = @{ Glyph = [string][char]0xE895; Bg = $C.InfoBg;    Fg = $C.Accent }
    Success = @{ Glyph = [string][char]0xE73E; Bg = $C.SuccessBg; Fg = $C.SuccessFg }
    Warning = @{ Glyph = [string][char]0xE7BA; Bg = $C.WarningBg; Fg = $C.WarningFg }
    Error   = @{ Glyph = [string][char]0xE783; Bg = $C.ErrorBg;   Fg = $C.ErrorFg }
}

# Barre d'information façon Windows 11 ; "None" la masque
Function Set-Status {
    param(
        [string]$Text,
        [ValidateSet('None', 'Info', 'Busy', 'Success', 'Warning', 'Error')]
        [string]$Severity = 'Info'
    )

    If ($Severity -eq 'None' -or -not $Text) {
        $bdStatus.Visibility = "Collapsed"
        return
    }
    $style = $script:StatusStyles[$Severity]
    $bdStatus.Background = New-Brush $style.Bg
    $txtStatusIcon.Text = $style.Glyph
    $txtStatusIcon.Foreground = New-Brush $style.Fg
    $txtStatus.Text = $Text
    $bdStatus.Visibility = "Visible"
}

# Icône de fenêtre dessinée à partir d'un glyphe Windows (aucun fichier externe)
Function New-GlyphImage {
    param([string]$Glyph, [string]$Color, [int]$Size = 64)

    $tb = [System.Windows.Controls.TextBlock]::new()
    $tb.Text = $Glyph
    $tb.FontFamily = [System.Windows.Media.FontFamily]::new($script:IconFont)
    $tb.FontSize = $Size * 0.85
    $tb.Foreground = New-Brush $Color
    $tb.HorizontalAlignment = "Center"
    $tb.VerticalAlignment = "Center"

    $box = [System.Windows.Controls.Grid]::new()
    $box.Width = $Size; $box.Height = $Size
    $box.Children.Add($tb) | Out-Null
    $box.Measure([System.Windows.Size]::new($Size, $Size))
    $box.Arrange([System.Windows.Rect]::new(0, 0, $Size, $Size))

    $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($box)
    $bitmap.Freeze()
    return $bitmap
}

# Image d'une configuration (dossier images\ à côté du script), chargée une seule fois ; $null si absente
$script:ImageCache = @{}
Function Get-ConfigImage {
    param($Config)

    If ($script:ImageCache.ContainsKey($Config.Key)) { return $script:ImageCache[$Config.Key] }
    $image = $null
    $path = Join-Path $script:ImageDir $Config.Image
    If (Test-Path -LiteralPath $path) {
        Try {
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.UriSource = [System.Uri]::new($path)
            $bitmap.EndInit()
            $bitmap.Freeze()
            $image = $bitmap
        } Catch {
            Write-Warning "Image illisible : $path"
        }
    }
    $script:ImageCache[$Config.Key] = $image
    return $image
}

# Visuel d'une configuration ; message de remplacement si l'image est introuvable
Function New-ConfigVisual {
    param($Config, [bool]$Large = $false)

    $source = Get-ConfigImage -Config $Config
    If ($source) {
        $img = [System.Windows.Controls.Image]::new()
        $img.Source = $source
        $img.Stretch = "Uniform"
        [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($img, [System.Windows.Media.BitmapScalingMode]::HighQuality)
        return $img
    }

    $missing = [System.Windows.Controls.TextBlock]::new()
    $missing.Text = "Image introuvable : images\$($Config.Image)"
    $missing.Foreground = New-Brush '#5F5F5F'
    $missing.FontSize = $(If ($Large) { 14 } Else { 11 })
    $missing.TextWrapping = "Wrap"
    $missing.TextAlignment = "Center"
    $missing.HorizontalAlignment = "Center"
    $missing.VerticalAlignment = "Center"
    return $missing
}

Function Switch-Favorite {
    param([int]$LayoutIndex)

    $script:Configs[$LayoutIndex].Favorite = -not $script:Configs[$LayoutIndex].Favorite
    Save-Settings
    Build-Cards
}

# Carte d'une configuration : vignette, nom, description et étoile favoris
Function New-ConfigCard {
    param([int]$Index)

    $config = $script:Configs[$Index]
    $isSelected = ($Index -eq $script:SelectedLayoutIndex)

    # Carte sélectionnable : bordure d'accent quand elle est choisie (épaisseur compensée par le padding)
    $card = [System.Windows.Controls.Border]::new()
    $card.Width = 214
    $card.Margin = [System.Windows.Thickness]::new(4)
    $card.CornerRadius = [System.Windows.CornerRadius]::new(6)
    $card.Background = New-Brush $C.Card
    If ($isSelected) {
        $card.BorderBrush = New-Brush $C.Accent
        $card.BorderThickness = [System.Windows.Thickness]::new(2)
        $card.Padding = [System.Windows.Thickness]::new(9)
    } Else {
        $card.BorderBrush = New-Brush $C.CardBorder
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.Padding = [System.Windows.Thickness]::new(10)
    }
    $card.Tag = $Index
    $card.ToolTip = "Choisir la configuration $($config.Name)"

    $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
    $miFav = [System.Windows.Controls.MenuItem]::new()
    If ($config.Favorite) {
        $miFav.Header = "Retirer des favoris"
    } Else {
        $miFav.Header = "Ajouter aux favoris"
    }
    $miFav.Tag = $Index
    $miFav.Add_Click({
        param($sender, $e)
        Switch-Favorite -LayoutIndex $sender.Tag
    })
    $ctxMenu.Items.Add($miFav) | Out-Null
    $card.ContextMenu = $ctxMenu

    $grid = [System.Windows.Controls.Grid]::new()
    $row1 = [System.Windows.Controls.RowDefinition]::new(); $row1.Height = [System.Windows.GridLength]::Auto
    $row2 = [System.Windows.Controls.RowDefinition]::new(); $row2.Height = [System.Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($row1)
    $grid.RowDefinitions.Add($row2)

    # Vignette
    $thumb = [System.Windows.Controls.Border]::new()
    $thumb.Height = 96
    $thumb.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $thumb.Background = New-Brush $C.Illustration
    $thumb.Padding = [System.Windows.Thickness]::new(8)
    $thumb.Child = New-ConfigVisual -Config $config
    $grid.Children.Add($thumb) | Out-Null

    # Nom, description et étoile favoris
    $labelRow = [System.Windows.Controls.Grid]::new()
    $labelRow.Margin = [System.Windows.Thickness]::new(2, 10, 0, 0)
    $col1 = [System.Windows.Controls.ColumnDefinition]::new()
    $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $col2 = [System.Windows.Controls.ColumnDefinition]::new()
    $col2.Width = [System.Windows.GridLength]::Auto
    $labelRow.ColumnDefinitions.Add($col1)
    $labelRow.ColumnDefinitions.Add($col2)
    [System.Windows.Controls.Grid]::SetRow($labelRow, 1)

    $texts = [System.Windows.Controls.StackPanel]::new()
    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = $config.Name
    $title.FontWeight = If ($isSelected) { "SemiBold" } Else { "Normal" }
    $texts.Children.Add($title) | Out-Null
    $desc = [System.Windows.Controls.TextBlock]::new()
    $desc.Text = $config.Description
    $desc.FontSize = 12
    $desc.Foreground = New-Brush $C.TextSecondary
    $desc.TextWrapping = "Wrap"
    $texts.Children.Add($desc) | Out-Null
    $labelRow.Children.Add($texts) | Out-Null

    $star = [System.Windows.Controls.Button]::new()
    $star.Style = $window.FindResource("BtnIcon")
    $star.VerticalAlignment = "Top"
    $star.Margin = [System.Windows.Thickness]::new(4, -4, -4, 0)
    $starGlyph = [System.Windows.Controls.TextBlock]::new()
    $starGlyph.FontFamily = [System.Windows.Media.FontFamily]::new($script:IconFont)
    $starGlyph.FontSize = 16
    If ($config.Favorite) {
        $starGlyph.Text = [string][char]0xE735
        $starGlyph.Foreground = New-Brush $C.Accent
        $star.ToolTip = "Retirer des favoris"
    } Else {
        $starGlyph.Text = [string][char]0xE734
        $starGlyph.Foreground = New-Brush $C.TextSecondary
        $star.ToolTip = "Ajouter aux favoris"
    }
    [System.Windows.Automation.AutomationProperties]::SetName($star, $star.ToolTip)
    $star.Content = $starGlyph
    $star.Tag = $Index
    $star.Add_Click({
        param($sender, $e)
        Switch-Favorite -LayoutIndex $sender.Tag
    })
    [System.Windows.Controls.Grid]::SetColumn($star, 1)
    $labelRow.Children.Add($star) | Out-Null
    $grid.Children.Add($labelRow) | Out-Null

    $card.Child = $grid

    $card.Add_MouseEnter({
        param($sender, $e)
        If ($sender.Tag -ne $script:SelectedLayoutIndex) { $sender.Background = New-Brush $C.CardHover }
    })
    $card.Add_MouseLeave({
        param($sender, $e)
        $sender.Background = New-Brush $C.Card
    })
    $card.Add_MouseLeftButtonDown({
        param($sender, $e)
        $script:SelectedLayoutIndex = $sender.Tag
        Set-Status "" "None"
        Build-Cards
        Update-Preview
    })

    return $card
}

# Titre d'un groupe de configurations, avec un badge si ce poste est celui détecté
Function New-DeviceHeader {
    param($Device)

    $header = [System.Windows.Controls.StackPanel]::new()
    $header.Orientation = "Horizontal"
    $header.Margin = [System.Windows.Thickness]::new(0, 12, 0, 6)

    $name = [System.Windows.Controls.TextBlock]::new()
    $name.Text = $Device.Name
    $name.FontSize = 13
    $name.Foreground = New-Brush $C.TextSecondary
    $name.VerticalAlignment = "Center"
    $header.Children.Add($name) | Out-Null

    If ($script:DetectedDevice -eq $Device.Key) {
        $badgeText = [System.Windows.Controls.TextBlock]::new()
        $badgeText.Text = "Détecté"
        $badgeText.FontSize = 11
        $badgeText.Foreground = New-Brush $C.AccentText
        $badge = [System.Windows.Controls.Border]::new()
        $badge.Background = New-Brush $C.Accent
        $badge.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $badge.Padding = [System.Windows.Thickness]::new(8, 1, 8, 2)
        $badge.Margin = [System.Windows.Thickness]::new(10, 0, 0, 0)
        $badge.VerticalAlignment = "Center"
        $badge.Child = $badgeText
        $header.Children.Add($badge) | Out-Null
    }
    return $header
}

Function Build-Cards {
    $pnlCards.Children.Clear()

    If ($script:ShowFavoritesOnly -and -not $script:Configs[$script:SelectedLayoutIndex].Favorite) {
        $favorite = @(Get-CompatibleConfigIndexes | Where-Object { $script:Configs[$_].Favorite }) | Select-Object -First 1
        If ($null -ne $favorite) { $script:SelectedLayoutIndex = $favorite }
    }

    # Aucun poste reconnu : toutes les configurations restent proposées, avec une explication
    If (-not $script:DetectedDevice) {
        $hint = [System.Windows.Controls.TextBlock]::new()
        $hint.Text = "Aucun poste reconnu pour le moment : toutes les configurations sont proposées. Branchez les écrans de votre poste, la liste s'adaptera automatiquement."
        $hint.FontSize = 12
        $hint.Foreground = New-Brush $C.TextSecondary
        $hint.TextWrapping = "Wrap"
        $pnlCards.Children.Add($hint) | Out-Null
    }

    # Un groupe par poste ; seul le poste détecté est proposé quand il est reconnu
    $shown = 0
    ForEach ($device In $script:Devices) {
        If ($script:DetectedDevice -and $device.Key -ne $script:DetectedDevice) { continue }
        $wrap = [System.Windows.Controls.WrapPanel]::new()
        $wrap.Margin = [System.Windows.Thickness]::new(-4, 0, -4, 0)
        For ($i = 0; $i -lt $script:Configs.Count; $i++) {
            $config = $script:Configs[$i]
            If ($config.Device -ne $device.Key) { continue }
            If ($script:ShowFavoritesOnly -and -not $config.Favorite) { continue }
            $wrap.Children.Add((New-ConfigCard -Index $i)) | Out-Null
        }
        If ($wrap.Children.Count -eq 0) { continue }

        $shown += $wrap.Children.Count
        $pnlCards.Children.Add((New-DeviceHeader -Device $device)) | Out-Null
        $pnlCards.Children.Add($wrap) | Out-Null
    }

    $txtNoFavorites.Visibility = If ($shown -eq 0) { "Visible" } Else { "Collapsed" }
}

# Grande image de la configuration choisie, écran principal et écrans branchés
Function Update-Preview {
    $config = $script:Configs[$script:SelectedLayoutIndex]
    $txtPreviewTitle.Text = "Aperçu : $($config.Name)"
    $bdPreview.Child = New-ConfigVisual -Config $config -Large $true
    $txtPrimaryInfo.Text = "Écran principal : $($config.PrimaryLabel)"

    # L'inversion des écrans externes ne concerne que le poste à deux écrans
    $bdSwapExternal.Visibility = If ($config.Device -eq "Dual") { "Visible" } Else { "Collapsed" }

    $screens = @(Get-ConnectedScreens)
    $count = $screens.Count
    $internal = @($screens | Where-Object { $_.IsInternal }).Count
    $external = $count - $internal
    $inactive = @($script:Monitors | Where-Object { -not $_.IsActive }).Count
    If ($count -lt $config.MinScreens -or $external -lt $config.MinExternal) {
        $txtPreviewIcon.Text = [string][char]0xE7BA
        $txtPreviewIcon.Foreground = New-Brush $C.WarningFg
        $hint = $config.MissingHint.Substring(0, 1).ToUpper() + $config.MissingHint.Substring(1)
        $txtDetect.Text = "Écrans attendus non détectés pour le moment ($external externe(s) sur $($config.MinExternal)). $hint."
    } Else {
        $txtPreviewIcon.Text = [string][char]0xE80F
        $txtPreviewIcon.Foreground = New-Brush $C.Text
        $parts = @()
        If ($external -gt 0) { $parts += "$external externe(s)" }
        If ($internal -gt 0) { $parts += "l'écran du portable" }
        $txtDetect.Text = "$count écran(s) branché(s) : $($parts -join ' + ')."
        If ($inactive -gt 0) { $txtDetect.Text += " $inactive éteint(s) pour le moment." }
    }
    $txtDetect.ToolTip = (@(For ($i = 0; $i -lt $script:Displays.Count; $i++) {
        $d = $script:Displays[$i]
        $roles = @()
        If ($d.IsInternal) { $roles += "portable" }
        If ($d.IsPrimary) { $roles += "principal actuel" }
        $suffix = If ($roles.Count -gt 0) { " ($($roles -join ', '))" } Else { "" }
        "$($i + 1). $((Get-DisplayLabel -Index $i) -replace "`n", ' · ')$suffix"
    }) -join "`n")
}

# Suivi des écrans en temps réel : relit l'état des écrans et ne met l'interface à jour que s'il a changé.
# Quand le poste reconnu change, seules ses configurations sont proposées et la sélection s'adapte.
Function Invoke-DisplayRefresh {
    param(
        [switch]$Force,
        [switch]$Quiet
    )

    $previousSignature = $script:DisplaySignature
    $previousDevice = $script:DetectedDevice
    Update-DisplayInfo
    If (-not $Force -and $script:DisplaySignature -eq $previousSignature) { return }

    $script:DetectedDevice = Get-DetectedDevice
    If ($script:DetectedDevice -ne $previousDevice) {
        Select-CompatibleConfig -KeepCurrent
        If (-not $Quiet) {
            If ($script:DetectedDevice) {
                $deviceName = ($script:Devices | Where-Object { $_.Key -eq $script:DetectedDevice }).Name
                Set-Status "$deviceName détecté : seules les configurations compatibles sont proposées." "Info"
            } Else {
                Set-Status "Aucun poste reconnu : toutes les configurations sont proposées." "Info"
            }
        }
    }
    Build-Cards
    Update-Preview
}

Function Set-LayoutFromGui {
    $config = $script:Configs[$script:SelectedLayoutIndex]
    $script:LastResolutionChanges = @()

    Try {
        # Avec la résolution maximale, chaque écran y passe d'abord ; la disposition est calculée avec ces tailles
        $result = Invoke-ScreenConfiguration -Config $config -MaxResolution:([bool]$script:UseMaxResolution) -SwapExternal:([bool]$script:SwapExternal)

        $applied = @($result)
        $resolutionChanged = @($script:LastResolutionChanges | Where-Object { $_.Changed }).Count
        $resolutionFailed  = @($script:LastResolutionChanges | Where-Object { $_.NeedsChange -and -not $_.Changed }).Count

        If ($applied.Count -eq 0 -or $applied[-1] -ne $true) {
            Set-Status "Échec de l'application de $($config.Name) (code $([DisplayApi]::LastResult))." "Error"
        } Else {
            $text = "Configuration $($config.Name) appliquée"
            If ($resolutionChanged -gt 0) { $text += " ($resolutionChanged écran(s) passé(s) en résolution maximale)" }

            $notes = @()
            If ($script:LastLayoutWarning) { $notes += "l'écran principal n'a pas pu être défini (détails : $script:DiagnosticPath)" }
            If ($resolutionFailed -gt 0) { $notes += "résolution maximale refusée sur $resolutionFailed écran(s)" }

            If ($notes.Count -gt 0) {
                Set-Status "$text, mais $($notes -join ' et ')." "Warning"
            } Else {
                # Écran principal réellement retenu par Windows, pour vérification visuelle
                $primaryNow = [DisplayApi]::GetSources() | Where-Object { $_.IsPrimary } | Select-Object -First 1
                $primaryText = If (-not $primaryNow) { "" } ElseIf ($primaryNow.IsInternal) { " Écran principal : écran du portable." } Else { " Écran principal : $(Get-ScreenName -Screen $primaryNow)." }
                If ($script:LastIconsMoved -gt 0) { $primaryText += " Icônes du bureau replacées dessus." }
                Set-Status "$text.$primaryText" "Success"
            }
        }
    }
    Catch {
        Set-Status "Erreur : $($_.Exception.Message)" "Error"
    }

    # Le message d'application reste affiché, même si le poste reconnu a changé
    Invoke-DisplayRefresh -Force -Quiet
}

# ========== ÉVÉNEMENTS ==========
$window.Icon = New-GlyphImage -Glyph ([string][char]0xE7F4) -Color $C.Accent
$chkMaxRes.IsChecked = [bool]$script:UseMaxResolution
$chkSwapExternal.IsChecked = [bool]$script:SwapExternal

$btnApply.Add_Click({
    # Affiche l'état "en cours" avant de lancer l'application, qui bloque l'interface quelques secondes
    $btnApply.IsEnabled = $false
    Set-Status "Application de la configuration en cours..." "Busy"
    $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{
        Try { Set-LayoutFromGui } Finally { $btnApply.IsEnabled = $true }
    }) | Out-Null
})

$tglFavorites.Add_Click({
    $script:ShowFavoritesOnly = [bool]$tglFavorites.IsChecked
    Build-Cards
    Update-Preview
})

$chkMaxRes.Add_Click({
    $script:UseMaxResolution = [bool]$chkMaxRes.IsChecked
    Save-Settings
})

$chkSwapExternal.Add_Click({
    $script:SwapExternal = [bool]$chkSwapExternal.IsChecked
    Save-Settings
})

# Barre de titre assortie au thème et fond Mica sous Windows 11
$window.Add_SourceInitialized({
    $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
    If ([DisplayApi]::ApplyWindowStyle($hwnd, $script:IsDark, $script:UseMica)) {
        $window.Background = [System.Windows.Media.Brushes]::Transparent
        [System.Windows.Interop.HwndSource]::FromHwnd($hwnd).CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
    }
})

# Surveillance des écrans toutes les 2 secondes (branchement, débranchement, portable ouvert ou fermé)
$script:DisplayWatcher = [System.Windows.Threading.DispatcherTimer]::new()
$script:DisplayWatcher.Interval = [System.TimeSpan]::FromSeconds(2)
$script:DisplayWatcher.Add_Tick({
    # Pas de rafraîchissement pendant l'application d'une configuration
    If (-not $btnApply.IsEnabled) { return }
    Try { Invoke-DisplayRefresh } Catch { Write-Warning "Suivi des écrans : $($_.Exception.Message)" }
})

$window.Add_ContentRendered({
    Build-Cards
    Update-Preview
    $script:DisplayWatcher.Start()
})

# Retour sur la fenêtre : vérification immédiate, sans attendre le prochain cycle
$window.Add_Activated({
    If (-not $btnApply.IsEnabled) { return }
    Try { Invoke-DisplayRefresh } Catch { Write-Warning "Suivi des écrans : $($_.Exception.Message)" }
})

$window.Add_Closed({
    $script:DisplayWatcher.Stop()
})

# ========== AFFICHER LA FENÊTRE ==========
$window.ShowDialog() | Out-Null
