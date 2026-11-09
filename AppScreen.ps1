# ScreenConfig-Final.ps1
$ErrorActionPreference = 'Stop'

# ========== CHARGEMENT DES ASSEMBLIES WPF ==========
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ========== INTÉGRATION DE DisplayApi ==========
If (-not ([System.Management.Automation.PSTypeName]'DisplayApi').Type) {
    Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32;

public struct POINTL { public int x; public int y; }

public static class DisplayApi
{
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

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool EnumDisplaySettingsEx(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode, int dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int ChangeDisplaySettingsEx(string lpszDeviceName, IntPtr lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool EnumDisplayDevices(string lpDevice, int iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, int dwFlags);

    const uint QDC_ONLY_ACTIVE_PATHS              = 0x00000002;
    const uint SDC_APPLY                          = 0x00000080;
    const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG    = 0x00000020;
    const uint SDC_NO_OPTIMIZATION                = 0x00000100;
    const uint SDC_SAVE_TO_DATABASE               = 0x00000200;
    const uint DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE = 1;

    const int ENUM_CURRENT_SETTINGS = -1;
    const int DM_POSITION           = 0x00000020;
    const int CDS_UPDATEREGISTRY    = 0x00000001;
    const int CDS_NORESET           = 0x10000000;
    const int CDS_SET_PRIMARY       = 0x00000010;

    private static int lastResult = 0;
    public static int LastResult { get { return lastResult; } }

    public class SourceInfo {
        public int IndexInModeArray;
        public uint Id;
        public int Width, Height;
        public int X, Y;
        public LUID Adapter;
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
                list.Add(info);
            }
        }
        list.Sort((a,b) => a.Id.CompareTo(b.Id));
        return list;
    }

    public static bool ApplyPositions(Dictionary<UInt32, POINTL> positions)
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
                uint id = modes[i].id;
                if (positions != null && positions.ContainsKey(id))
                {
                    var sm = modes[i].modeInfo.sourceMode;
                    POINTL dest = positions[id];
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

    public static bool TrySetPrimaryByPosition(int x, int y)
    {
        int devNum = 0;
        while (true)
        {
            DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevices(null, devNum, ref dd, 0))
                break;

            bool isDisplay = dd.DeviceName != null && dd.DeviceName.StartsWith(@"\.\DISPLAY", StringComparison.OrdinalIgnoreCase);
            if (!isDisplay) { devNum++; continue; }

            DEVMODE dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (!EnumDisplaySettingsEx(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm, 0)) { devNum++; continue; }

            if (dm.dmPosition.x == x && dm.dmPosition.y == y)
            {
                int r1 = ChangeDisplaySettingsEx(dd.DeviceName, IntPtr.Zero, IntPtr.Zero, (uint)(CDS_SET_PRIMARY | CDS_UPDATEREGISTRY | CDS_NORESET), IntPtr.Zero);
                int r2 = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
                return (r1 == 0 && r2 == 0);
            }
            devNum++;
        }
        return false;
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

            info.WidthMm = edid[21] * 10;
            info.HeightMm = edid[22] * 10;

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
    $pointType = [DisplayApi].Assembly.GetType('POINTL')
    if (-not $pointType) { throw "POINTL type not found." }
    $dictType = [System.Collections.Generic.Dictionary``2].MakeGenericType([System.UInt32], $pointType)
    return [Activator]::CreateInstance($dictType)
}

Function New-PointL {
    param([int]$X, [int]$Y)
    $pointType = [DisplayApi].Assembly.GetType('POINTL')
    $p = [Activator]::CreateInstance($pointType)
    $p.x = $X; $p.y = $Y
    return $p
}

Function Apply-LayoutPositions {
    param(
        $Positions,
        $Sources,
        [int]$PrimaryIndex,
        [string]$LayoutName
    )

    $ok = [DisplayApi]::ApplyPositions($Positions)
    if (-not $ok) {
        Write-Warning "SetDisplayConfig returned code: $([DisplayApi]::LastResult)"
        return $false
    }
    Write-Host "$LayoutName layout applied." -ForegroundColor Green

    $primary = $Sources[$PrimaryIndex]
    $ptPrimary = $Positions[[uint32]$primary.Id]
    if (-not [DisplayApi]::TrySetPrimaryByPosition($ptPrimary.x, $ptPrimary.y)) {
        Write-Warning "Could not set primary display (GPO restriction?)."
    } else {
        Write-Host "Primary set to screen index $PrimaryIndex (ID $($primary.Id))." -ForegroundColor Green
    }

    return $true
}

Function Set-LayoutTShape {
    param([int]$PrimaryIndex = 0)

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }

    $srcA = $sources[0]; $srcB = $sources[1]; $srcC = $sources[2]

    $topWidth = $srcB.Width + $srcC.Width
    [int]$xA = [Math]::Floor(($topWidth - $srcA.Width) / 2.0)
    [int]$yA = [Math]::Max($srcB.Height, $srcC.Height)

    $positions = New-PointLDictionary
    $positions.Add([uint32]$srcB.Id, (New-PointL -X 0 -Y 0))
    $positions.Add([uint32]$srcC.Id, (New-PointL -X $srcB.Width -Y 0))
    $positions.Add([uint32]$srcA.Id, (New-PointL -X $xA -Y $yA))

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "T-shape"
}

Function Set-LayoutHorizontal {
    param(
        [int]$MinScreens = 3,
        [int]$PrimaryIndex = 2
    )

    $sources = Wait-ExtendedDesktop -MinScreens $MinScreens
    if ($sources.Count -lt $MinScreens) { throw "Need at least $MinScreens screens, found $($sources.Count)." }

    $positions = New-PointLDictionary
    $xOffset = 0
    foreach ($src in $sources) {
        $positions.Add([uint32]$src.Id, (New-PointL -X $xOffset -Y 0))
        $xOffset += $src.Width
    }

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Horizontal"
}

Function Set-LayoutLineOut {
    param([int]$PrimaryIndex = 0)

    $sources = Wait-ExtendedDesktop -MinScreens 3
    if ($sources.Count -lt 3) { throw "Need at least 3 screens, found $($sources.Count)." }

    $srcA = $sources[0]; $srcB = $sources[1]; $srcC = $sources[2]

    $mainHeight = [Math]::Max($srcA.Height, $srcB.Height)
    [int]$yC = $mainHeight - $srcC.Height

    $positions = New-PointLDictionary
    $positions.Add([uint32]$srcA.Id, (New-PointL -X 0 -Y 0))
    $positions.Add([uint32]$srcB.Id, (New-PointL -X $srcA.Width -Y 0))
    $positions.Add([uint32]$srcC.Id, (New-PointL -X ($srcA.Width + $srcB.Width) -Y $yC))

    return Apply-LayoutPositions -Positions $positions -Sources $sources -PrimaryIndex $PrimaryIndex -LayoutName "Line-out"
}

# ========== DONNÉES DES LAYOUTS ==========
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
            @{ Id = 1; X = 0;   Y = 0;  W = 140; H = 90; Primary = $false }
            @{ Id = 2; X = 140; Y = 0;  W = 140; H = 90; Primary = $false }
            @{ Id = 3; X = 310; Y = 30; W = 80;  H = 60; Primary = $false }
        )
    }
)

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
$btnIdentify     = $window.FindName("btnIdentify")  # <-- AJOUTE CETTE LIGNE
$txtStatus       = $window.FindName("txtStatus")
$txtFavStar      = $window.FindName("txtFavStar")
$txtPreviewTitle = $window.FindName("txtPreviewTitle")

