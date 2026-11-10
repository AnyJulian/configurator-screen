# ScreenConfig-Final.ps1
$ErrorActionPreference = 'Stop'

# ========== CHARGEMENT DES ASSEMBLIES WPF ==========
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ========== INTÉGRATION DE DisplayApi ==========
$displayApiType = ([System.Management.Automation.PSTypeName]'DisplayApi').Type
If ($displayApiType -and (-not $displayApiType.GetField('Version') -or $displayApiType.GetField('Version').GetValue($null) -lt 4)) {
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
    public const int Version = 4;

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

    const uint QDC_ONLY_ACTIVE_PATHS              = 0x00000002;
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

        // Windows place toujours l'écran principal à l'origine du bureau
        public bool IsPrimary { get { return X == 0 && Y == 0; } }
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

                var pref = new DISPLAYCONFIG_TARGET_PREFERRED_MODE();
                pref.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE;
                pref.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_PREFERRED_MODE));
                pref.header.adapterId = ti.adapterId;
                pref.header.id = ti.id;
                if (DisplayConfigGetDeviceInfo(ref pref) == 0)
                {
                    info.PreferredWidth = (int)pref.width;
                    info.PreferredHeight = (int)pref.height;
                }

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

# ========== DONNÉES DES LAYOUTS ==========
# SourceMap[i] = index (dans [DisplayApi]::GetSources()) de l'écran placé dans l'emplacement i ; Screens[i].Id = SourceMap[i] + 1
# X / Y / W / H : modèle d'aperçu utilisé tant que les écrans ne sont pas tous détectés
$script:Layouts = @(
    @{
        Name        = "T-shape"
        Description = "Deux écrans en haut, un centré en dessous"
        LayoutKey   = "T"
        Favorite    = $true
        SourceMap   = @(1, 2, 0)
        Screens     = @(
            @{ Id = 2; X = 0;   Y = 0;   W = 140; H = 90; Primary = $false }
            @{ Id = 3; X = 140; Y = 0;   W = 140; H = 90; Primary = $false }
            @{ Id = 1; X = 70;  Y = 90;  W = 140; H = 90; Primary = $true  }
        )
    },
    @{
        Name        = "Full line"
        Description = "Tous les écrans alignés côte à côte"
        LayoutKey   = "Horizontal"
        Favorite    = $false
        SourceMap   = @(0, 1, 2)
        Screens     = @(
            @{ Id = 1; X = 0;   Y = 0; W = 120; H = 90; Primary = $false }
            @{ Id = 2; X = 120; Y = 0; W = 120; H = 90; Primary = $false }
            @{ Id = 3; X = 240; Y = 0; W = 120; H = 90; Primary = $true  }
        )
    },
    @{
        Name        = "Line-out"
        Description = "Deux écrans côte à côte, un plus petit à droite"
        LayoutKey   = "LineOut"
        Favorite    = $false
        SourceMap   = @(0, 1, 2)
        Screens     = @(
            @{ Id = 1; X = 0;   Y = 0;  W = 140; H = 90; Primary = $true  }
            @{ Id = 2; X = 140; Y = 0;  W = 140; H = 90; Primary = $false }
            @{ Id = 3; X = 280; Y = 30; W = 80;  H = 60; Primary = $false }
        )
    }
)

# ========== PRÉFÉRENCES (favoris, échanges, écran principal, résolution maximale) ==========
$script:SettingsPath = Join-Path $env:APPDATA "ScreenConfig\settings.json"
$script:UseMaxResolution = $true

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
        $data = @{ Layouts = $saved; MaxResolution = [bool]$script:UseMaxResolution }
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
$script:LastResolutionChanges = @()

# ========== ÉCRANS CONNECTÉS ==========
$script:Displays = @()
$script:MaxModes = @{}

Function Update-DisplayInfo {
    Try { $list = [DisplayApi]::GetSources() } Catch { $list = $null }
    $script:Displays = @(If ($list) { $list })

    # Résolution maximale prévue pour chaque écran (lecture seule)
    $script:MaxModes = @{}
    Try {
        ForEach ($change In @([DisplayApi]::GetMaxResolutionPlan())) {
            If ($change) { $script:MaxModes[$change.GdiDeviceName] = $change }
        }
    } Catch { }
}

Function Get-DisplayName {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "Non détecté" }
    $d = $script:Displays[$Index]
    $name = $d.FriendlyName
    If (-not $name -and $d.Edid -and $d.Edid.Model -ne "Unknown") { $name = $d.Edid.Model }
    If (-not $name -and $d.PnpId) { $name = $d.PnpId }
    If (-not $name) { $name = "Écran" }
    return $name
}

