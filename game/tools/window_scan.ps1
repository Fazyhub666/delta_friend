param(
    [Parameter(Mandatory=$true)][string]$OutFile,
    [int]$GamePid = 0,
    [int]$IntervalMs = 80
)

$src = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WinScan {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int idx);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out RECT r, int size);

    const int GWL_EXSTYLE = -20;
    const long WS_EX_TOOLWINDOW = 0x80;
    const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

    static bool GetFrameBounds(IntPtr hWnd, out RECT r) {
        if (DwmGetWindowAttribute(hWnd, DWMWA_EXTENDED_FRAME_BOUNDS, out r, Marshal.SizeOf(typeof(RECT))) == 0) {
            return true;
        }
        return GetWindowRect(hWnd, out r);
    }

    public static List<long[]> Scan(int gamePid) {
        var result = new List<long[]>();
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            if (IsIconic(h)) return true;
            long style = GetWindowLong(h, GWL_EXSTYLE);
            if ((style & WS_EX_TOOLWINDOW) != 0) return true;
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (gamePid != 0 && (int)pid == gamePid) return true;
            int len = GetWindowTextLength(h);
            if (len == 0) return true;
            var sb = new StringBuilder(len + 1);
            GetWindowText(h, sb, sb.Capacity);
            if (sb.Length == 0) return true;
            RECT r; if (!GetFrameBounds(h, out r)) return true;
            long w = (long)r.Right - r.Left;
            long hh = (long)r.Bottom - r.Top;
            if (w < 20 || hh < 20) return true;
            result.Add(new long[] { r.Left, r.Top, w, hh });
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
"@

Add-Type -TypeDefinition $src -Language CSharp

$jsonPath = $OutFile
$tmpPath = "$OutFile.tmp"
Remove-Item -LiteralPath $tmpPath -ErrorAction SilentlyContinue

while ($true) {
    try {
        $rows = [WinScan]::Scan($GamePid)
        if ($null -eq $rows -or $rows.Count -eq 0) {
            $json = "[]"
        } else {
            $inner = @($rows | ForEach-Object { "[" + ($_ -join ",") + "]" })
            $json = "[" + ($inner -join ",") + "]"
        }
        Set-Content -LiteralPath $tmpPath -Value $json -Encoding Ascii -NoNewline
        Move-Item -LiteralPath $tmpPath -Destination $jsonPath -Force -ErrorAction SilentlyContinue
    } catch {
        # keep last good file on transient errors
    }
    Start-Sleep -Milliseconds $IntervalMs
}