# ========== FONCTIONS D'AFFICHAGE ==========
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
        [int]$ScreenIndex = -1
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
            Update-Preview
            Build-Cards
        })
        $ctxMenu.Items.Add($mi)
        $rect.ContextMenu = $ctxMenu

        $rect.Tag = $ScreenIndex
        $rect.Add_MouseLeftButtonDown({
            param($sender, $e)
            $clickedIdx = $sender.Tag
            If ($script:SelectedSwapIndex -lt 0) {
                $script:SelectedSwapIndex = $clickedIdx
                $selId = $script:Layouts[$script:SelectedLayoutIndex].Screens[$clickedIdx].Id
                $txtStatus.Text = [string]::Format("Écran {0} sélectionné. Cliquez sur un autre écran pour échanger.", $selId)
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFD700")
                Update-Preview
            } ElseIf ($script:SelectedSwapIndex -eq $clickedIdx) {
                $script:SelectedSwapIndex = -1
                $txtStatus.Text = "Prêt"
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
                Update-Preview
            } Else {
                Swap-ScreenSlots -IndexA $script:SelectedSwapIndex -IndexB $clickedIdx
                $script:SelectedSwapIndex = -1
                $txtStatus.Text = "Écrans échangés."
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
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

    $tb.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))
    $tbW = $tb.DesiredSize.Width
    $tbH = $tb.DesiredSize.Height

    [System.Windows.Controls.Canvas]::SetLeft($tb, $X + ($W - $tbW) / 2)
    [System.Windows.Controls.Canvas]::SetTop($tb, $Y + ($H - $tbH) / 2)
    $Canvas.Children.Add($tb) | Out-Null
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
        Draw-ScreenRect -Canvas $Canvas -X $sx -Y $sy -W $sw -H $sh -Label "$($s.Id)" -Primary $s.Primary -Mini $Mini -ScreenId $s.Id -ScreenIndex $idx
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
            $wasFavorite = $script:Layouts[$layoutIdx].Favorite
            ForEach ($l In $script:Layouts) { $l.Favorite = $false }
            If (-not $wasFavorite) { $script:Layouts[$layoutIdx].Favorite = $true }
            Build-Cards
            Update-Preview
        })
        $ctxMenu.Items.Add($miFav)
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

    $txtStatus.Text = "Application en cours..."
    $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFD700")

    # Trouver l'index de l'écran principal dans le layout
    $primaryScreenIdx = 0
    For ($i = 0; $i -lt $currentLayout.Screens.Count; $i++) {
        If ($currentLayout.Screens[$i].Primary) { $primaryScreenIdx = $i; break }
    }

    # Récupérer l'index dans SourceMap pour l'écran principal
    $primarySourceIdx = $currentLayout.SourceMap[$primaryScreenIdx]

    Try {
        switch ($currentLayout.LayoutKey) {
            "T" {
                Set-LayoutTShape -PrimaryIndex $primarySourceIdx
                $txtStatus.Text = "Configuration T-shape appliquée."
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
            }
            "Horizontal" {
                Set-LayoutHorizontal -MinScreens 3 -PrimaryIndex $primarySourceIdx
                $txtStatus.Text = "Configuration Full line appliquée."
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
            }
            "LineOut" {
                Set-LayoutLineOut -PrimaryIndex $primarySourceIdx
                $txtStatus.Text = "Configuration Line-out appliquée."
                $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
            }
            default {
                throw "Layout non supporté : $($currentLayout.LayoutKey)"
            }
        }
    }
    Catch {
        $txtStatus.Text = "Erreur: $($_.Exception.Message)"
        $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E63946")
    }
}

