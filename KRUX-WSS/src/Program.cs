using System.Diagnostics;
using System.Net;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;

namespace KRUX;

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
    static readonly Color BG = Color.FromArgb(51, 51, 51);
    static readonly Color TOPBAR = Color.FromArgb(60, 60, 60);
    static readonly Color BTN_BG = Color.FromArgb(60, 60, 60);
    static readonly Color BTN_BORDER = Color.FromArgb(60, 60, 60);
    static readonly Color BTN_HOVER = Color.FromArgb(44, 61, 77);
    static readonly Color BTN_DOWN = Color.FromArgb(38, 70, 102);
    static readonly Color BTN_BORDER_HOVER = Color.FromArgb(134, 134, 134);
    static readonly Color EDITOR_BG = Color.FromArgb(45, 45, 45);
    static readonly Color SCRIPTS_BG = Color.FromArgb(60, 60, 60);
    static readonly Color TEXT = Color.White;

    HttpListener httpListener;
    CancellationTokenSource cts = new();
    readonly List<WebSocket> clients = new();
    readonly System.Windows.Forms.Timer updateTimer;
    RichTextBox scriptBox = null!;
    ListBox scriptsList = null!;
    Label titleLabel = null!;

    string exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');

    public MainForm()
    {
        SuspendLayout();
        Text = "KRUX";
        Size = new Size(801, 355);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor = BG;
        TopMost = true;
        DoubleBuffered = true;

        try
        {
            var asm = typeof(MainForm).Assembly;
            using var s = asm.GetManifestResourceStream("KRUX.KruxLogo.jpg");
            if (s != null) Icon = Icon.FromHandle(new Bitmap(s).GetHicon());
        }
        catch { }

        // ═══ TOP BAR ═══
        var topBar = new Panel { Dock = DockStyle.Top, Height = 30, BackColor = TOPBAR };
        bool drag = false; Point dragOff = Point.Empty;
        topBar.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { drag = true; dragOff = e.Location; } };
        topBar.MouseMove += (s, e) => { if (drag) Location = new Point(Location.X + e.X - dragOff.X, Location.Y + e.Y - dragOff.Y); };
        topBar.MouseUp += (s, e) => { drag = false; };

        var logo = new PictureBox
        {
            Size = new Size(25, 25),
            Location = new Point(5, 2),
            SizeMode = PictureBoxSizeMode.StretchImage,
            BackColor = Color.Transparent
        };
        try
        {
            var asm = typeof(MainForm).Assembly;
            using var s = asm.GetManifestResourceStream("KRUX.KruxLogo.jpg");
            if (s != null) logo.Image = new Bitmap(s);
        }
        catch { }
        logo.Click += (s, e) => MessageBox.Show(
            "KRUX Executor - WebSocket Edition\n\n" +
            "Based on WebSocket X by mov-ebx\n" +
            "https://github.com/game-hax/Roblox-Websocket-Executor\n\n" +
            "UI layout from Solara executor by n1eys\n" +
            "https://github.com/n1eys/Solara\n\n" +
            "Rebranded as KRUX for Windows",
            "KRUX", MessageBoxButtons.OK, MessageBoxIcon.Information);
        topBar.Controls.Add(logo);

        titleLabel = new Label
        {
            Text = "KRUX Executor v1.0",
            Font = new Font("Microsoft Sans Serif", 9f),
            ForeColor = TEXT,
            AutoSize = true,
            Location = new Point(357, 6),
            TextAlign = ContentAlignment.MiddleCenter
        };
        titleLabel.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { drag = true; dragOff = e.Location; } };
        titleLabel.MouseMove += (s, e) => { if (drag) Location = new Point(Location.X + e.X - dragOff.X, Location.Y + e.Y - dragOff.Y); };
        titleLabel.MouseUp += (s, e) => { drag = false; };
        topBar.Controls.Add(titleLabel);

        var exitBtn = MakeButton("X", new Point(780, 0), new Size(21, 21));
        exitBtn.Click += (s, e) => { StopServer(); Process.GetCurrentProcess().Kill(); };
        topBar.Controls.Add(exitBtn);

        var minBtn = MakeButton("_", new Point(759, 0), new Size(21, 21));
        minBtn.Click += (s, e) => WindowState = FormWindowState.Minimized;
        topBar.Controls.Add(minBtn);

        Controls.Add(topBar);

        // ═══ SCRIPT EDITOR ═══
        scriptBox = new RichTextBox
        {
            Dock = DockStyle.None,
            Location = new Point(3, 36),
            Size = new Size(673, 275),
            BackColor = EDITOR_BG,
            ForeColor = Color.FromArgb(204, 204, 204),
            Font = new Font("Courier New", 9f),
            BorderStyle = BorderStyle.None,
            AcceptsTab = true,
            WordWrap = false,
            ScrollBars = RichTextBoxScrollBars.Vertical,
            DetectUrls = false,
            ShortcutsEnabled = true
        };
        Controls.Add(scriptBox);

        // ═══ SCRIPTS LIST ═══
        scriptsList = new ListBox
        {
            Dock = DockStyle.None,
            Location = new Point(679, 37),
            Size = new Size(119, 270),
            BackColor = SCRIPTS_BG,
            ForeColor = TEXT,
            BorderStyle = BorderStyle.None,
            Font = new Font("Microsoft Sans Serif", 9f)
        };
        scriptsList.SelectedIndexChanged += ScriptsList_SelectedIndexChanged;
        Controls.Add(scriptsList);

        // ═══ BOTTOM BAR ═══
        int by = 316;
        int bw = 91;
        int gap = 6;

        var execBtn = MakeButton("Execute", new Point(5, by), new Size(bw, 33));
        execBtn.Click += (s, e) => ExecuteScript(scriptBox.Text);
        Controls.Add(execBtn);

        var clearBtn = MakeButton("Clear", new Point(5 + bw + gap, by), new Size(bw, 33));
        clearBtn.Click += (s, e) => scriptBox.Text = "";
        Controls.Add(clearBtn);

        var openBtn = MakeButton("Open File", new Point(5 + (bw + gap) * 2, by), new Size(bw, 33));
        openBtn.Click += OpenFile_Click;
        Controls.Add(openBtn);

        var execFileBtn = MakeButton("Execute File", new Point(5 + (bw + gap) * 3, by), new Size(bw, 33));
        execFileBtn.Click += ExecuteFile_Click;
        Controls.Add(execFileBtn);

        var saveBtn = MakeButton("Save File", new Point(5 + (bw + gap) * 4, by), new Size(bw, 33));
        saveBtn.Click += SaveFile_Click;
        Controls.Add(saveBtn);

        var optionsBtn = MakeButton("Options", new Point(5 + (bw + gap) * 5, by), new Size(bw, 33));
        optionsBtn.Click += (s, e) => MessageBox.Show("KRUX WebSocket Executor\n\nTopMost: Always on\nWebSocket: ws://127.0.0.1:8080\n\nLoad KRUX.lua in your executor's autoexec folder.", "Options", MessageBoxButtons.OK, MessageBoxIcon.Information);
        Controls.Add(optionsBtn);

        var scriptHubBtn = MakeButton("Script Hub", new Point(706, by), new Size(bw, 33));
        scriptHubBtn.Click += (s, e) => MessageBox.Show("Script Hub coming soon!\n\nFor now, paste scripts in the editor.", "KRUX", MessageBoxButtons.OK, MessageBoxIcon.Information);
        Controls.Add(scriptHubBtn);

        ResumeLayout(false);

        // ═══ START WEBSERVER ═══
        StartServer();

        // ═══ TIMER: AUTO-UPDATE SCRIPTS LIST ═══
        updateTimer = new System.Windows.Forms.Timer { Interval = 1000, Enabled = true };
        updateTimer.Tick += (s, e) => UpdateScriptsList();

        Log("KRUX Executor ready (WebSocket backend)");
        Log("Waiting for Roblox connection on ws://127.0.0.1:8080...");
        Log("Load KRUX.lua in your executor's autoexec folder.");
    }

    void StartServer()
    {
        httpListener = new HttpListener();
        httpListener.Prefixes.Add("http://127.0.0.1:8080/");
        httpListener.Start();
        _ = AcceptConnections();
    }

    void StopServer()
    {
        cts.Cancel();
        foreach (var ws in clients.ToArray())
        {
            try { ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None).Wait(500); } catch { }
        }
        try { httpListener.Stop(); } catch { }
    }

    async Task AcceptConnections()
    {
        while (!cts.Token.IsCancellationRequested)
        {
            try
            {
                var ctx = await httpListener.GetContextAsync();
                if (ctx.Request.IsWebSocketRequest)
                {
                    var wsCtx = await ctx.AcceptWebSocketAsync(null);
                    var ws = wsCtx.WebSocket;
                    lock (clients) clients.Add(ws);
                    Log($"Client connected ({clients.Count} total)");
                    _ = ReceiveLoop(ws);
                }
                else
                {
                    ctx.Response.StatusCode = 400;
                    ctx.Response.Close();
                }
            }
            catch (ObjectDisposedException) { break; }
            catch (HttpListenerException) { break; }
            catch { }
        }
    }

    async Task ReceiveLoop(WebSocket ws)
    {
        var buf = new byte[4096];
        try
        {
            while (ws.State == WebSocketState.Open && !cts.Token.IsCancellationRequested)
            {
                var result = await ws.ReceiveAsync(new ArraySegment<byte>(buf), cts.Token);
                if (result.MessageType == WebSocketMessageType.Close)
                {
                    await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None);
                }
                else
                {
                    var msg = Encoding.ASCII.GetString(buf, 0, result.Count);
                    if (msg == "autoexec")
                    {
                        SendAutoExec(ws);
                    }
                }
            }
        }
        catch { }
        finally
        {
            lock (clients) clients.Remove(ws);
            try { ws.Dispose(); } catch { }
            Log($"Client disconnected ({clients.Count} total)");
        }
    }

    void SendAutoExec(WebSocket ws)
    {
        var autoexecDir = Path.Combine(exeDir, "autoexec");
        if (!Directory.Exists(autoexecDir)) Directory.CreateDirectory(autoexecDir);
        foreach (var file in Directory.GetFiles(autoexecDir))
        {
            try
            {
                var content = File.ReadAllText(file);
                var bytes = Encoding.ASCII.GetBytes(content);
                ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None).Wait(1000);
            }
            catch { }
        }
    }

    void ExecuteScript(string script)
    {
        if (string.IsNullOrWhiteSpace(script)) return;
        List<WebSocket> snapshot;
        lock (clients) snapshot = new List<WebSocket>(clients);
        if (snapshot.Count == 0)
        {
            Log("No clients connected — load KRUX.lua in Roblox first");
            return;
        }
        var bytes = Encoding.ASCII.GetBytes(script);
        int sent = 0;
        foreach (var ws in snapshot)
        {
            try
            {
                if (ws.State == WebSocketState.Open)
                {
                    ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None).Wait(1000);
                    sent++;
                }
            }
            catch { }
        }
        Log($"Executed ({script.Length} chars) -> {sent} client(s)");
    }

    // ═══ UI BUTTON HELPER ═══
    Button MakeButton(string text, Point loc, Size size)
    {
        var btn = new Button
        {
            Text = text,
            Location = loc,
            Size = size,
            FlatStyle = FlatStyle.Flat,
            BackColor = BTN_BG,
            ForeColor = TEXT,
            Font = new Font("Microsoft Sans Serif", 10f),
            UseVisualStyleBackColor = false
        };
        btn.FlatAppearance.BorderColor = BTN_BORDER;
        btn.FlatAppearance.MouseDownBackColor = BTN_DOWN;
        btn.FlatAppearance.MouseOverBackColor = BTN_HOVER;
        btn.MouseEnter += (s, e) => btn.FlatAppearance.BorderColor = BTN_BORDER_HOVER;
        btn.MouseLeave += (s, e) => btn.FlatAppearance.BorderColor = BTN_BORDER;
        btn.MouseDown += (s, e) => btn.FlatAppearance.BorderColor = BTN_DOWN;
        btn.MouseUp += (s, e) => btn.FlatAppearance.BorderColor = BTN_BORDER_HOVER;
        return btn;
    }

    // ═══ FILE OPS ═══
    void OpenFile_Click(object? sender, EventArgs e)
    {
        using var ofd = new OpenFileDialog { InitialDirectory = Path.Combine(exeDir, "scripts"), Filter = "Script Files|*.lua;*.txt" };
        if (ofd.ShowDialog() == DialogResult.OK)
            scriptBox.Text = File.ReadAllText(ofd.FileName);
    }

    void ExecuteFile_Click(object? sender, EventArgs e)
    {
        using var ofd = new OpenFileDialog { InitialDirectory = Path.Combine(exeDir, "scripts"), Filter = "Script Files|*.lua;*.txt" };
        if (ofd.ShowDialog() == DialogResult.OK)
            ExecuteScript(File.ReadAllText(ofd.FileName));
    }

    void SaveFile_Click(object? sender, EventArgs e)
    {
        using var sfd = new SaveFileDialog { InitialDirectory = Path.Combine(exeDir, "scripts"), Filter = "Script Files|*.lua;*.txt" };
        if (sfd.ShowDialog() == DialogResult.OK)
            File.WriteAllText(sfd.FileName, scriptBox.Text);
    }

    // ═══ SCRIPTS LIST ═══
    void UpdateScriptsList()
    {
        var scriptsDir = Path.Combine(exeDir, "scripts");
        if (!Directory.Exists(scriptsDir)) Directory.CreateDirectory(scriptsDir);
        var files = Directory.GetFiles(scriptsDir);
        if (files.Length != scriptsList.Items.Count)
        {
            scriptsList.Items.Clear();
            foreach (var f in files) scriptsList.Items.Add(Path.GetFileName(f));
        }
    }

    void ScriptsList_SelectedIndexChanged(object? sender, EventArgs e)
    {
        if (scriptsList.SelectedIndex < 0) return;
        try
        {
            var scriptsDir = Path.Combine(exeDir, "scripts");
            var file = Path.Combine(scriptsDir, scriptsList.Items[scriptsList.SelectedIndex].ToString()!);
            scriptBox.Text = File.ReadAllText(file);
        }
        catch { }
    }

    // ═══ LOG ═══
    void Log(string msg)
    {
        Debug.WriteLine($"[KRUX] {msg}");
        Console.WriteLine($"[KRUX] {msg}");
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        StopServer();
        base.OnFormClosing(e);
    }
}
