using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32;

namespace Vaktet
{
    static class Program
    {
        private const string MutexName = "Global\\Vaktet2026_SingleInstance_Mutex";

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private const int SW_RESTORE = 9;

        private static readonly Dictionary<string, byte[]> Assets = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        private static readonly Dictionary<string, string> MimeTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { ".html", "text/html; charset=utf-8" },
            { ".htm", "text/html; charset=utf-8" },
            { ".css", "text/css; charset=utf-8" },
            { ".js", "application/javascript; charset=utf-8" },
            { ".json", "application/json; charset=utf-8" },
            { ".webmanifest", "application/manifest+json; charset=utf-8" },
            { ".png", "image/png" },
            { ".jpg", "image/jpeg" },
            { ".jpeg", "image/jpeg" },
            { ".gif", "image/gif" },
            { ".svg", "image/svg+xml" },
            { ".ico", "image/x-icon" },
            { ".ttf", "font/ttf" },
            { ".woff", "font/woff" },
            { ".woff2", "font/woff2" },
            { ".mp3", "audio/mpeg" },
            { ".wav", "audio/wav" },
            { ".txt", "text/plain; charset=utf-8" }
        };

        private static HttpListener _httpListener;
        private static DateTime _launchTime = DateTime.UtcNow;
        private static DateTime _lastHeartbeat = DateTime.MinValue;
        private static volatile bool _exitRequested = false;
        private static volatile int _heartbeatCount = 0;
        private static string _logFile;

        private static void Log(string msg)
        {
            try
            {
                if (!string.IsNullOrEmpty(_logFile))
                {
                    File.AppendAllText(_logFile, string.Format("[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}\r\n", DateTime.Now, msg));
                }
            }
            catch { }
        }

        private static IntPtr FindVaktetWindow()
        {
            IntPtr found = IntPtr.Zero;
            try
            {
                EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
                {
                    if (IsWindowVisible(hWnd))
                    {
                        int length = GetWindowTextLength(hWnd);
                        if (length > 0)
                        {
                            StringBuilder sb = new StringBuilder(length + 1);
                            GetWindowText(hWnd, sb, sb.Capacity);
                            string title = sb.ToString();
                            if (title.IndexOf("Vaktet", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                found = hWnd;
                                return false; // Stop enumeration
                            }
                        }
                    }
                    return true;
                }, IntPtr.Zero);
            }
            catch { }
            return found;
        }

        [STAThread]
        static void Main(string[] args)
        {
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Vaktet2026");
            if (!Directory.Exists(appData))
            {
                Directory.CreateDirectory(appData);
            }
            _logFile = Path.Combine(appData, "vaktet.log");
            Log("=== Vaktet 2026 starting ===");

            bool createdNew;
            using (Mutex mutex = new Mutex(true, MutexName, out createdNew))
            {
                if (!createdNew)
                {
                    Log("Another instance is already running. Focusing window.");
                    IntPtr existing = FindVaktetWindow();
                    if (existing != IntPtr.Zero)
                    {
                        ShowWindow(existing, SW_RESTORE);
                        SetForegroundWindow(existing);
                    }
                    return;
                }

                try
                {
                    _launchTime = DateTime.UtcNow;
                    LoadAssetsFromAssembly();
                    Log(string.Format("Loaded {0} assets from assembly.", Assets.Count));

                    int port = GetFreePort();
                    StartHttpServer(port);
                    Log(string.Format("HTTP server listening on 127.0.0.1:{0}", port));

                    string appUrl = string.Format("http://127.0.0.1:{0}/", port);
                    LaunchAppWindow(appUrl);
                    Log("App window launched. Entering monitor loop.");

                    // Main monitoring loop
                    while (!_exitRequested)
                    {
                        Thread.Sleep(1000);

                        if (_exitRequested)
                        {
                            Log("Exit signal received. Terminating host.");
                            break;
                        }

                        double elapsedSinceLaunch = (DateTime.UtcNow - _launchTime).TotalSeconds;

                        if (_heartbeatCount > 0)
                        {
                            double elapsedSinceHeartbeat = (DateTime.UtcNow - _lastHeartbeat).TotalSeconds;
                            if (elapsedSinceHeartbeat > 8)
                            {
                                Log(string.Format("Heartbeat timed out ({0:F1}s). User closed app.", elapsedSinceHeartbeat));
                                break;
                            }
                        }
                        else
                        {
                            // Initial grace period: wait up to 45 seconds for first heartbeat
                            if (elapsedSinceLaunch > 45)
                            {
                                Log("No heartbeat received within 45s grace period. Shutting down.");
                                break;
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Log("FATAL ERROR: " + ex.ToString());
                    System.Windows.Forms.MessageBox.Show(
                        "Gabim gjatë nisjes së Vaktet 2026:\n" + ex.Message,
                        "Vaktet 2026",
                        System.Windows.Forms.MessageBoxButtons.OK,
                        System.Windows.Forms.MessageBoxIcon.Error);
                }
                finally
                {
                    Log("Stopping HTTP server and exiting.");
                    StopHttpServer();
                }
            }
        }

        private static void LoadAssetsFromAssembly()
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream stream = asm.GetManifestResourceStream("assets.zip"))
            {
                if (stream == null)
                {
                    throw new FileNotFoundException("Burimi i paketuar 'assets.zip' nuk u gjet brenda aplikacionit.");
                }

                using (ZipArchive archive = new ZipArchive(stream, ZipArchiveMode.Read))
                {
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        if (string.IsNullOrEmpty(entry.Name))
                            continue; // skip directory entry

                        string normalizedKey = entry.FullName.Replace('\\', '/').TrimStart('/');
                        using (Stream entryStream = entry.Open())
                        using (MemoryStream ms = new MemoryStream())
                        {
                            entryStream.CopyTo(ms);
                            Assets[normalizedKey] = ms.ToArray();
                        }
                    }
                }
            }
        }