# Taille que l'écran aura une fois la configuration appliquée
Function Get-DisplayTargetSize {
    param([int]$Index)

    $d = $script:Displays[$Index]
    $width = $d.Width; $height = $d.Height
    If ($script:UseMaxResolution -and $script:MaxModes.ContainsKey($d.GdiDeviceName)) {
        $width = $script:MaxModes[$d.GdiDeviceName].NewWidth
        $height = $script:MaxModes[$d.GdiDeviceName].NewHeight
    }
    return [pscustomobject]@{ Width = $width; Height = $height }
}

# "1920 × 1080", ou "1920 × 1080 → 2560 × 1440" si la résolution maximale va la changer
Function Get-DisplayResolutionText {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "" }
    $d = $script:Displays[$Index]
    $target = Get-DisplayTargetSize -Index $Index
    $text = "$($d.Width) × $($d.Height)"
    If ($target.Width -ne $d.Width -or $target.Height -ne $d.Height) { $text += " → $($target.Width) × $($target.Height)" }
    return $text
}

# Nom + résolution de l'écran d'index $Index (même numérotation que les layouts : Id = index + 1)
Function Get-DisplayLabel {
    param([int]$Index)

    If ($Index -lt 0 -or $Index -ge $script:Displays.Count) { return "Non détecté" }
    $d = $script:Displays[$Index]
    return "$(Get-DisplayName -Index $Index)`n$($d.Width) × $($d.Height)"
}

# Écrans à dessiner pour un layout : vraies proportions si tous ses écrans sont connectés, sinon le modèle
Function Get-PreviewScreens {
    param($Layout)

    $sizes = @()
    ForEach ($sourceIdx In $Layout.SourceMap) {
        If ($sourceIdx -ge $script:Displays.Count) { $sizes = $null; break }
        $sizes += Get-DisplayTargetSize -Index $sourceIdx
    }

    $screens = @()
    If ($sizes) {
        $geometry = Get-LayoutGeometry -LayoutKey $Layout.LayoutKey -Slots $sizes
        For ($i = 0; $i -lt $Layout.Screens.Count; $i++) {
            $screens += @{
                Id = $Layout.Screens[$i].Id; Primary = $Layout.Screens[$i].Primary
                X = $geometry[$i][0]; Y = $geometry[$i][1]; W = $sizes[$i].Width; H = $sizes[$i].Height
            }
        }
    } Else {
        ForEach ($s In $Layout.Screens) {
            $screens += @{ Id = $s.Id; Primary = $s.Primary; X = $s.X; Y = $s.Y; W = $s.W; H = $s.H }
        }
    }
    return , $screens
}

