using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.IO.Pipes;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace KruxExecutor;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}

class MainForm : Form
{
    static readonly Color BG = Color.FromArgb(30, 30, 30);
    static readonly Color TITLEBAR = Color.FromArgb(37, 37, 38);
    static readonly Color EDITOR_BG = Color.FromArgb(30, 30, 30);
    static readonly Color BTN_BG = Color.FromArgb(50, 50, 52);
    static readonly Color BTN_BORDER = Color.FromArgb(68, 68, 68);
    static readonly Color ACCENT = Color.FromArgb(0, 122, 204);
    static readonly Color GREEN = Color.FromArgb(76, 175, 80);
    static readonly Color RED = Color.FromArgb(240, 80, 80);
    static readonly Color TEXT = Color.FromArgb(212, 212, 212);
    static readonly Color DIM = Color.FromArgb(136, 136, 136);

    string exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
    bool attached = false;
    readonly List<string> tabContents = new() { "" };
    readonly List<string> tabNames = new() { "Untitled" };
    int activeTab = 0;

    RichTextBox editor = null!;
    Panel outputPanel = null!;
    RichTextBox outputBox = null!;
    Label statusLeft = null!;
    Label statusRight = null!;
    Panel tabStrip = null!;
    Panel searchOverlay = null!;
    TextBox searchInput = null!;
    Panel searchResultsPanel = null!;

    bool drag = false; Point dragOff;

    public MainForm()
    {
        SuspendLayout();
        Text = "KRUX";
        Size = new Size(800, 560);
        MinimumSize = new Size(650, 450);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor = BG;
        try { var asm = typeof(MainForm).Assembly; using var s = asm.GetManifestResourceStream("KruxExecutor.KruxLogo.jpg"); if (s != null) Icon = Icon.FromHandle(new Bitmap(s).GetHicon()); } catch { }
        DoubleBuffered = true;

        // ═══ TITLEBAR ═══
        var tb = new Panel { Dock = DockStyle.Top, Height = 30, BackColor = TITLEBAR };
        tb.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { drag = true; dragOff = e.Location; } };
        tb.MouseMove += (s, e) => { if (drag) Location = new Point(Location.X + e.X - dragOff.X, Location.Y + e.Y - dragOff.Y); };
        tb.MouseUp += (s, e) => { drag = false; };

        var tbTitle = new Label { Text = "KRUX", Font = new Font("Segoe UI", 9f, FontStyle.Bold), ForeColor = TEXT, Dock = DockStyle.Left, Width = 60, TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(8, 0, 0, 0) };
        tb.Controls.Add(tbTitle);

