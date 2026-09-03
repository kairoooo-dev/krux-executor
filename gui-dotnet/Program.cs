using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text;

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
    // ── Solara-exact colors ──
    static readonly Color BG = Color.FromArgb(18, 18, 22);
    static readonly Color TITLEBAR_BG = Color.FromArgb(22, 22, 26);
    static readonly Color TAB_BG = Color.FromArgb(28, 28, 32);
    static readonly Color TAB_ACTIVE = Color.FromArgb(38, 32, 36);
    static readonly Color TAB_HOVER = Color.FromArgb(32, 30, 34);
    static readonly Color SIDEBAR_BG = Color.FromArgb(20, 20, 24);
    static readonly Color EDITOR_BG = Color.FromArgb(20, 18, 22);
    static readonly Color EXPLORER_BG = Color.FromArgb(22, 22, 26);
    static readonly Color GREEN_DOT = Color.FromArgb(0, 200, 80);
    static readonly Color GREEN = Color.FromArgb(0, 200, 80);
    static readonly Color RED = Color.FromArgb(220, 60, 60);
    static readonly Color TEXT = Color.FromArgb(180, 180, 180);
    static readonly Color BRIGHT = Color.FromArgb(230, 230, 230);
    static readonly Color DIM = Color.FromArgb(100, 100, 100);
    static readonly Color BORDER = Color.FromArgb(40, 40, 44);
    static readonly Color LINE_NUM = Color.FromArgb(80, 75, 85);

    // ── Xeno DLL P/Invoke ──
    [DllImport("Xeno.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern void Initialize();

    [DllImport("Xeno.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern IntPtr GetClients();

    [DllImport("Xeno.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    static extern void Execute(byte[] scriptSource, string[] clientUsers, int numUsers);

    [DllImport("Xeno.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    static extern IntPtr Compilable(byte[] scriptSource);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    struct ClientInfo
    {
        public IntPtr version;
        public IntPtr name;
        public int id;
    }

    string exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
    bool attached = false;
    bool autoAttach = true;
    readonly System.Windows.Forms.Timer attachWatcher;
    readonly System.Windows.Forms.Timer clientPollTimer;

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
    Panel lineNumberPanel = null!;
    Label clientLabel = null!;

    bool drag = false; Point dragOff;

    public MainForm()
    {
        SuspendLayout();
        Text = "KRUX";
        Size = new Size(950, 620);
        MinimumSize = new Size(750, 480);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor = BG;
        try { var asm = typeof(MainForm).Assembly; using var s = asm.GetManifestResourceStream("KruxExecutor.KruxLogo.jpg"); if (s != null) Icon = Icon.FromHandle(new Bitmap(s).GetHicon()); } catch { }
        DoubleBuffered = true;

        // ═══ TITLEBAR ═══
        var tb = new Panel { Dock = DockStyle.Top, Height = 32, BackColor = TITLEBAR_BG };
        tb.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { drag = true; dragOff = e.Location; } };
        tb.MouseMove += (s, e) => { if (drag) Location = new Point(Location.X + e.X - dragOff.X, Location.Y + e.Y - dragOff.Y); };
        tb.MouseUp += (s, e) => { drag = false; };

        var logoPanel = new Panel { Dock = DockStyle.Left, Width = 120, BackColor = Color.Transparent };
        var tbLogo = new Label { Text = "  KRUX", Font = new Font("Segoe UI", 9.5f, FontStyle.Bold), ForeColor = BRIGHT, Dock = DockStyle.Left, Width = 70, TextAlign = ContentAlignment.MiddleLeft };
        logoPanel.Controls.Add(tbLogo);
        statusDot = new Label { Text = "\u25CF", Font = new Font("Segoe UI", 9f), ForeColor = RED, Dock = DockStyle.Left, Width = 20, TextAlign = ContentAlignment.MiddleCenter };
        logoPanel.Controls.Add(statusDot);
        tb.Controls.Add(logoPanel);

        var closeBtn = new Button { Text = "X", Dock = DockStyle.Right, Width = 44, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 8.5f) };
        closeBtn.FlatAppearance.BorderSize = 0;
        closeBtn.Click += (s, e) => Close();
        tb.Controls.Add(closeBtn);
        var maxBtn = new Button { Text = "\u25A1", Dock = DockStyle.Right, Width = 30, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 8.5f) };
        maxBtn.FlatAppearance.BorderSize = 0;
        maxBtn.Click += (s, e) => WindowState = WindowState == FormWindowState.Normal ? FormWindowState.Maximized : FormWindowState.Normal;
        tb.Controls.Add(maxBtn);
        var minBtn = new Button { Text = "\u2014", Dock = DockStyle.Right, Width = 30, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 8.5f) };
        minBtn.FlatAppearance.BorderSize = 0;
        minBtn.Click += (s, e) => WindowState = FormWindowState.Minimized;
        tb.Controls.Add(minBtn);

        // ═══ TAB STRIP ═══
        tabStrip = new Panel { Dock = DockStyle.Top, Height = 32, BackColor = TAB_BG };
        RefreshTabs();

        // ═══ LEFT SIDEBAR ═══
        var sidebar = new Panel { Dock = DockStyle.Left, Width = 32, BackColor = SIDEBAR_BG };
        var icons = new[] { "\u2699", "\u25B6", "\u2630" };
        for (int i = 0; i < icons.Length; i++)
        {
            int idx = i;
            var btn = new Button { Text = icons[i], Size = new Size(32, 32), FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 11f), Dock = DockStyle.Top, Cursor = Cursors.Hand };
            btn.FlatAppearance.BorderSize = 0;
            btn.MouseEnter += (s, e) => btn.ForeColor = TEXT;
            btn.MouseLeave += (s, e) => btn.ForeColor = DIM;
            btn.Click += (s, e) => { if (idx == 2) ToggleExplorer(); };
            sidebar.Controls.Add(btn);
        }

        // ═══ RIGHT EXPLORER PANEL ═══
        explorerPanel = new Panel { Dock = DockStyle.Right, Width = 200, BackColor = EXPLORER_BG, Visible = true };
        var exHeader = new Panel { Dock = DockStyle.Top, Height = 26, BackColor = EXPLORER_BG };
        exHeader.Controls.Add(new Label { Text = "  EXPLORER", Font = new Font("Segoe UI", 7.5f, FontStyle.Bold), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft });
        explorerPanel.Controls.Add(exHeader);
        explorerTree = new TreeView { Dock = DockStyle.Fill, BackColor = EXPLORER_BG, ForeColor = TEXT, Font = new Font("Consolas", 9f), BorderStyle = BorderStyle.None, ShowLines = true, ShowPlusMinus = true, ShowRootLines = true, ItemHeight = 22, LineColor = BORDER, HideSelection = false };
        explorerTree.DrawMode = TreeViewDrawMode.OwnerDrawText;
        explorerTree.DrawNode += (s, e) =>
        {
            e.Graphics.FillRectangle(new SolidBrush(explorerTree.BackColor), e.Bounds);
            var brush = e.Node.IsSelected ? new SolidBrush(BRIGHT) : new SolidBrush(e.Node.Level == 0 ? BRIGHT : TEXT);
            e.Graphics.DrawString(e.Node.Text, explorerTree.Font, brush, e.Bounds.X, e.Bounds.Y);
        };
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

        // ═══ BOTTOM BAR ═══
        var bottomBar = new Panel { Dock = DockStyle.Bottom, Height = 30, BackColor = SIDEBAR_BG, Padding = new Padding(6, 0, 6, 0) };
        var bottomIcons = new[] { "\u2699", "\u25B6", "\u25A0", "\u27A1" };
        int bx = 4;
        foreach (var ic in bottomIcons)
        {
            var b = new Button { Text = ic, Size = new Size(26, 26), Location = new Point(bx, 2), FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 9f), Cursor = Cursors.Hand };
            b.FlatAppearance.BorderSize = 0;
            b.MouseEnter += (s2, e2) => b.ForeColor = TEXT;
            b.MouseLeave += (s2, e2) => b.ForeColor = DIM;
            b.Click += (s2, e2) => { if (ic == "\u25B6") ExecuteScript(); };
            bottomBar.Controls.Add(b);
            bx += 28;
        }

        var attachBtn = new Button { Text = "Attach", Dock = DockStyle.Right, Width = 70, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(0, 120, 60), ForeColor = Color.White, Font = new Font("Segoe UI", 8f, FontStyle.Bold), Cursor = Cursors.Hand };
        attachBtn.FlatAppearance.BorderSize = 0;
        attachBtn.Click += (s, e) => Attach();
        bottomBar.Controls.Add(attachBtn);

        statusText = new Label { Text = "Not Attached", Font = new Font("Segoe UI", 7.5f), ForeColor = DIM, Dock = DockStyle.Right, Width = 80, TextAlign = ContentAlignment.MiddleRight };
        bottomBar.Controls.Add(statusText);

        clientLabel = new Label { Text = "Clients: 0", Font = new Font("Segoe UI", 7.5f), ForeColor = DIM, Dock = DockStyle.Right, Width = 80, TextAlign = ContentAlignment.MiddleRight };
        bottomBar.Controls.Add(clientLabel);

        // ═══ EDITOR ═══
        var editorPanel = new Panel { Dock = DockStyle.Fill, BackColor = EDITOR_BG };
        lineNumberPanel = new Panel { Dock = DockStyle.Left, Width = 40, BackColor = EDITOR_BG };
        lineNumberPanel.Paint += (s, e) =>
        {
            e.Graphics.Clear(EDITOR_BG);
            var font = new Font("Consolas", 10.5f);
            var brush = new SolidBrush(LINE_NUM);
            int lineY = 2;
            int lineH = (int)e.Graphics.MeasureString("W", font).Height;
            int count = editor.Lines.Length;
            for (int i = 0; i < count && lineY < editorPanel.Height; i++)
            {
                e.Graphics.DrawString((i + 1).ToString(), font, brush, new PointF(4, lineY));
                lineY += lineH;
            }
        };
        editorPanel.Controls.Add(lineNumberPanel);

        editor = new RichTextBox
        {
            Dock = DockStyle.Fill,
            BackColor = EDITOR_BG,
            ForeColor = TEXT,
            Font = new Font("Consolas", 10.5f),
            BorderStyle = BorderStyle.None,
            AcceptsTab = true,
            WordWrap = false,
            ScrollBars = RichTextBoxScrollBars.Vertical,
            DetectUrls = false,
            ShortcutsEnabled = true,
            Padding = new Padding(4, 4, 4, 4)
        };
        editor.TextChanged += (s, e) =>
        {
            if (activeTab >= 0 && activeTab < tabContents.Count) tabContents[activeTab] = editor.Text;
            lineNumberPanel.Invalidate();
        };
        editor.VScroll += (s, e) => lineNumberPanel.Invalidate();
        editor.KeyDown += (s, e) => { if (e.Control && e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; ExecuteScript(); } };
        editorPanel.Controls.Add(editor);

        // ═══ OUTPUT ═══
        outputPanel = new Panel { Dock = DockStyle.Bottom, Height = 80, BackColor = BG, Visible = true };
        var outputHeader = new Panel { Dock = DockStyle.Top, Height = 18, BackColor = TAB_BG, Cursor = Cursors.Hand };
        var outputToggle = new Label { Text = "  Output", Font = new Font("Segoe UI", 7f), ForeColor = DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Cursor = Cursors.Hand };
        outputToggle.Click += (s, e) => { outputPanel.Visible = !outputPanel.Visible; };
        outputHeader.Controls.Add(outputToggle);
        outputPanel.Controls.Add(outputHeader);
        outputBox = new RichTextBox { Dock = DockStyle.Fill, BackColor = BG, ForeColor = GREEN, Font = new Font("Consolas", 8.5f), BorderStyle = BorderStyle.None, ReadOnly = true, ScrollBars = RichTextBoxScrollBars.Vertical };
        outputPanel.Controls.Add(outputBox);

        // ═══ ASSEMBLE ═══
        Controls.Add(editorPanel);
        Controls.Add(explorerPanel);
        Controls.Add(outputPanel);
        Controls.Add(bottomBar);
        Controls.Add(tabStrip);
        Controls.Add(sidebar);
        Controls.Add(tb);

        ResumeLayout(false);
        Log("KRUX Executor ready (Xeno backend)");
        Log("Auto-attach ON — waiting for Roblox...");

        // ═══ XENO DLL POLLING ═══
        clientPollTimer = new System.Windows.Forms.Timer { Interval = 2000 };
        clientPollTimer.Tick += (s, e) => UpdateClientList();
        clientPollTimer.Start();

        attachWatcher = new System.Windows.Forms.Timer { Interval = 2000 };
        attachWatcher.Tick += (s, e) =>
        {
            if (!autoAttach || attached) return;
            var procs = Process.GetProcessesByName("RobloxPlayerBeta");
            if (procs.Length > 0) { attachWatcher.Stop(); Attach(); }
        };
        attachWatcher.Start();
    }

    // ═══════════════════════════════════════════
    //  TABS
    // ═══════════════════════════════════════════
    void RefreshTabs()
    {
        tabStrip.SuspendLayout();
        tabStrip.Controls.Clear();
        var addTab = new Button { Text = "+", Dock = DockStyle.Left, Width = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 10f, FontStyle.Bold), Cursor = Cursors.Hand };
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
            var tab = new Panel { Tag = idx, Dock = DockStyle.Left, Width = 120, BackColor = idx == activeTab ? TAB_ACTIVE : TAB_BG, Cursor = Cursors.Hand };
            var tabLabel = new Label { Text = "  " + tabNames[idx], Font = new Font("Segoe UI", 8f), ForeColor = idx == activeTab ? BRIGHT : DIM, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Tag = idx };
            tabLabel.Click += Tab_Click;
            tabLabel.MouseEnter += (s, e) => { if (idx != activeTab) tab.BackColor = TAB_HOVER; };
            tabLabel.MouseLeave += (s, e) => { if (idx != activeTab) tab.BackColor = TAB_BG; };
            tab.Controls.Add(tabLabel);
            var closeTab = new Button { Text = "x", Dock = DockStyle.Right, Width = 20, FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = DIM, Font = new Font("Segoe UI", 7f), Tag = idx, Cursor = Cursors.Hand };
            closeTab.FlatAppearance.BorderSize = 0;
            closeTab.Click += Tab_Close;
            tab.Controls.Add(closeTab);
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
    void ToggleExplorer() { explorerPanel.Visible = !explorerPanel.Visible; }

    void LoadExplorerTree()
    {
        explorerTree.Nodes.Clear();
        var root = new TreeNode("KRUX") { Tag = exeDir };
        var autoexec = Path.Combine(exeDir, "autoexec");
        if (!Directory.Exists(autoexec)) Directory.CreateDirectory(autoexec);
        var aeNode = new TreeNode("autoexec") { Tag = autoexec };
        foreach (var f in Directory.GetFiles(autoexec, "*.lua"))
            aeNode.Nodes.Add(new TreeNode(Path.GetFileName(f)) { Tag = f });
        root.Nodes.Add(aeNode);
        var scripts = Path.Combine(exeDir, "scripts");
        if (!Directory.Exists(scripts)) Directory.CreateDirectory(scripts);
        var scNode = new TreeNode("scripts") { Tag = scripts };
        foreach (var f in Directory.GetFiles(scripts, "*.lua"))
            scNode.Nodes.Add(new TreeNode(Path.GetFileName(f)) { Tag = f });
        root.Nodes.Add(scNode);
        root.Expand(); aeNode.Expand(); scNode.Expand();
        explorerTree.Nodes.Add(root);
    }

    // ═══════════════════════════════════════════
    //  XENO DLL ATTACH
    // ═══════════════════════════════════════════
    void Attach()
    {
        statusText.Text = "Initializing...";
        try
        {
            string dllPath = Path.Combine(exeDir, "Xeno.dll");
            if (!File.Exists(dllPath)) { statusText.Text = "No DLL"; Log($"Missing: {dllPath}"); return; }

            Initialize();
            attached = true;
            statusDot.ForeColor = GREEN_DOT;
            statusText.Text = "Attached";
            statusText.ForeColor = GREEN_DOT;
            Log("Xeno DLL initialized!");
            UpdateClientList();
        }
        catch (Exception ex) { statusText.Text = "Failed"; Log($"Attach failed: {ex.Message}"); }
    }

    void UpdateClientList()
    {
        if (!attached) return;
        try
        {
            IntPtr currentPtr = GetClients();
            if (currentPtr == IntPtr.Zero) { clientLabel.Text = "Clients: 0"; return; }
            int count = 0;
            while (true)
            {
                var client = Marshal.PtrToStructure<ClientInfo>(currentPtr);
                if (client.name == IntPtr.Zero) break;
                string name = Marshal.PtrToStringAnsi(client.name) ?? "";
                if (name == "N/A" || string.IsNullOrEmpty(name)) break;
                count++;
                currentPtr += Marshal.SizeOf<ClientInfo>();
            }
            clientLabel.Text = $"Clients: {count}";
            if (count > 0 && statusText.Text != "Attached")
            {
                statusDot.ForeColor = GREEN_DOT;
                statusText.Text = "Attached";
                statusText.ForeColor = GREEN_DOT;
                attached = true;
            }
        }
        catch { }
    }

    // ═══════════════════════════════════════════
    //  EXECUTE
    // ═══════════════════════════════════════════
    void ExecuteScript()
    {
        string code = editor.Text;
        if (string.IsNullOrWhiteSpace(code)) return;
        try
        {
            IntPtr currentPtr = GetClients();
            var users = new List<string>();
            while (true)
            {
                var client = Marshal.PtrToStructure<ClientInfo>(currentPtr);
                if (client.name == IntPtr.Zero) break;
                string name = Marshal.PtrToStringAnsi(client.name) ?? "";
                if (name == "N/A" || string.IsNullOrEmpty(name)) break;
                users.Add(name);
                currentPtr += Marshal.SizeOf<ClientInfo>();
            }
            if (users.Count == 0) { Log("No clients found"); return; }
            Execute(Encoding.UTF8.GetBytes(code), users.ToArray(), users.Count);
            Log($"Executed ({code.Length} chars) -> {users.Count} client(s)");
        }
        catch (Exception ex) { Log($"Execute error: {ex.Message}"); }
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
}