Update-DisplayInfo

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
If ($script:IsDark) {
    $accent = $accentPalette[1]
    $C = @{
        Bg = '#202020'; Text = '#FFFFFF'; TextSecondary = '#CFCFCF'
        Card = '#0DFFFFFF'; CardHover = '#15FFFFFF'; CardBorder = '#19000000'; Footer = '#0DFFFFFF'
        ControlFill = '#0FFFFFFF'; ControlHover = '#15FFFFFF'; ControlPressed = '#08FFFFFF'; ControlStroke = '#17FFFFFF'
        Subtle = '#0FFFFFFF'; SubtlePressed = '#0AFFFFFF'; Flyout = '#2C2C2C'
        PreviewBg = '#26000000'; TileFill = '#3F3F3F'; TileStroke = '#26FFFFFF'
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
        PreviewBg = '#0A000000'; TileFill = '#FFFFFF'; TileStroke = '#33000000'
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
    Width="980" Height="860"
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

        <!-- Bouton bascule en forme de pastille (filtre favoris, choix de l'écran principal) -->
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
                <TextBlock Text="Choisissez une disposition, réorganisez vos écrans si besoin, puis cliquez sur Appliquer."
                           Foreground="$($C.TextSecondary)" Margin="0,4,0,0" TextWrapping="Wrap"/>

                <!-- Aperçu de la disposition -->
                <TextBlock x:Name="txtPreviewTitle" Style="{StaticResource SectionTitle}" Text="Aperçu"/>
                <Border Style="{StaticResource Card}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="280"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Border Background="$($C.PreviewBg)" CornerRadius="5,5,0,0">
                            <Canvas x:Name="cvPreview" ClipToBounds="True" Background="Transparent"/>
                        </Border>
                        <Grid Grid.Row="1" Margin="16,12,16,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Style="{StaticResource Icon}" Text="&#xE946;" Foreground="$($C.TextSecondary)" Margin="0,0,10,0"/>
                            <TextBlock x:Name="txtHint" Grid.Column="1" Foreground="$($C.TextSecondary)" FontSize="12"
                                       TextWrapping="Wrap" VerticalAlignment="Center"/>
                            <Button x:Name="btnIdentify" Grid.Column="2" Style="{StaticResource BtnStandard}" Content="Identifier" Margin="16,0,0,0"/>
                        </Grid>
                    </Grid>
                </Border>

                <!-- Choix de la disposition -->
                <Grid Margin="0,28,0,8">
                    <TextBlock Text="Disposition" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    <ToggleButton x:Name="tglFavorites" Style="{StaticResource Chip}" HorizontalAlignment="Right" ToolTip="N'afficher que les dispositions favorites">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Style="{StaticResource Icon}" Text="&#xE734;" FontSize="12" Margin="0,0,8,0"/>
                            <TextBlock Text="Favoris uniquement" FontSize="13" VerticalAlignment="Center"/>
                        </StackPanel>
                    </ToggleButton>
                </Grid>
                <WrapPanel x:Name="pnlCards" Margin="-4,0,-4,0"/>
                <TextBlock x:Name="txtNoFavorites" Visibility="Collapsed" Foreground="$($C.TextSecondary)" Margin="0,4,0,0" TextWrapping="Wrap"
                           Text="Aucune disposition favorite. Cliquez sur l'étoile d'une disposition pour l'ajouter aux favoris."/>

                <!-- Paramètres -->
                <TextBlock Style="{StaticResource SectionTitle}" Text="Paramètres"/>
                <Border Style="{StaticResource Card}" Padding="16,12" MinHeight="68" Margin="0,0,0,4">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Style="{StaticResource Icon}" Text="&#xE7F4;" FontSize="20" Margin="4,0,20,0"/>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock Text="Écran principal"/>
                            <TextBlock Text="La barre des tâches et les nouvelles fenêtres s'affichent sur cet écran."
                                       FontSize="12" Foreground="$($C.TextSecondary)" TextWrapping="Wrap"/>
                        </StackPanel>
                        <StackPanel x:Name="pnlPrimary" Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0"/>
                    </Grid>
                </Border>
                <Border Style="{StaticResource Card}" Padding="16,12" MinHeight="68">
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
$cvPreview       = $window.FindName("cvPreview")
$btnApply        = $window.FindName("btnApply")
$btnIdentify     = $window.FindName("btnIdentify")
$txtStatus       = $window.FindName("txtStatus")
$txtStatusIcon   = $window.FindName("txtStatusIcon")
$bdStatus        = $window.FindName("bdStatus")
$txtPreviewTitle = $window.FindName("txtPreviewTitle")
$txtHint         = $window.FindName("txtHint")
$tglFavorites    = $window.FindName("tglFavorites")
$txtNoFavorites  = $window.FindName("txtNoFavorites")
$pnlPrimary      = $window.FindName("pnlPrimary")
$chkMaxRes       = $window.FindName("chkMaxRes")

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

Function New-TextBlock {
    param(
        [string]$Text,
        [string]$Color,
        [double]$Size = 14,
        [string]$Weight = "Normal",
        [string]$Font = ""
    )

    $tb = [System.Windows.Controls.TextBlock]::new()
    $tb.Text = $Text
    $tb.Foreground = New-Brush $Color
    $tb.FontSize = $Size
    $tb.FontWeight = $Weight
    If ($Font) { $tb.FontFamily = [System.Windows.Media.FontFamily]::new($Font) }
    $tb.HorizontalAlignment = "Center"
    $tb.TextAlignment = "Center"
    $tb.TextTrimming = "CharacterEllipsis"
    return $tb
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

Function Invoke-ScreenSwap {
    param([int]$IndexA, [int]$IndexB)

    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    $idA = $layout.Screens[$IndexA].Id
    $idB = $layout.Screens[$IndexB].Id
    Swap-ScreenSlots -IndexA $IndexA -IndexB $IndexB
    $script:SelectedSwapIndex = -1
    Save-Settings
    Set-Status "Écrans $idA et $idB échangés. Cliquez sur Appliquer pour valider." "Success"
    Update-Preview
    Build-Cards
}

Function Set-PrimaryScreen {
    param([int]$ScreenId)

    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    ForEach ($s In $layout.Screens) {
        $s.Primary = ($s.Id -eq $ScreenId)
    }
    Save-Settings
    Set-Status "Écran $ScreenId défini comme écran principal. Cliquez sur Appliquer pour valider." "Info"
    Update-Preview
    Build-Cards
}

# Clic simple sur un écran de l'aperçu : sélection, puis échange avec le deuxième écran cliqué
Function Invoke-TileClick {
    param([int]$Index)

    If ($script:SelectedSwapIndex -lt 0) {
        $script:SelectedSwapIndex = $Index
        $selId = $script:Layouts[$script:SelectedLayoutIndex].Screens[$Index].Id
        Set-Status ([string]::Format("Écran {0} sélectionné. Cliquez sur un autre écran pour les échanger.", $selId)) "Info"
        Update-Preview
    } ElseIf ($script:SelectedSwapIndex -eq $Index) {
        $script:SelectedSwapIndex = -1
        Set-Status "" "None"
        Update-Preview
    } Else {
        Invoke-ScreenSwap -IndexA $script:SelectedSwapIndex -IndexB $Index
    }
}

# Emplacement de l'aperçu situé sous le point (en ignorant l'écran en cours de déplacement)
Function Get-PreviewSlotAt {
    param([System.Windows.Point]$Point, [int]$Exclude = -1)

    ForEach ($slot In $script:PreviewSlots) {
        If ($slot.Index -eq $Exclude) { continue }
        If ($Point.X -ge $slot.X -and $Point.X -le ($slot.X + $slot.W) -and $Point.Y -ge $slot.Y -and $Point.Y -le ($slot.Y + $slot.H)) {
            return $slot.Index
        }
    }
    return -1
}

Function Set-TileHighlight {
    param([int]$Index, [bool]$On)

    $info = $script:PreviewTiles[$Index]
    If (-not $info) { return }
    If ($On) {
        $info.Tile.BorderBrush = New-Brush $info.Highlight
        $info.Tile.BorderThickness = [System.Windows.Thickness]::new(3)
    } Else {
        $info.Tile.BorderBrush = $info.Stroke
        $info.Tile.BorderThickness = $info.Thickness
    }
}

Function Draw-ScreenRect {
    param(
        $Canvas,
        [double]$X, [double]$Y, [double]$W, [double]$H,
        $Screen,
        [int]$ScreenIndex = -1,
        [bool]$Mini = $false
    )

    $isPrimary = [bool]$Screen.Primary
    $isSelected = (-not $Mini -and $ScreenIndex -ge 0 -and $ScreenIndex -eq $script:SelectedSwapIndex)

    $fill = If ($isPrimary) { $C.Accent } Else { $C.TileFill }
    $textColor = If ($isPrimary) { $C.AccentText } Else { $C.Text }
    $highlight = If ($isPrimary) { $C.Text } Else { $C.Accent }
    If ($isSelected) {
        $stroke = $highlight
    } ElseIf ($isPrimary) {
        $stroke = $C.Accent
    } Else {
        $stroke = $C.TileStroke
    }

    $tile = [System.Windows.Controls.Border]::new()
    $tile.Width  = [Math]::Max($W, 2)
    $tile.Height = [Math]::Max($H, 2)
    $tile.Background = New-Brush $fill
    $tile.BorderBrush = New-Brush $stroke
    $tile.BorderThickness = [System.Windows.Thickness]::new($(If ($isSelected) { 3 } Else { 1 }))
    $tile.CornerRadius = [System.Windows.CornerRadius]::new($(If ($Mini) { 2 } Else { 6 }))
    $tile.SnapsToDevicePixels = $true

    $stack = [System.Windows.Controls.StackPanel]::new()
    $stack.HorizontalAlignment = "Center"
    $stack.VerticalAlignment = "Center"
    $stack.IsHitTestVisible = $false

    If ($Mini) {
        $numberSize = [Math]::Max([Math]::Min($H * 0.45, 13), 8)
    } Else {
        $numberSize = [Math]::Max([Math]::Min($H / 3.5, 40), 14)
    }
    $stack.Children.Add((New-TextBlock -Text "$($Screen.Id)" -Color $textColor -Size $numberSize -Weight "SemiBold" -Font "Segoe UI Variable Display, Segoe UI")) | Out-Null

    # Nom, résolution et rôle de l'écran quand la place le permet
    If (-not $Mini -and $H -ge 90 -and $W -ge 110) {
        $maxTextWidth = [Math]::Max($W - 16, 0)
        $name = New-TextBlock -Text (Get-DisplayName -Index ($Screen.Id - 1)) -Color $textColor -Size 12
        $name.MaxWidth = $maxTextWidth
        $stack.Children.Add($name) | Out-Null

        $resolution = Get-DisplayResolutionText -Index ($Screen.Id - 1)
        If ($resolution) {
            $res = New-TextBlock -Text $resolution -Color $textColor -Size 12
            $res.Opacity = 0.8
            $res.MaxWidth = $maxTextWidth
            $stack.Children.Add($res) | Out-Null
        }
        If ($isPrimary -and $H -ge 125) {
            $role = New-TextBlock -Text "Écran principal" -Color $textColor -Size 11 -Weight "SemiBold"
            $role.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
            $stack.Children.Add($role) | Out-Null
        }
    }
    $tile.Child = $stack

    If (-not $Mini) {
        $tile.Cursor = [System.Windows.Input.Cursors]::Hand
        $tile.Tag = $ScreenIndex
        $tile.ToolTip = "Écran $($Screen.Id) · $(Get-DisplayName -Index ($Screen.Id - 1))`nGlissez-le sur un autre écran pour les échanger.`nClic droit pour en faire l'écran principal."

        $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
        $miPrimary = [System.Windows.Controls.MenuItem]::new()
        $miPrimary.Header = "Définir comme écran principal"
        $miPrimary.IsEnabled = -not $isPrimary
        $miPrimary.Tag = $Screen.Id
        $miPrimary.Add_Click({
            param($sender, $e)
            Set-PrimaryScreen -ScreenId $sender.Tag
        })
        $ctxMenu.Items.Add($miPrimary) | Out-Null
        $ctxMenu.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
        $miIdentify = [System.Windows.Controls.MenuItem]::new()
        $miIdentify.Header = "Identifier les écrans"
        $miIdentify.Add_Click({ Show-IdentifyOverlays })
        $ctxMenu.Items.Add($miIdentify) | Out-Null
        $tile.ContextMenu = $ctxMenu

        # Glisser-déposer : un écran lâché sur un autre échange leurs emplacements ; un simple clic garde l'ancien fonctionnement
        $tile.Add_MouseLeftButtonDown({
            param($sender, $e)
            $script:Drag = @{ Index = [int]$sender.Tag; Start = $e.GetPosition($cvPreview); Moved = $false; Target = -1 }
            [void]$sender.CaptureMouse()
            $e.Handled = $true
        })
        $tile.Add_MouseMove({
            param($sender, $e)
            $drag = $script:Drag
            If (-not $drag -or $drag.Index -ne [int]$sender.Tag) { return }
            $p = $e.GetPosition($cvPreview)
            $dx = $p.X - $drag.Start.X
            $dy = $p.Y - $drag.Start.Y
            If (-not $drag.Moved) {
                If ([Math]::Abs($dx) -lt 4 -and [Math]::Abs($dy) -lt 4) { return }
                $drag.Moved = $true
                [System.Windows.Controls.Panel]::SetZIndex($sender, 100)
                $sender.Opacity = 0.85
            }
            $sender.RenderTransform = [System.Windows.Media.TranslateTransform]::new($dx, $dy)
            $target = Get-PreviewSlotAt -Point $p -Exclude $drag.Index
            If ($target -ne $drag.Target) {
                If ($drag.Target -ge 0) { Set-TileHighlight -Index $drag.Target -On $false }
                If ($target -ge 0) { Set-TileHighlight -Index $target -On $true }
                $drag.Target = $target
            }
        })
        $tile.Add_MouseLeftButtonUp({
            param($sender, $e)
            $drag = $script:Drag
            $script:Drag = $null
            $sender.ReleaseMouseCapture()
            If (-not $drag) { return }
            If (-not $drag.Moved) {
                Invoke-TileClick -Index $drag.Index
            } ElseIf ($drag.Target -ge 0) {
                Invoke-ScreenSwap -IndexA $drag.Index -IndexB $drag.Target
            } Else {
                Update-Preview
            }
        })
        $tile.Add_LostMouseCapture({
            # Glisser interrompu (changement de fenêtre, etc.) : on remet l'aperçu en place
            If ($script:Drag) {
                $script:Drag = $null
                Update-Preview
            }
        })

        $script:PreviewTiles[$ScreenIndex] = @{
            Tile = $tile; Stroke = $tile.BorderBrush; Thickness = $tile.BorderThickness; Highlight = $highlight
        }
    }

    [System.Windows.Controls.Canvas]::SetLeft($tile, $X)
    [System.Windows.Controls.Canvas]::SetTop($tile, $Y)
    $Canvas.Children.Add($tile) | Out-Null
}

Function Draw-LayoutPreview {
    param(
        $Canvas,
        $Screens,
        [bool]$Mini = $false
    )

    $Canvas.Children.Clear()
    If (-not $Mini) {
        $script:PreviewSlots = @()
        $script:PreviewTiles = @{}
    }
    If (-not $Screens -or $Screens.Count -eq 0) { return }

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

    $padding = If ($Mini) { 6 } Else { 28 }
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

    # Petit espace entre les écrans, comme dans les Paramètres Windows
    $gap = If ($Mini) { 1.5 } Else { 3 }

    For ($idx = 0; $idx -lt $Screens.Count; $idx++) {
        $s = $Screens[$idx]
        $sx = (($s.X - $minX) * $scale) + $offsetX
        $sy = (($s.Y - $minY) * $scale) + $offsetY
        $sw = $s.W * $scale
        $sh = $s.H * $scale
        Draw-ScreenRect -Canvas $Canvas -X ($sx + $gap) -Y ($sy + $gap) -W ($sw - 2 * $gap) -H ($sh - 2 * $gap) -Screen $s -ScreenIndex $idx -Mini $Mini
        If (-not $Mini) {
            $script:PreviewSlots += @{ Index = $idx; X = $sx; Y = $sy; W = $sw; H = $sh }
        }
    }
}

Function Switch-Favorite {
    param([int]$LayoutIndex)

    $script:Layouts[$LayoutIndex].Favorite = -not $script:Layouts[$LayoutIndex].Favorite
    Save-Settings
    Build-Cards
    Update-Preview
}

Function Build-Cards {
    $pnlCards.Children.Clear()

    If ($script:ShowFavoritesOnly -and -not $script:Layouts[$script:SelectedLayoutIndex].Favorite) {
        For ($j = 0; $j -lt $script:Layouts.Count; $j++) {
            If ($script:Layouts[$j].Favorite) { $script:SelectedLayoutIndex = $j; break }
        }
    }

    $shown = 0
    For ($i = 0; $i -lt $script:Layouts.Count; $i++) {
        $layout = $script:Layouts[$i]
        If ($script:ShowFavoritesOnly -and -not $layout.Favorite) { continue }
        $shown++
        $idx = $i

        $isSelected = ($i -eq $script:SelectedLayoutIndex)

        # Carte sélectionnable : bordure d'accent quand elle est choisie (épaisseur compensée par le padding)
        $card = [System.Windows.Controls.Border]::new()
        $card.Width = 236
        $card.Margin = [System.Windows.Thickness]::new(4)
        $card.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $card.Background = New-Brush $C.Card
        If ($isSelected) {
            $card.BorderBrush = New-Brush $C.Accent
            $card.BorderThickness = [System.Windows.Thickness]::new(2)
            $card.Padding = [System.Windows.Thickness]::new(11)
        } Else {
            $card.BorderBrush = New-Brush $C.CardBorder
            $card.BorderThickness = [System.Windows.Thickness]::new(1)
            $card.Padding = [System.Windows.Thickness]::new(12)
        }
        $card.Tag = $idx
        $card.ToolTip = "Choisir la disposition $($layout.Name)"

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
            Switch-Favorite -LayoutIndex $sender.Tag
        })
        $ctxMenu.Items.Add($miFav) | Out-Null
        $card.ContextMenu = $ctxMenu

        $grid = [System.Windows.Controls.Grid]::new()
        $row1 = [System.Windows.Controls.RowDefinition]::new(); $row1.Height = [System.Windows.GridLength]::Auto
        $row2 = [System.Windows.Controls.RowDefinition]::new(); $row2.Height = [System.Windows.GridLength]::Auto
        $grid.RowDefinitions.Add($row1)
        $grid.RowDefinitions.Add($row2)

        # Miniature
        $miniHost = [System.Windows.Controls.Border]::new()
        $miniHost.Height = 104
        $miniHost.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $miniHost.Background = New-Brush $C.PreviewBg
        $miniCanvas = [System.Windows.Controls.Canvas]::new()
        $miniCanvas.IsHitTestVisible = $false
        $miniHost.Child = $miniCanvas
        $grid.Children.Add($miniHost) | Out-Null

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
        $title.Text = $layout.Name
        $title.FontWeight = If ($isSelected) { "SemiBold" } Else { "Normal" }
        $texts.Children.Add($title) | Out-Null
        $desc = [System.Windows.Controls.TextBlock]::new()
        $desc.Text = $layout.Description
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
        If ($layout.Favorite) {
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
        $star.Tag = $idx
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
            $script:SelectedSwapIndex = -1
            Set-Status "" "None"
            Build-Cards
            Update-Preview
        })

        $pnlCards.Children.Add($card) | Out-Null
        $miniCanvas.Tag = Get-PreviewScreens -Layout $layout
        $miniCanvas.Add_Loaded({
            param($sender, $e)
            Draw-LayoutPreview -Canvas $sender -Screens $sender.Tag -Mini $true
        })
    }

    $txtNoFavorites.Visibility = If ($shown -eq 0) { "Visible" } Else { "Collapsed" }
}

# Pastilles "Écran 1 / 2 / 3" pour choisir l'écran principal
Function Update-PrimaryChips {
    $pnlPrimary.Children.Clear()
    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    ForEach ($s In @($layout.Screens | Sort-Object { $_.Id })) {
        $chip = [System.Windows.Controls.RadioButton]::new()
        $chip.Style = $window.FindResource("Chip")
        $chip.GroupName = "PrimaryScreen"
        $chip.Content = "Écran $($s.Id)"
        $chip.Margin = [System.Windows.Thickness]::new(4, 0, 0, 0)
        $chip.ToolTip = Get-DisplayLabel -Index ($s.Id - 1)
        $chip.IsChecked = [bool]$s.Primary
        $chip.Tag = $s.Id
        $chip.Add_Checked({
            param($sender, $e)
            Set-PrimaryScreen -ScreenId $sender.Tag
        })
        $pnlPrimary.Children.Add($chip) | Out-Null
    }
}

Function Update-Hint {
    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    $needed = $layout.SourceMap.Count
    If ($script:Displays.Count -lt $needed) {
        $txtHint.Text = "Aperçu indicatif : cette disposition demande $needed écrans, $($script:Displays.Count) détecté(s) pour le moment."
    } Else {
        $txtHint.Text = "Glissez un écran sur un autre pour les échanger. Clic droit sur un écran pour en faire l'écran principal."
    }
}

Function Update-Preview {
    $layout = $script:Layouts[$script:SelectedLayoutIndex]
    $txtPreviewTitle.Text = "Aperçu : $($layout.Name)"
    Draw-LayoutPreview -Canvas $cvPreview -Screens (Get-PreviewScreens -Layout $layout) -Mini $false
    Update-PrimaryChips
    Update-Hint
}

Function Set-LayoutFromGui {
    $currentLayout = $script:Layouts[$script:SelectedLayoutIndex]

    # Trouver l'index de l'écran principal dans le layout
    $primaryScreenIdx = 0
    For ($i = 0; $i -lt $currentLayout.Screens.Count; $i++) {
        If ($currentLayout.Screens[$i].Primary) { $primaryScreenIdx = $i; break }
    }

    # Récupérer l'index dans SourceMap pour l'écran principal
    $primarySourceIdx = $currentLayout.SourceMap[$primaryScreenIdx]
    $sourceMap = [int[]]$currentLayout.SourceMap
    $useMax = [bool]$script:UseMaxResolution
    $script:LastResolutionChanges = @()

    Try {
        # Avec la résolution maximale, chaque écran y passe d'abord ; la disposition est calculée avec ces tailles
        switch ($currentLayout.LayoutKey) {
            "T" {
                $result = Set-LayoutTShape -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap -MaxResolution:$useMax
            }
            "Horizontal" {
                $result = Set-LayoutHorizontal -MinScreens 3 -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap -MaxResolution:$useMax
            }
            "LineOut" {
                $result = Set-LayoutLineOut -PrimaryIndex $primarySourceIdx -SourceMap $sourceMap -MaxResolution:$useMax
            }
            default {
                throw "Layout non supporté : $($currentLayout.LayoutKey)"
            }
        }

        $applied = @($result)
        $resolutionChanged = @($script:LastResolutionChanges | Where-Object { $_.Changed }).Count
        $resolutionFailed  = @($script:LastResolutionChanges | Where-Object { $_.NeedsChange -and -not $_.Changed }).Count

        If ($applied.Count -eq 0 -or $applied[-1] -ne $true) {
            Set-Status "Échec de l'application de $($currentLayout.Name) (code $([DisplayApi]::LastResult))." "Error"
        } Else {
            $text = "Configuration $($currentLayout.Name) appliquée"
            If ($resolutionChanged -gt 0) { $text += " ($resolutionChanged écran(s) passé(s) en résolution maximale)" }

            $notes = @()
            If ($script:LastLayoutWarning) { $notes += "l'écran principal n'a pas pu être défini" }
            If ($resolutionFailed -gt 0) { $notes += "résolution maximale refusée sur $resolutionFailed écran(s)" }

            If ($notes.Count -gt 0) {
                Set-Status "$text, mais $($notes -join ' et ')." "Warning"
            } Else {
                Set-Status "$text." "Success"
            }
        }
    }
    Catch {
        Set-Status "Erreur : $($_.Exception.Message)" "Error"
    }

    Update-DisplayInfo
    Update-Preview
    Build-Cards
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
    If ($Message) { Set-Status $Message "Success" }
}

Function Show-IdentifyOverlays {
    Close-IdentifyOverlays

    # Numérotation identique à l'aperçu : écran N = source N-1 de [DisplayApi]::GetSources()
    Update-DisplayInfo
    Update-Preview
    If ($script:Displays.Count -eq 0) {
        Set-Status "Aucun écran détecté." "Error"
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

        # Grand numéro en bas à gauche de l'écran, comme le bouton Identifier de Windows
        $number = New-TextBlock -Text ($i + 1).ToString() -Color "#FFFFFF" -Size ([Math]::Max([Math]::Min($bh / 6, 140), 64)) -Weight "SemiBold" -Font "Segoe UI Variable Display, Segoe UI"
        $number.HorizontalAlignment = "Left"
        $number.TextAlignment = "Left"

        $name = New-TextBlock -Text (Get-DisplayLabel -Index $i) -Color "#E6E6E6" -Size 16
        $name.HorizontalAlignment = "Left"
        $name.TextAlignment = "Left"

        $panel = [System.Windows.Controls.StackPanel]::new()
        $panel.Children.Add($number) | Out-Null
        $panel.Children.Add($name) | Out-Null

        $border = [System.Windows.Controls.Border]::new()
        $border.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(230, 32, 32, 32))
        $border.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(40, 255, 255, 255))
        $border.BorderThickness = [System.Windows.Thickness]::new(1)
        $border.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $border.Padding = [System.Windows.Thickness]::new(32, 8, 40, 24)
        $border.Margin = [System.Windows.Thickness]::new(48)
        $border.HorizontalAlignment = "Left"
        $border.VerticalAlignment = "Bottom"
        $border.Cursor = [System.Windows.Input.Cursors]::Hand
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

    Set-Status "Cliquez sur un numéro ou attendez $($script:IdentifySeconds) secondes..." "Info"
}

