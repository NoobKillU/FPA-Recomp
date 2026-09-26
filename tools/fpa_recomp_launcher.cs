using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

internal static class FpaRecompLauncher
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new LauncherForm());
    }
}

internal sealed class LauncherForm : Form
{
    private readonly TextBox executable = new TextBox();
    private readonly TextBox gameFolder = new TextBox();
    private readonly ComboBox resolution = new ComboBox();
    private readonly ComboBox controller = new ComboBox();
    private readonly CheckBox fullscreen = new CheckBox();
    private readonly CheckBox asyncShaders = new CheckBox();
    private readonly CheckBox waitForPipelines = new CheckBox();
    private readonly NumericUpDown pipelineThreads = new NumericUpDown();

    internal LauncherForm()
    {
        Text = "Fancy Pants Adventures Launcher";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        ClientSize = new Size(560, 390);
        Font = new Font("Segoe UI", 9F);

        AddLabel("Game executable", 16, 18, 150);
        executable.SetBounds(16, 42, 420, 25);
        Controls.Add(executable);
        AddButton("Browse...", 446, 40, 96, 28, BrowseExecutable);

        AddLabel("Game files folder", 16, 80, 150);
        gameFolder.SetBounds(16, 104, 420, 25);
        Controls.Add(gameFolder);
        AddButton("Browse...", 446, 102, 96, 28, BrowseGameFolder);
        AddLabel("The folder may be beside the executable or elsewhere.", 16, 132, 510);

        AddLabel("Resolution", 16, 171, 100);
        resolution.SetBounds(16, 195, 150, 26);
        resolution.DropDownStyle = ComboBoxStyle.DropDownList;
        resolution.Items.AddRange(new object[] { "720p", "1080p", "1440p", "4k", "1280x720" });
        resolution.SelectedItem = "720p";
        Controls.Add(resolution);

        fullscreen.Text = "Fullscreen";
        fullscreen.SetBounds(192, 196, 140, 24);
        Controls.Add(fullscreen);

        AddLabel("Controller", 16, 239, 100);
        controller.SetBounds(16, 263, 150, 26);
        controller.DropDownStyle = ComboBoxStyle.DropDownList;
        controller.Items.AddRange(new object[] { "SDL (recommended)", "XInput" });
        controller.SelectedIndex = 0;
        Controls.Add(controller);

        asyncShaders.Text = "Async shader compilation";
        asyncShaders.SetBounds(192, 264, 220, 24);
        asyncShaders.Checked = true;
        Controls.Add(asyncShaders);

        waitForPipelines.Text = "Wait for GPU pipelines";
        waitForPipelines.SetBounds(16, 303, 200, 24);
        Controls.Add(waitForPipelines);

        AddLabel("Pipeline worker threads", 250, 301, 160);
        pipelineThreads.SetBounds(414, 301, 75, 25);
        pipelineThreads.Minimum = 0;
        pipelineThreads.Maximum = 64;
        pipelineThreads.Value = 2;
        Controls.Add(pipelineThreads);

        AddButton("Save settings and launch", 332, 344, 210, 32, LaunchGame);
        AddButton("Save settings", 16, 344, 130, 32, SaveSettingsOnly);

        string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string nearbyExecutable = Path.Combine(appDirectory, "fpa_recomp.exe");
        string buildExecutable = Path.GetFullPath(Path.Combine(appDirectory, "..", "out", "build", "win-amd64-release", "fpa_recomp.exe"));
        if (File.Exists(nearbyExecutable)) executable.Text = nearbyExecutable;
        else if (File.Exists(buildExecutable)) executable.Text = buildExecutable;
        if (executable.Text.Length > 0) gameFolder.Text = Path.GetDirectoryName(executable.Text);
        LoadExistingSettings();
    }

    private void AddLabel(string text, int x, int y, int width)
    {
        Label label = new Label();
        label.Text = text;
        label.SetBounds(x, y, width, 24);
        Controls.Add(label);
    }

    private void AddButton(string text, int x, int y, int width, int height, EventHandler onClick)
    {
        Button button = new Button();
        button.Text = text;
        button.SetBounds(x, y, width, height);
        button.Click += onClick;
        Controls.Add(button);
    }

