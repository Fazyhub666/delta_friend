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

    // EnumWindows recorre las ventanas en orden de Z (delante hacia atras).
    // Por eso 'front' contiene las ventanas que ya aceptamos y estan delante.

    // Devuelve true si w esta totalmente contenida por alguna ventana frontal.
    static bool IsFullyCovered(long[] w, List<long[]> front) {
        long wLeft = w[0], wTop = w[1], wRight = w[0] + w[2], wBottom = w[1] + w[3];
        foreach (var f in front) {
            if (f[0] <= wLeft && f[1] <= wTop && (f[0] + f[2]) >= wRight && (f[1] + f[3]) >= wBottom) return true;
        }
        return false;
    }

    // Devuelve true si el borde superior de w (fila y=w.Top) queda oculto por las ventanas frontales.
    static bool TopEdgeCovered(long[] w, List<long[]> front) {
        long edgeLeft = w[0];
        long edgeRight = w[0] + w[2];
        long top = w[1];
        long coveredUntil = edgeLeft;
        bool progress = true;
        while (progress) {
            progress = false;
            foreach (var f in front) {
                if (f[1] + f[3] <= top) continue;
                if (f[1] > top) continue;
                long fLeft = Math.Max(f[0], coveredUntil);
                if (fLeft > coveredUntil) continue;
                long fRight = Math.Min(f[0] + f[2], edgeRight);
                if (fRight > coveredUntil) {
                    coveredUntil = fRight;
                    progress = true;
                    if (coveredUntil >= edgeRight) return true;
                }
            }
        }
        return false;
    }

    public static List<long[]> Scan(int gamePid) {
        var front = new List<long[]>();
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
            long[] rect = new long[] { r.Left, r.Top, w, hh };
            if (IsFullyCovered(rect, front)) return true;
            if (TopEdgeCovered(rect, front)) return true;
            front.Add(rect);
            return true;
        }, IntPtr.Zero);
        return front;
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