        private static int GetFreePort()
        {
            TcpListener l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            int port = ((IPEndPoint)l.LocalEndpoint).Port;
            l.Stop();
            return port;
        }

        private static void StartHttpServer(int port)
        {
            _httpListener = new HttpListener();
            _httpListener.Prefixes.Add(string.Format("http://127.0.0.1:{0}/", port));
            _httpListener.Start();
            _httpListener.BeginGetContext(OnHttpRequest, null);
        }

        private static void StopHttpServer()
        {
            if (_httpListener != null)
            {
                try
                {
                    _httpListener.Stop();
                    _httpListener.Close();
                }
                catch { }
                _httpListener = null;
            }
        }

        private static void OnHttpRequest(IAsyncResult ar)
        {
            if (_httpListener == null || !_httpListener.IsListening)
                return;

            HttpListenerContext ctx = null;
            try
            {
                ctx = _httpListener.EndGetContext(ar);
            }
            catch
            {
                return;
            }
            finally
            {
                if (_httpListener != null && _httpListener.IsListening)
                {
                    try { _httpListener.BeginGetContext(OnHttpRequest, null); } catch { }
                }
            }

            if (ctx == null) return;

            try
            {
                string path = ctx.Request.Url.AbsolutePath.TrimStart('/');
                if (string.IsNullOrEmpty(path))
                {
                    path = "index.html";
                }

                // Heartbeat API
                if (string.Equals(path, "api/heartbeat", StringComparison.OrdinalIgnoreCase))
                {
                    _lastHeartbeat = DateTime.UtcNow;
                    _heartbeatCount++;
                    ctx.Response.StatusCode = 204;
                    ctx.Response.ContentLength64 = 0;
                    ctx.Response.Close();
                    return;
                }

                // Exit API
                if (string.Equals(path, "api/exit", StringComparison.OrdinalIgnoreCase))
                {
                    _exitRequested = true;
                    Log("Frontend sent /api/exit signal.");
                    ctx.Response.StatusCode = 204;
                    ctx.Response.ContentLength64 = 0;
                    ctx.Response.Close();
                    return;
                }

                // Asset Serving
                byte[] data;
                if (Assets.TryGetValue(path, out data))
                {
                    string ext = Path.GetExtension(path);
                    string mime;
                    if (!MimeTypes.TryGetValue(ext, out mime))
                    {
                        mime = "application/octet-stream";
                    }

                    // For index.html, inject the desktop integration script
                    if (string.Equals(path, "index.html", StringComparison.OrdinalIgnoreCase))
                    {
                        string html = Encoding.UTF8.GetString(data);
                        string hookScript = 
                            "\n<script>\n" +
                            "(function(){\n" +
                            "  function ping(){\n" +
                            "    try { var x = new XMLHttpRequest(); x.open('GET','/api/heartbeat?t=' + Date.now(), true); x.send(); } catch(e){}\n" +
                            "  }\n" +
                            "  setInterval(ping, 2000);\n" +
                            "  ping();\n" +
                            "  function onExit(){\n" +
                            "    try {\n" +
                            "      if (navigator.sendBeacon) { navigator.sendBeacon('/api/exit'); }\n" +
                            "      else { var x = new XMLHttpRequest(); x.open('POST','/api/exit',false); x.send(); }\n" +
                            "    } catch(e){}\n" +
                            "  }\n" +
                            "  window.addEventListener('pagehide', onExit);\n" +
                            "  window.addEventListener('beforeunload', onExit);\n" +
                            "})();\n" +
                            "</script>\n";

                        int bodyIdx = html.LastIndexOf("</body>", StringComparison.OrdinalIgnoreCase);
                        if (bodyIdx >= 0)
                        {
                            html = html.Insert(bodyIdx, hookScript);
                        }
                        else
                        {
                            html += hookScript;
                        }
                        data = Encoding.UTF8.GetBytes(html);
                    }

                    ctx.Response.StatusCode = 200;
                    ctx.Response.ContentType = mime;
                    ctx.Response.ContentLength64 = data.Length;
                    ctx.Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate");
                    ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*");
                    ctx.Response.OutputStream.Write(data, 0, data.Length);
                    ctx.Response.OutputStream.Close();
                }
                else
                {
                    Log("Asset not found: " + path);
                    ctx.Response.StatusCode = 404;
                    byte[] err = Encoding.UTF8.GetBytes("Nuk u gjet: " + path);
                    ctx.Response.ContentType = "text/plain; charset=utf-8";
                    ctx.Response.ContentLength64 = err.Length;
                    ctx.Response.OutputStream.Write(err, 0, err.Length);
                    ctx.Response.OutputStream.Close();
                }
            }
            catch (Exception ex)
            {
                Log("Error handling request: " + ex.Message);
                try
                {
                    ctx.Response.StatusCode = 500;
                    ctx.Response.Close();
                }
                catch { }
            }
        }