    private void BrowseExecutable(object sender, EventArgs e)
    {
        using (OpenFileDialog dialog = new OpenFileDialog())
        {
            dialog.Title = "Select the recompiled game executable";
            dialog.Filter = "Recompiled game (fpa_recomp.exe)|fpa_recomp.exe|Executable files (*.exe)|*.exe";
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                executable.Text = dialog.FileName;
                if (String.IsNullOrWhiteSpace(gameFolder.Text)) gameFolder.Text = Path.GetDirectoryName(dialog.FileName);
                LoadExistingSettings();
            }
        }
    }

    private void BrowseGameFolder(object sender, EventArgs e)
    {
        using (FolderBrowserDialog dialog = new FolderBrowserDialog())
        {
            dialog.Description = "Choose the folder containing the game files";
            dialog.ShowNewFolderButton = false;
            if (Directory.Exists(gameFolder.Text)) dialog.SelectedPath = gameFolder.Text;
            else if (File.Exists(executable.Text)) dialog.SelectedPath = Path.GetDirectoryName(executable.Text);
            if (dialog.ShowDialog(this) == DialogResult.OK) gameFolder.Text = dialog.SelectedPath;
        }
    }

    private void LoadExistingSettings()
    {
        if (!File.Exists(executable.Text)) return;
        string config = Path.Combine(Path.GetDirectoryName(executable.Text), "fpa_recomp.toml");
        if (!File.Exists(config)) return;

        Dictionary<string, string> values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (string rawLine in File.ReadAllLines(config))
        {
            string line = rawLine.Trim();
            int separator = line.IndexOf('=');
            if (line.Length == 0 || line.StartsWith("#") || separator < 1) continue;
            values[line.Substring(0, separator).Trim()] = line.Substring(separator + 1).Trim().Trim('"');
        }

        string value;
        if (values.TryGetValue("resolution", out value) && resolution.Items.Contains(value)) resolution.SelectedItem = value;
        if (values.TryGetValue("fullscreen", out value)) fullscreen.Checked = String.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
        if (values.TryGetValue("input_backend", out value)) controller.SelectedIndex = String.Equals(value, "xinput", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
        if (values.TryGetValue("async_shader_compilation", out value)) asyncShaders.Checked = String.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
        if (values.TryGetValue("d3d12_pipeline_creation_wait", out value)) waitForPipelines.Checked = String.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
        if (values.TryGetValue("d3d12_pipeline_creation_threads", out value))
        {
            decimal parsed;
            if (Decimal.TryParse(value, out parsed)) pipelineThreads.Value = Math.Min(pipelineThreads.Maximum, Math.Max(pipelineThreads.Minimum, parsed));
        }
    }

    private void SaveSettingsOnly(object sender, EventArgs e)
    {
        if (SaveSettings()) MessageBox.Show(this, "Settings saved beside the game executable.", "Settings saved", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private bool SaveSettings()
    {
        string exe = executable.Text.Trim();
        string root = gameFolder.Text.Trim();
        if (!File.Exists(exe))
        {
            MessageBox.Show(this, "Select a valid fpa_recomp.exe first.", "Executable not found", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return false;
        }
        if (!Directory.Exists(root))
        {
            MessageBox.Show(this, "Select the folder containing your game files.", "Game folder not found", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return false;
        }

        string backend = controller.SelectedIndex == 1 ? "xinput" : "sdl";
        string[] lines = new string[]
        {
            "resolution = \"" + EscapeToml(resolution.SelectedItem.ToString()) + "\"",
            "fullscreen = " + fullscreen.Checked.ToString().ToLowerInvariant(),
            "input_backend = \"" + backend + "\"",
            "async_shader_compilation = " + asyncShaders.Checked.ToString().ToLowerInvariant(),
            "d3d12_pipeline_creation_wait = " + waitForPipelines.Checked.ToString().ToLowerInvariant(),
            "d3d12_pipeline_creation_threads = " + pipelineThreads.Value.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "anisotropic_override = 0",
            "clear_memory_page_state = false",
            "mnk_mode = true",
            "keybind_lstick_up = \"Up\"",
            "keybind_lstick_down = \"Down\"",
            "keybind_lstick_left = \"Left\"",
            "keybind_lstick_right = \"Right\"",
            "keybind_a = \"S\"",
            "keybind_x = \"A\"",
            "keybind_start = \"Return\""
        };

        string destination = Path.Combine(Path.GetDirectoryName(exe), "fpa_recomp.toml");
        try
        {
            File.WriteAllLines(destination, lines, new UTF8Encoding(false));
            return true;
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Could not save settings", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return false;
        }
    }

    private void LaunchGame(object sender, EventArgs e)
    {
        if (!SaveSettings()) return;
        try
        {
            ProcessStartInfo start = new ProcessStartInfo(executable.Text.Trim());
            start.WorkingDirectory = Path.GetDirectoryName(executable.Text.Trim());
            start.UseShellExecute = false;
            start.EnvironmentVariables["FPA_GAME_ROOT"] = gameFolder.Text.Trim();
            Process.Start(start);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Could not launch game", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static string EscapeToml(string value)
    {
        return value.Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