# ========== ÉVÉNEMENTS ==========
$btnApply.Add_Click({
    Set-LayoutFromGui
})

$btnIdentify.Add_Click({
    $txtStatus.Text = "Cliquez sur un numéro ou attendez 10 secondes..."
    $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFD700")

    if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.Screen').Type) {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    }

    $script:identifyWindows = @()
    $screens = [System.Windows.Forms.Screen]::AllScreens

    foreach ($screen in $screens) {
        $window = [System.Windows.Window]::new()
        $window.Width = $screen.Bounds.Width
        $window.Height = $screen.Bounds.Height
        $window.Left = $screen.Bounds.Left
        $window.Top = $screen.Bounds.Top
        $window.WindowStyle = [System.Windows.WindowStyle]::None
        $window.AllowsTransparency = $true
        $window.Background = [System.Windows.Media.Brushes]::Transparent
        $window.Topmost = $true
        $window.ShowInTaskbar = $false

        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $textBlock.Text = ($screens.IndexOf($screen) + 1).ToString()
        $textBlock.FontSize = [Math]::Min($screen.Bounds.Height / 4, 200)
        $textBlock.Foreground = [System.Windows.Media.Brushes]::White
        $textBlock.HorizontalAlignment = "Center"
        $textBlock.VerticalAlignment = "Center"
        $textBlock.FontWeight = [System.Windows.FontWeights]::Bold

        $border = [System.Windows.Controls.Border]::new()
        $border.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(180, 0, 0, 0))
        $border.CornerRadius = [System.Windows.CornerRadius]::new(20)
        $border.Padding = [System.Windows.Thickness]::new(40)
        $border.Child = $textBlock

        $window.Content = $border

        # Fermer au clic
        $window.Add_MouseLeftButtonDown({
            param($sender, $e)
            foreach ($w in $script:identifyWindows) { $w.Close() }
            $script:identifyWindows = @()
            if ($timer) { $timer.Stop() }
            $txtStatus.Text = "Identification terminée"
            $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
        })

        $window.Show()
        $script:identifyWindows += $window
    }

    # Fermer après 4 secondes si non cliqué
    $script:timer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:timer.Interval = [System.TimeSpan]::FromSeconds(4)
    $script:timer.Add_Tick({
        param($sender, $e)
        $sender.Stop()
        foreach ($w in $script:identifyWindows) { $w.Close() }
        $script:identifyWindows = @()
        $txtStatus.Text = "Identification terminée (timeout)"
        $txtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4CAF50")
    })
    $script:timer.Start()
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

# ========== FONCTION POUR IDENTIFIER LES ÉCRANS ==========

# ========== AFFICHER LA FENÊTRE ==========
$window.ShowDialog() | Out-Null