        private static void LaunchAppWindow(string url)
        {
            string browserExe = FindBrowserExecutable();
            string profileDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Vaktet2026", "UserData");

            if (!Directory.Exists(profileDir))
            {
                Directory.CreateDirectory(profileDir);
            }

            Log(string.Format("Launching browser '{0}' with url '{1}'", browserExe ?? "DefaultBrowser", url));

            if (!string.IsNullOrEmpty(browserExe) && File.Exists(browserExe))
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = browserExe;
                // Chromium --app mode: dedicated chromeless window with specified size and custom app profile
                psi.Arguments = string.Format(
                    "--app={0} --window-size=460,880 --user-data-dir=\"{1}\" --app-id=Vaktet2026 --disable-features=Translate,OptimizationHints --no-first-run --no-default-browser-check",
                    url,
                    profileDir);
                psi.UseShellExecute = true;

                try
                {
                    Process.Start(psi);
                    return;
                }
                catch (Exception ex)
                {
                    Log("Failed to launch specific browser: " + ex.Message);
                }
            }

            // Fallback: system default browser
            ProcessStartInfo fallback = new ProcessStartInfo(url);
            fallback.UseShellExecute = true;
            Process.Start(fallback);
        }

        private static string FindBrowserExecutable()
        {
            // 1. Check Google Chrome
            string[] chromePaths = new string[]
            {
                GetRegistryAppPath("chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe")
            };

            foreach (string p in chromePaths)
            {
                if (!string.IsNullOrEmpty(p) && File.Exists(p))
                    return p;
            }

            // 2. Check Microsoft Edge
            string[] edgePaths = new string[]
            {
                GetRegistryAppPath("msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe")
            };

            foreach (string p in edgePaths)
            {
                if (!string.IsNullOrEmpty(p) && File.Exists(p))
                    return p;
            }

            // Check EdgeCore directory if standard Edge location not present
            string progX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            string edgeCoreDir = Path.Combine(progX86, @"Microsoft\EdgeCore");
            if (Directory.Exists(edgeCoreDir))
            {
                string[] files = Directory.GetFiles(edgeCoreDir, "msedge.exe", SearchOption.AllDirectories);
                if (files.Length > 0 && File.Exists(files[0]))
                    return files[0];
            }

            // 3. Check Brave
            string[] bravePaths = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"BraveSoftware\Brave-Browser\Application\brave.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"BraveSoftware\Brave-Browser\Application\brave.exe")
            };

            foreach (string p in bravePaths)
            {
                if (!string.IsNullOrEmpty(p) && File.Exists(p))
                    return p;
            }

            return null;
        }

        private static string GetRegistryAppPath(string exeName)
        {
            try
            {
                string key = @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" + exeName;
                using (RegistryKey rk = Registry.LocalMachine.OpenSubKey(key))
                {
                    if (rk != null)
                    {
                        object val = rk.GetValue("");
                        if (val != null) return val.ToString();
                    }
                }
                using (RegistryKey rk = Registry.CurrentUser.OpenSubKey(key))
                {
                    if (rk != null)
                    {
                        object val = rk.GetValue("");
                        if (val != null) return val.ToString();
                    }
                }
            }
            catch { }
            return null;
        }
    }
}