        // Center icons
        int iconX = 120;
        foreach (var ic in new[] { "❮❯", "⚙", "🌐", "🖌" })
        {
            var b = new Button { Text = ic, Size = new Size(28, 28), Location = new Point(iconX, 1), FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 10f), Cursor = Cursors.Hand };
            b.FlatAppearance.BorderSize = 0;
            b.Click += (s, e) => { if (ic == "🌐") ToggleSearch(); };
            tb.Controls.Add(b);
            iconX += 28;
        }

        // Right buttons
        var searchBtn = new Button { Text = "🔍", Dock = DockStyle.Right, Width = 30, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        searchBtn.FlatAppearance.BorderSize = 0;
        searchBtn.Click += (s, e) => ToggleSearch();
        tb.Controls.Add(searchBtn);

        var closeBtn = new Button { Text = "X", Dock = DockStyle.Right, Width = 46, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        closeBtn.FlatAppearance.BorderSize = 0;
        closeBtn.Click += (s, e) => Close();
        tb.Controls.Add(closeBtn);

        var maxBtn = new Button { Text = "□", Dock = DockStyle.Right, Width = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        maxBtn.FlatAppearance.BorderSize = 0;
        maxBtn.Click += (s, e) => WindowState = WindowState == FormWindowState.Normal ? FormWindowState.Maximized : FormWindowState.Normal;
        tb.Controls.Add(maxBtn);

        var minBtn = new Button { Text = "—", Dock = DockStyle.Right, Width = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        minBtn.FlatAppearance.BorderSize = 0;
        minBtn.Click += (s, e) => WindowState = FormWindowState.Minimized;
        tb.Controls.Add(minBtn);

        // ═══ TAB STRIP ═══
        tabStrip = new Panel { Dock = DockStyle.Top, Height = 30, BackColor = TITLEBAR };
        RefreshTabs();

        // ═══ STATUS BAR ═══
        var statusBar = new Panel { Dock = DockStyle.Bottom, Height = 28, BackColor = ACCENT, Padding = new Padding(10, 0, 10, 0) };
        statusLeft = new Label { Text = "Setup Process & Look Around  >", Font = new Font("Segoe UI", 8.5f), ForeColor = Color.White, Dock = DockStyle.Left, Width = 280, TextAlign = ContentAlignment.MiddleLeft, Cursor = Cursors.Hand };
        statusLeft.Click += (s, e) => Attach();
        statusBar.Controls.Add(statusLeft);
        var userIcon = new Label { Text = "👤", Font = new Font("Segoe UI", 9f), ForeColor = Color.White, Dock = DockStyle.Right, Width = 24, TextAlign = ContentAlignment.MiddleCenter };
        statusBar.Controls.Add(userIcon);
        statusRight = new Label { Text = "None", Font = new Font("Segoe UI", 8.5f), ForeColor = Color.White, Dock = DockStyle.Right, Width = 60, TextAlign = ContentAlignment.MiddleRight };
        statusBar.Controls.Add(statusRight);

        // ═══ BUTTON BAR ═══
        var btnBar = new Panel { Dock = DockStyle.Bottom, Height = 44, BackColor = BG, Padding = new Padding(10, 8, 10, 8) };

        var attachBtn = MakeBtn("⚖ Attach", BTN_BG, BTN_BORDER);
        attachBtn.Dock = DockStyle.Right;
        attachBtn.Width = 100;
        attachBtn.Click += (s, e) => Attach();
        btnBar.Controls.Add(attachBtn);

        var saveBtn = MakeBtn(" Save", BTN_BG, BTN_BORDER);
        saveBtn.Dock = DockStyle.Left;
        saveBtn.Width = 80;
        saveBtn.Click += (s, e) =>
        {
            using var sfd = new SaveFileDialog { Filter = "Lua (*.lua)|*.lua", DefaultExt = "lua" };
            if (sfd.ShowDialog() == DialogResult.OK) File.WriteAllText(sfd.FileName, editor.Text);
        };
        btnBar.Controls.Add(saveBtn);

        var openBtn = MakeBtn(" Open", BTN_BG, BTN_BORDER);
        openBtn.Dock = DockStyle.Left;
        openBtn.Width = 80;
        openBtn.Click += (s, e) =>
        {
            using var ofd = new OpenFileDialog { Filter = "Lua (*.lua;*.txt)|*.lua;*.txt|All|*.*" };
            if (ofd.ShowDialog() == DialogResult.OK)
            {
                editor.Text = File.ReadAllText(ofd.FileName);
                tabContents[activeTab] = editor.Text;
            }
        };
        btnBar.Controls.Add(openBtn);

        var clearBtn = MakeBtn(" Clear", BTN_BG, BTN_BORDER);
        clearBtn.Dock = DockStyle.Left;
        clearBtn.Width = 80;
        clearBtn.Click += (s, e) => { editor.Clear(); editor.Focus(); };
        btnBar.Controls.Add(clearBtn);

        var execBtn = MakeBtn(" Execute", GREEN, Color.FromArgb(60, 140, 60));
        execBtn.Dock = DockStyle.Left;
        execBtn.Width = 90;
        execBtn.Click += (s, e) => Execute();
        btnBar.Controls.Add(execBtn);

        // ═══ OUTPUT ═══
        outputPanel = new Panel { Dock = DockStyle.Bottom, Height = 100, BackColor = BG };
        var outputHeader = new Panel { Dock = DockStyle.Top, Height = 22, BackColor = TITLEBAR, Cursor = Cursors.Hand };
        var outputToggle = new Label { Text = "▶ Output", Font = new Font("Segoe UI", 8f), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(8, 0, 0, 0), Cursor = Cursors.Hand };
        outputToggle.Click += (s, e) => { outputPanel.Visible = !outputPanel.Visible; outputToggle.Text = outputPanel.Visible ? "▼ Output" : "▶ Output"; };
        outputHeader.Controls.Add(outputToggle);
        outputPanel.Controls.Add(outputHeader);
        outputBox = new RichTextBox { Dock = DockStyle.Fill, BackColor = BG, ForeColor = GREEN, Font = new Font("Consolas", 9f), BorderStyle = BorderStyle.None, ReadOnly = true, ScrollBars = RichTextBoxScrollBars.Vertical };
        outputPanel.Controls.Add(outputBox);

        // ═══ EDITOR ═══
        editor = new RichTextBox
        {
            Dock = DockStyle.Fill,
            BackColor = EDITOR_BG,
            ForeColor = Color.FromArgb(212, 212, 212),
            Font = new Font("Consolas", 10.5f),
            BorderStyle = BorderStyle.None,
            AcceptsTab = true,
            WordWrap = false,
            ScrollBars = RichTextBoxScrollBars.Both,
            DetectUrls = false,
            ShortcutsEnabled = true
        };
        editor.TextChanged += (s, e) => { if (activeTab >= 0 && activeTab < tabContents.Count) tabContents[activeTab] = editor.Text; };
        editor.KeyDown += (s, e) => { if (e.Control && e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; Execute(); } };

        // ═══ SEARCH OVERLAY ═══
        searchOverlay = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(180, 0, 0, 0), Visible = false };
        var searchBox = new Panel { Size = new Size(500, 420), BackColor = BG, Anchor = AnchorStyles.None };
        var sHeader = new Panel { Dock = DockStyle.Top, Height = 36, BackColor = TITLEBAR };
        searchInput = new TextBox { Dock = DockStyle.Fill, BackColor = Color.FromArgb(50, 50, 52), ForeColor = TEXT, Font = new Font("Segoe UI", 10f), BorderStyle = BorderStyle.None, PlaceholderText = "Search ScriptBlox..." };
        searchInput.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; DoSearch(); } };
        sHeader.Controls.Add(searchInput);
        var sClose = new Button { Text = "X", Dock = DockStyle.Right, Width = 30, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        sClose.FlatAppearance.BorderSize = 0;
        sClose.Click += (s, e) => ToggleSearch();
        sHeader.Controls.Add(sClose);
        searchResultsPanel = new Panel { Dock = DockStyle.Fill, BackColor = BG, AutoScroll = true, Padding = new Padding(4) };
        searchBox.Controls.Add(searchResultsPanel);
        searchBox.Controls.Add(sHeader);
        searchOverlay.Controls.Add(searchBox);
        Controls.Add(searchOverlay);

        // ═══ ASSEMBLE (order matters for docking) ═══
        Controls.Add(editor);
        Controls.Add(outputPanel);
        Controls.Add(btnBar);
        Controls.Add(tabStrip);
        Controls.Add(statusBar);
        Controls.Add(tb);

        ResumeLayout(false);
        Log("KRUX Executor ready");
        Log("Click 'Attach' to connect to Roblox");
    }

    // ═══════════════════════════════════════════
    //  TABS - simple Button-based, actually works
    // ═══════════════════════════════════════════
    void RefreshTabs()
    {
        tabStrip.SuspendLayout();
        tabStrip.Controls.Clear();

        for (int i = 0; i < tabNames.Count; i++)
        {
            int idx = i; // capture for closure

            var tab = new Button
            {
                Text = $"  ❝ {tabNames[idx]}  ×",
                Tag = idx,
                Dock = DockStyle.Left,
                Width = 130,
                FlatStyle = FlatStyle.Flat,
                BackColor = idx == activeTab ? EDITOR_BG : TITLEBAR,
                ForeColor = idx == activeTab ? TEXT : DIM,
                Font = new Font("Segoe UI", 8.5f),
                TextAlign = ContentAlignment.MiddleLeft,
                Padding = new Padding(6, 0, 0, 0),
                Cursor = Cursors.Hand
            };
            tab.FlatAppearance.BorderSize = 0;

            tab.Click += Tab_Click;

            tabStrip.Controls.Add(tab);
        }

        // "+" button
        var addTab = new Button
        {
            Text = "+",
            Dock = DockStyle.Left,
            Width = 30,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.Transparent,
            ForeColor = DIM,
            Font = new Font("Segoe UI", 11f, FontStyle.Bold),
            Cursor = Cursors.Hand
        };
        addTab.FlatAppearance.BorderSize = 0;
        addTab.Click += (s, e) =>
        {
            tabContents.Add("");
            tabNames.Add($"Script {tabNames.Count + 1}");
            activeTab = tabNames.Count - 1;
            editor.Text = tabContents[activeTab];
            RefreshTabs();
        };
        tabStrip.Controls.Add(addTab);

        tabStrip.ResumeLayout(false);
    }

    void Tab_Click(object? sender, EventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not int idx) return;

        // If clicking the "×" part of the text (last 2 chars)
        // We detect by checking if click is on the right portion
        // Simple approach: right-click or shift-click closes tab, left-click switches
        if (Control.MouseButtons == MouseButtons.Right)
        {
            // Right click = close tab
            if (tabNames.Count <= 1) return;
            tabContents.RemoveAt(idx);
            tabNames.RemoveAt(idx);
            if (activeTab >= tabNames.Count) activeTab = tabNames.Count - 1;
            editor.Text = tabContents[activeTab];
            RefreshTabs();
            return;
        }

        // Save current tab content
        if (activeTab >= 0 && activeTab < tabContents.Count)
            tabContents[activeTab] = editor.Text;

        // Switch tab
        activeTab = idx;
        editor.Text = tabContents[activeTab];
        RefreshTabs();
        editor.Focus();
    }

    // ═══════════════════════════════════════════
    //  SEARCH
    // ═══════════════════════════════════════════
    void ToggleSearch()
    {
        searchOverlay.Visible = !searchOverlay.Visible;
        if (searchOverlay.Visible)
        {
            searchOverlay.BringToFront();
            searchInput.Focus();
        }
    }

    async void DoSearch()
    {
        string q = searchInput.Text.Trim();
        if (string.IsNullOrEmpty(q)) return;

        searchResultsPanel.Controls.Clear();
        searchResultsPanel.Controls.Add(new Label { Text = "Loading...", Font = new Font("Segoe UI", 10f), ForeColor = DIM, Dock = DockStyle.Top, Height = 40, TextAlign = ContentAlignment.MiddleCenter });

        try
        {
            string url = $"https://scriptblox.com/api/script/search?mode=free&page=1&q={Uri.EscapeDataString(q)}";
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0");
            var json = await http.GetStringAsync(url);
            var doc = JsonDocument.Parse(json);
            searchResultsPanel.Controls.Clear();

            if (doc.RootElement.TryGetProperty("result", out var res) && res.TryGetProperty("scripts", out var scripts))
            {
                int y = 0;
                foreach (var s in scripts.EnumerateArray())
                {
                    string title = s.TryGetProperty("title", out var tEl) ? tEl.GetString() ?? "" : "";
                    string game = "";
                    if (s.TryGetProperty("game", out var gEl))
                    {
                        if (gEl.ValueKind == JsonValueKind.String)
                            game = gEl.GetString() ?? "";
                        else if (gEl.ValueKind == JsonValueKind.Object && gEl.TryGetProperty("name", out var gName))
                            game = gName.GetString() ?? "";
                    }
                    string scriptCode = s.TryGetProperty("script", out var scEl) ? scEl.GetString() ?? "" : "";

                    var card = new Panel { Location = new Point(0, y), Size = new Size(searchResultsPanel.Width - 20, 52), BackColor = Color.FromArgb(40, 40, 43), Padding = new Padding(10, 6, 10, 6) };
                    card.Controls.Add(new Label { Text = title.Length > 55 ? title[..55] + "..." : title, Font = new Font("Segoe UI", 9f, FontStyle.Bold), ForeColor = TEXT, Location = new Point(10, 4), AutoSize = true });
                    card.Controls.Add(new Label { Text = game.Length > 50 ? game[..50] + "..." : game, Font = new Font("Segoe UI", 7.5f), ForeColor = DIM, Location = new Point(10, 24), AutoSize = true });

                    string sc = scriptCode;
                    string scriptTitle = title;
                    var loadBtn = new Button { Text = "Load", Size = new Size(50, 22), FlatStyle = FlatStyle.Flat, BackColor = ACCENT, ForeColor = Color.White, Font = new Font("Segoe UI", 7.5f, FontStyle.Bold), Cursor = Cursors.Hand, Anchor = AnchorStyles.Top | AnchorStyles.Right };
                    loadBtn.FlatAppearance.BorderSize = 0;
                    loadBtn.Location = new Point(card.Width - 56, 14);
                    loadBtn.Click += (ss, ee) =>
                    {
                        tabContents[activeTab] = sc;
                        tabNames[activeTab] = scriptTitle.Length > 20 ? scriptTitle[..20] : scriptTitle;
                        editor.Text = sc;
                        editor.SelectionStart = 0;
                        editor.SelectionLength = 0;
                        editor.Focus();
                        RefreshTabs();
                        ToggleSearch();
                    };
                    card.Controls.Add(loadBtn);

                    searchResultsPanel.Controls.Add(card);
                    y += 56;
                }
            }

            if (searchResultsPanel.Controls.Count == 0)
                searchResultsPanel.Controls.Add(new Label { Text = "No results", Font = new Font("Segoe UI", 10f), ForeColor = DIM, Dock = DockStyle.Top, Height = 40, TextAlign = ContentAlignment.MiddleCenter });
        }
        catch (Exception ex)
        {
            searchResultsPanel.Controls.Clear();
            searchResultsPanel.Controls.Add(new Label { Text = $"Error: {ex.Message}", Font = new Font("Segoe UI", 9f), ForeColor = RED, Dock = DockStyle.Top, Height = 40, TextAlign = ContentAlignment.MiddleCenter });
        }
    }

    // ═══════════════════════════════════════════
    //  ATTACH / INJECT / PIPE
    // ═══════════════════════════════════════════
    async void Attach()
    {
        statusLeft.Text = "Searching for Roblox...";
        var procs = Process.GetProcessesByName("RobloxPlayerBeta");
        if (procs.Length == 0) procs = Process.GetProcesses().Where(p => p.ProcessName.ToLower().Contains("roblox")).ToArray();
        if (procs.Length == 0) { statusLeft.Text = "Roblox not found"; Log("Roblox not found"); return; }

        var proc = procs[0];
        statusLeft.Text = $"Injecting PID {proc.Id}...";
        Log($"Found Roblox PID {proc.Id}");

        string dllPath = Path.Combine(exeDir, "executor.dll");
        if (!File.Exists(dllPath)) { statusLeft.Text = "executor.dll missing"; Log($"Missing: {dllPath}"); return; }

        try
        {
            await Task.Run(() => InjectDLL(proc.Id, dllPath));
            await Task.Delay(1000);
            attached = true;
            statusLeft.Text = "Setup Process & Look Around  >";
            statusRight.Text = "Ready";
            Log("Injected successfully");
            _ = PipeListener();
        }
        catch (Exception ex) { statusLeft.Text = $"Failed"; Log($"Inject failed: {ex.Message}"); }
    }

    void InjectDLL(int pid, string dllPath)
    {
        var hProc = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
        if (hProc == IntPtr.Zero) throw new Exception("OpenProcess failed");
        var loadAddr = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryW");
        if (loadAddr == IntPtr.Zero) throw new Exception("LoadLibraryW not found");
        var pathBytes = Encoding.Unicode.GetBytes(dllPath + '\0');
        var allocAddr = VirtualAllocEx(hProc, IntPtr.Zero, (uint)pathBytes.Length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (allocAddr == IntPtr.Zero) throw new Exception("VirtualAllocEx failed");
        WriteProcessMemory(hProc, allocAddr, pathBytes, pathBytes.Length, out _);
        CreateRemoteThread(hProc, IntPtr.Zero, 0, loadAddr, allocAddr, 0, out _);
        CloseHandle(hProc);
    }

    async Task PipeListener()
    {
        while (true)
        {
            try
            {
                await using var server = new NamedPipeServerStream("KruxExecutor", PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                await server.WaitForConnectionAsync();
                Log("Client connected");
                using var reader = new StreamReader(server, Encoding.UTF8);
                while (server.IsConnected) { var line = await reader.ReadLineAsync(); if (line == null) break; Log(line); }
            }
            catch { await Task.Delay(1000); }
        }
    }

    void Execute()
    {
        string code = editor.Text;
        if (string.IsNullOrWhiteSpace(code)) return;
        try
        {
            using var client = new NamedPipeClientStream(".", "KruxExecutor", PipeDirection.Out);
            client.Connect(3000);
            using var w = new StreamWriter(client, Encoding.UTF8);
            w.Write(code);
            w.Flush();
            Log($"Executed ({code.Length} chars)");
        }
        catch (Exception ex) { Log($"Pipe error: {ex.Message}"); }
    }

    void Log(string msg)
    {
        if (outputBox == null || outputBox.IsDisposed) return;
        var ts = DateTime.Now.ToString("HH:mm:ss");
        outputBox.SelectionStart = outputBox.TextLength;
        outputBox.SelectionLength = 0;
        outputBox.SelectionColor = GREEN;
        outputBox.AppendText($"[{ts}] {msg}\n");
        outputBox.ScrollToCaret();
    }

    Button MakeBtn(string text, Color bg, Color border)
    {
        var b = new Button { Text = text, FlatStyle = FlatStyle.Flat, BackColor = bg, ForeColor = TEXT, Font = new Font("Segoe UI", 8.5f), Cursor = Cursors.Hand, Margin = new Padding(4, 0, 4, 0) };
        b.FlatAppearance.BorderColor = border;
        b.FlatAppearance.BorderSize = 1;
        b.MouseEnter += (s, e) => b.BackColor = ControlPaint.Light(bg, 0.1f);
        b.MouseLeave += (s, e) => b.BackColor = bg;
        return b;
    }

    const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
    const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, PAGE_READWRITE = 0x04;
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint a, bool i, int p);
    [DllImport("kernel32.dll")] static extern IntPtr GetProcAddress(IntPtr m, string n);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] d, int s, out int w);
    [DllImport("kernel32.dll")] static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr s, uint st, IntPtr sa, IntPtr p, uint f, out IntPtr t);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
}