# ========== ÉVÉNEMENTS ==========
$window.Icon = New-GlyphImage -Glyph ([string][char]0xE7F4) -Color $C.Accent
$chkMaxRes.IsChecked = [bool]$script:UseMaxResolution
$script:Drag = $null
$script:PreviewSlots = @()
$script:PreviewTiles = @{}

$btnApply.Add_Click({
    # Affiche l'état "en cours" avant de lancer l'application, qui bloque l'interface quelques secondes
    $btnApply.IsEnabled = $false
    Set-Status "Application de la configuration en cours..." "Busy"
    $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{
        Try { Set-LayoutFromGui } Finally { $btnApply.IsEnabled = $true }
    }) | Out-Null
})

$btnIdentify.Add_Click({
    Show-IdentifyOverlays
})

$tglFavorites.Add_Click({
    $script:ShowFavoritesOnly = [bool]$tglFavorites.IsChecked
    Build-Cards
    Update-Preview
})

$chkMaxRes.Add_Click({
    $script:UseMaxResolution = [bool]$chkMaxRes.IsChecked
    Save-Settings
    Update-Preview
    Build-Cards
})

# Barre de titre assortie au thème et fond Mica sous Windows 11
$window.Add_SourceInitialized({
    $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
    If ([DisplayApi]::ApplyWindowStyle($hwnd, $script:IsDark, $script:UseMica)) {
        $window.Background = [System.Windows.Media.Brushes]::Transparent
        [System.Windows.Interop.HwndSource]::FromHwnd($hwnd).CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
    }
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
