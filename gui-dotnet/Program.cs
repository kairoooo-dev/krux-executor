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
    // ── Theme ──
    static readonly Color BG = Color.FromArgb(30, 30, 30);
    static readonly Color SIDEBAR_BG = Color.FromArgb(24, 24, 28);
    static readonly Color TITLEBAR = Color.FromArgb(32, 32, 36);
    static readonly Color TAB_ACTIVE = Color.FromArgb(40, 40, 44);
    static readonly Color TAB_HOVER = Color.FromArgb(36, 36, 40);
    static readonly Color EDITOR_BG = Color.FromArgb(28, 28, 32);
    static readonly Color PANEL_BG = Color.FromArgb(26, 26, 30);
    static readonly Color BTN_BG = Color.FromArgb(44, 44, 48);
    static readonly Color ACCENT = Color.FromArgb(0, 150, 80);
    static readonly Color GREEN = Color.FromArgb(0, 200, 80);
    static readonly Color RED = Color.FromArgb(220, 60, 60);
    static readonly Color TEXT = Color.FromArgb(200, 200, 200);
    static readonly Color DIM = Color.FromArgb(120, 120, 120);
    static readonly Color BORDER = Color.FromArgb(50, 50, 54);

    string exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
    bool attached = false;
    bool autoAttach = true;
    readonly System.Windows.Forms.Timer attachWatcher;

    readonly List<string> tabContents = new() { "" };
    readonly List<string> tabNames = new() { "Script" };
    int activeTab = 0;

    RichTextBox editor = null!;
    Panel outputPanel = null!;
    RichTextBox outputBox = null!;
    Label statusDot = null!;
    Label statusText = null!;
    Panel tabStrip = null!;
    Panel explorerPanel = null!;
    TreeView explorerTree = null!;

    bool drag = false; Point dragOff;

    public MainForm()
    {
        SuspendLayout();
        Text = "KRUX";
        Size = new Size(900, 600);
        MinimumSize = new Size(700, 450);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor = BG;
        try { var asm = typeof(MainForm).Assembly; using var s = asm.GetManifestResourceStream("KruxExecutor.KruxLogo.jpg"); if (s != null) Icon = Icon.FromHandle(new Bitmap(s).GetHicon()); } catch { }
        DoubleBuffered = true;

        // ═══ TITLEBAR ═══
        var tb = new Panel { Dock = DockStyle.Top, Height = 36, BackColor = TITLEBAR };
        tb.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { drag = true; dragOff = e.Location; } };
        tb.MouseMove += (s, e) => { if (drag) Location = new Point(Location.X + e.X - dragOff.X, Location.Y + e.Y - dragOff.Y); };
        tb.MouseUp += (s, e) => { drag = false; };

        var tbLogo = new Label { Text = "  KRUX", Font = new Font("Segoe UI", 9.5f, FontStyle.Bold), ForeColor = Color.White, Dock = DockStyle.Left, Width = 80, TextAlign = ContentAlignment.MiddleLeft };
        tb.Controls.Add(tbLogo);

        statusDot = new Label { Text = "\u25CF", Font = new Font("Segoe UI", 10f), ForeColor = RED, Dock = DockStyle.Left, Width = 24, TextAlign = ContentAlignment.MiddleCenter };
        tb.Controls.Add(statusDot);

        statusText = new Label { Text = "Not Attached", Font = new Font("Segoe UI", 8f), ForeColor = DIM, Dock = DockStyle.Left, Width = 90, TextAlign = ContentAlignment.MiddleLeft };
        tb.Controls.Add(statusText);

        var closeBtn = new Button { Text = "X", Dock = DockStyle.Right, Width = 46, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        closeBtn.FlatAppearance.BorderSize = 0;
        closeBtn.Click += (s, e) => Close();
        tb.Controls.Add(closeBtn);

        var maxBtn = new Button { Text = "\u25A1", Dock = DockStyle.Right, Width = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        maxBtn.FlatAppearance.BorderSize = 0;
        maxBtn.Click += (s, e) => WindowState = WindowState == FormWindowState.Normal ? FormWindowState.Maximized : FormWindowState.Normal;
        tb.Controls.Add(maxBtn);

        var minBtn = new Button { Text = "\u2014", Dock = DockStyle.Right, Width = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f) };
        minBtn.FlatAppearance.BorderSize = 0;
        minBtn.Click += (s, e) => WindowState = FormWindowState.Minimized;
        tb.Controls.Add(minBtn);

        // ═══ TAB STRIP ═══
        tabStrip = new Panel { Dock = DockStyle.Top, Height = 34, BackColor = TITLEBAR };
        RefreshTabs();

        // ═══ LEFT SIDEBAR ═══
        var sidebar = new Panel { Dock = DockStyle.Left, Width = 36, BackColor = SIDEBAR_BG };
        var sideIcons = new[] { "\u2699", "\u25B6", "\u2630" };
        for (int i = 0; i < sideIcons.Length; i++)
        {
            var btn = new Button { Text = sideIcons[i], Size = new Size(36, 36), FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 12f), Dock = DockStyle.Top, Cursor = Cursors.Hand };
            btn.FlatAppearance.BorderSize = 0;
            int idx = i;
            btn.Click += (s, e) => { if (idx == 2) ToggleExplorer(); };
            sidebar.Controls.Add(btn);
        }
        sidebar.Controls.Add(new Panel { Dock = DockStyle.Top, Height = 10, BackColor = SIDEBAR_BG });

        // ═══ EXPLORER PANEL ═══
        explorerPanel = new Panel { Dock = DockStyle.Right, Width = 200, BackColor = PANEL_BG, Visible = true };
        var exHeader = new Panel { Dock = DockStyle.Top, Height = 28, BackColor = TITLEBAR };
        exHeader.Controls.Add(new Label { Text = "  EXPLORER", Font = new Font("Segoe UI", 8f, FontStyle.Bold), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft });
        explorerPanel.Controls.Add(exHeader);

        explorerTree = new TreeView { Dock = DockStyle.Fill, BackColor = PANEL_BG, ForeColor = TEXT, Font = new Font("Consolas", 9f), BorderStyle = BorderStyle.None, ShowLines = true, ShowPlusMinus = true, ShowRootLines = true, ItemHeight = 22, LineColor = BORDER };
        explorerTree.NodeMouseDoubleClick += (s, e) =>
        {
            if (explorerTree.SelectedNode?.Tag is string filePath && File.Exists(filePath))
            {
                editor.Text = File.ReadAllText(filePath);
                tabContents[activeTab] = editor.Text;
                tabNames[activeTab] = Path.GetFileName(filePath);
                RefreshTabs();
            }
        };
        LoadExplorerTree();
        explorerPanel.Controls.Add(explorerTree);

        // ═══ STATUS BAR ═══
        var statusBar = new Panel { Dock = DockStyle.Bottom, Height = 28, BackColor = SIDEBAR_BG, Padding = new Padding(10, 0, 10, 0) };
        var attachBtn = new Button { Text = " Attach", Dock = DockStyle.Right, Width = 90, FlatStyle = FlatStyle.Flat, BackColor = ACCENT, ForeColor = Color.White, Font = new Font("Segoe UI", 8.5f, FontStyle.Bold), Cursor = Cursors.Hand };
        attachBtn.FlatAppearance.BorderSize = 0;
        attachBtn.Click += (s, e) => Attach();
        statusBar.Controls.Add(attachBtn);
        statusLeft = new Label { Text = "  Ready", Font = new Font("Segoe UI", 8f), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
        statusBar.Controls.Add(statusLeft);
        var autoLabel = new Label { Text = "Auto", Font = new Font("Segoe UI", 8f), ForeColor = GREEN, Dock = DockStyle.Right, Width = 40, TextAlign = ContentAlignment.MiddleCenter, Cursor = Cursors.Hand };
        autoLabel.Click += (s, e) => { autoAttach = !autoAttach; autoLabel.ForeColor = autoAttach ? GREEN : RED; };
        statusBar.Controls.Add(autoLabel);

        // ═══ BUTTON BAR ═══
        var btnBar = new Panel { Dock = DockStyle.Bottom, Height = 38, BackColor = BG, Padding = new Padding(6, 6, 6, 6) };

        var execBtn = MakeBtn(" Execute", GREEN, Color.FromArgb(0, 160, 60));
        execBtn.Dock = DockStyle.Right;
        execBtn.Width = 90;
        execBtn.Click += (s, e) => Execute();
        btnBar.Controls.Add(execBtn);

        var clearBtn = MakeBtn(" Clear", BTN_BG, BORDER);
        clearBtn.Dock = DockStyle.Right;
        clearBtn.Width = 60;
        clearBtn.Click += (s, e) => { editor.Clear(); editor.Focus(); };
        btnBar.Controls.Add(clearBtn);

        var openBtn = MakeBtn(" Open", BTN_BG, BORDER);
        openBtn.Dock = DockStyle.Right;
        openBtn.Width = 60;
        openBtn.Click += (s, e) =>
        {
            using var ofd = new OpenFileDialog { Filter = "Lua (*.lua;*.txt)|*.lua;*.txt|All|*.*" };
            if (ofd.ShowDialog() == DialogResult.OK)
            {
                editor.Text = File.ReadAllText(ofd.FileName);
                tabContents[activeTab] = editor.Text;
                tabNames[activeTab] = Path.GetFileName(ofd.FileName);
                RefreshTabs();
            }
        };
        btnBar.Controls.Add(openBtn);

        var saveBtn = MakeBtn(" Save", BTN_BG, BORDER);
        saveBtn.Dock = DockStyle.Right;
        saveBtn.Width = 60;
        saveBtn.Click += (s, e) =>
        {
            using var sfd = new SaveFileDialog { Filter = "Lua (*.lua)|*.lua", DefaultExt = "lua" };
            if (sfd.ShowDialog() == DialogResult.OK) File.WriteAllText(sfd.FileName, editor.Text);
        };
        btnBar.Controls.Add(saveBtn);

        // ═══ OUTPUT ═══
        outputPanel = new Panel { Dock = DockStyle.Bottom, Height = 90, BackColor = BG };
        var outputHeader = new Panel { Dock = DockStyle.Top, Height = 20, BackColor = TITLEBAR, Cursor = Cursors.Hand };
        var outputToggle = new Label { Text = "  Output", Font = new Font("Segoe UI", 7.5f), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Cursor = Cursors.Hand };
        outputToggle.Click += (s, e) => { outputPanel.Visible = !outputPanel.Visible; };
        outputHeader.Controls.Add(outputToggle);
        outputPanel.Controls.Add(outputHeader);
        outputBox = new RichTextBox { Dock = DockStyle.Fill, BackColor = BG, ForeColor = GREEN, Font = new Font("Consolas", 9f), BorderStyle = BorderStyle.None, ReadOnly = true, ScrollBars = RichTextBoxScrollBars.Vertical };
        outputPanel.Controls.Add(outputBox);

        // ═══ EDITOR ═══
        editor = new RichTextBox
        {
            Dock = DockStyle.Fill,
            BackColor = EDITOR_BG,
            ForeColor = TEXT,
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

        // ═══ ASSEMBLE ═══
        Controls.Add(editor);
        Controls.Add(explorerPanel);
        Controls.Add(outputPanel);
        Controls.Add(btnBar);
        Controls.Add(tabStrip);
        Controls.Add(statusBar);
        Controls.Add(sidebar);
        Controls.Add(tb);

        ResumeLayout(false);
        Log("KRUX Executor ready");
        Log("Auto-attach is ON — waiting for Roblox...");

        // ═══ AUTO-ATTACH WATCHER ═══
        attachWatcher = new System.Windows.Forms.Timer { Interval = 2000 };
        attachWatcher.Tick += (s, e) =>
        {
            if (!autoAttach || attached) return;
            var procs = Process.GetProcessesByName("RobloxPlayerBeta");
            if (procs.Length > 0)
            {
                attachWatcher.Stop();
                Attach();
            }
        };
        attachWatcher.Start();
    }

    Label statusLeft = null!;

    // ═══════════════════════════════════════════
    //  TABS
    // ═══════════════════════════════════════════
    void RefreshTabs()
    {
        tabStrip.SuspendLayout();
        tabStrip.Controls.Clear();

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
            tabNames.Add($"Script {tabNames.Count}");
            activeTab = tabNames.Count - 1;
            editor.Text = tabContents[activeTab];
            RefreshTabs();
        };
        tabStrip.Controls.Add(addTab);

        for (int i = tabNames.Count - 1; i >= 0; i--)
        {
            int idx = i;
            var tab = new Panel
            {
                Tag = idx,
                Dock = DockStyle.Left,
                Width = 130,
                BackColor = idx == activeTab ? TAB_ACTIVE : TITLEBAR,
                Cursor = Cursors.Hand
            };

            var tabLabel = new Label
            {
                Text = "  " + tabNames[idx],
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = idx == activeTab ? TEXT : DIM,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft,
                Tag = idx
            };
            tabLabel.Click += Tab_Click;
            tab.Controls.Add(tabLabel);

            var closeBtn = new Button
            {
                Text = "x",
                Dock = DockStyle.Right,
                Width = 22,
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.Transparent,
                ForeColor = DIM,
                Font = new Font("Segoe UI", 7.5f),
                Tag = idx,
                Cursor = Cursors.Hand
            };
            closeBtn.FlatAppearance.BorderSize = 0;
            closeBtn.Click += Tab_Close;
            tab.Controls.Add(closeBtn);

            tabStrip.Controls.Add(tab);
        }

        tabStrip.ResumeLayout(false);
    }

    void Tab_Click(object? sender, EventArgs e)
    {
        if (sender is not Label lbl || lbl.Tag is not int idx) return;
        if (idx == activeTab) return;
        tabContents[activeTab] = editor.Text;
        activeTab = idx;
        editor.Text = tabContents[activeTab];
        RefreshTabs();
        editor.Focus();
    }

    void Tab_Close(object? sender, EventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not int idx) return;
        if (tabNames.Count <= 1) return;
        tabContents.RemoveAt(idx);
        tabNames.RemoveAt(idx);
        if (activeTab >= tabNames.Count) activeTab = tabNames.Count - 1;
        editor.Text = tabContents[activeTab];
        RefreshTabs();
    }

    // ═══════════════════════════════════════════
    //  EXPLORER
    // ═══════════════════════════════════════════
    void ToggleExplorer()
    {
        explorerPanel.Visible = !explorerPanel.Visible;
    }

    void LoadExplorerTree()
    {
        explorerTree.Nodes.Clear();
        var root = new TreeNode("KRUX") { Tag = exeDir };

        var autoexec = Path.Combine(exeDir, "autoexec");
        if (!Directory.Exists(autoexec)) Directory.CreateDirectory(autoexec);
        var autoexecNode = new TreeNode("autoexec") { Tag = autoexec };
        foreach (var f in Directory.GetFiles(autoexec, "*.lua"))
            autoexecNode.Nodes.Add(new TreeNode(Path.GetFileName(f)) { Tag = f });
        root.Nodes.Add(autoexecNode);

        var scripts = Path.Combine(exeDir, "scripts");
        if (!Directory.Exists(scripts)) Directory.CreateDirectory(scripts);
        var scriptsNode = new TreeNode("scripts") { Tag = scripts };
        foreach (var f in Directory.GetFiles(scripts, "*.lua"))
            scriptsNode.Nodes.Add(new TreeNode(Path.GetFileName(f)) { Tag = f });
        root.Nodes.Add(scriptsNode);

        root.Expand();
        autoexecNode.Expand();
        scriptsNode.Expand();
        explorerTree.Nodes.Add(root);
    }

    // ═══════════════════════════════════════════
    //  ATTACH / INJECT / PIPE
    // ═══════════════════════════════════════════
    async void Attach()
    {
        statusLeft.Text = "  Searching for Roblox...";
        var procs = Process.GetProcessesByName("RobloxPlayerBeta");
        if (procs.Length == 0) procs = Process.GetProcesses().Where(p => p.ProcessName.ToLower().Contains("roblox")).ToArray();
        if (procs.Length == 0) { statusLeft.Text = "  Roblox not found"; Log("Roblox not found — waiting..."); attachWatcher?.Start(); return; }

        var proc = procs[0];
        statusLeft.Text = $"  Injecting PID {proc.Id}...";
        Log($"Found Roblox PID {proc.Id}");

        string dllPath = Path.Combine(exeDir, "executor.dll");
        if (!File.Exists(dllPath)) { statusLeft.Text = "  executor.dll missing"; Log($"Missing: {dllPath}"); return; }

        try
        {
            await Task.Run(() => InjectDLL(proc.Id, dllPath));
            await Task.Delay(1000);
            attached = true;
            statusDot.ForeColor = GREEN;
            statusText.Text = "Attached";
            statusText.ForeColor = GREEN;
            statusLeft.Text = "  Attached to Roblox";
            Log("Attached successfully!");
            Log("You can now execute scripts.");
            _ = PipeListener();
        }
        catch (Exception ex)
        {
            statusLeft.Text = "  Attach failed";
            Log($"Inject failed: {ex.Message}");
        }
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
                Log("DLL connected via pipe");
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
        var b = new Button { Text = text, FlatStyle = FlatStyle.Flat, BackColor = bg, ForeColor = TEXT, Font = new Font("Segoe UI", 8f), Cursor = Cursors.Hand };
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
