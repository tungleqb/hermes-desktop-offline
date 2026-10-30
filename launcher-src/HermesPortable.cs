// HermesPortable.exe — dependency-free launcher stub for Hermes Desktop Offline.
// Reads config\hermes-portable.ini next to the install root, exports env, spawns app\Hermes.exe.
using System;
using System.IO;
using System.Diagnostics;

class HermesPortable
{
    static string Root()
    {
        string exe = Environment.GetCommandLineArgs()[0];
        string dir = Path.GetDirectoryName(Path.GetFullPath(exe));
        // launcher sits in <root>\launcher
        return Directory.Exists(Path.Combine(dir, "app")) ? dir : Path.GetDirectoryName(dir);
    }

    static void Main(string[] args)
    {
        string root = Root();
        string iniPath = Path.Combine(root, "config", "hermes-portable.ini");
        var ini = new System.Collections.Generic.Dictionary<string, string>();
        if (File.Exists(iniPath))
        {
            foreach (var raw in File.ReadAllLines(iniPath))
            {
                string line = raw.Trim();
                if (line == "" || line.StartsWith(";") || line.StartsWith("[")) continue;
                int eq = line.IndexOf('=');
                if (eq > 0) ini[line.Substring(0, eq).Trim()] = line.Substring(eq + 1).Trim();
            }
        }
        string Get(string k, string d) => ini.ContainsKey(k) ? ini[k] : d;

        string dataRoot  = Get("data_root", Path.Combine(root, "data"));
        string workRoot  = Get("work_root", Path.Combine(root, "work"));
        string cacheRoot = Get("cache_root", Path.Combine(root, "cache"));

        string appExe = Path.Combine(root, "app", "Hermes.exe");
        if (!File.Exists(appExe))
        {
            Console.WriteLine("ERROR: app\\Hermes.exe not found under " + root);
            Console.WriteLine("Run setup.ps1 first.");
            Environment.Exit(1);
        }

        if (args.Length > 0 && (args[0] == "--setup" || args[0] == "-setup"))
        {
            var ps = new Process();
            ps.StartInfo.FileName = "powershell.exe";
            ps.StartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(root, "launcher", "setup.ps1") + "\"";
            ps.StartInfo.UseShellExecute = false;
            ps.Start();
            ps.WaitForExit();
            return;
        }

        var env = new ProcessStartInfo();
        env.FileName = appExe;
        env.WorkingDirectory = workRoot;
        env.UseShellExecute = false;
        env.Environment["HERMES_HOME"] = dataRoot;
        env.Environment["HERMES_RUNTIME_DIR"] = Path.Combine(root, "runtime");
        env.Environment["HERMES_BUNDLED_SKILLS"] = Path.Combine(root, "skills-bundle", "skills");
        env.Environment["HERMES_OPTIONAL_SKILLS"] = Path.Combine(root, "skills-bundle", "optional-skills");
        env.Environment["HERMES_BUNDLED_PLUGINS"] = Path.Combine(root, "skills-bundle", "plugins");
        env.Environment["HERMES_OFFLINE"] = "1";
        env.Environment["PYTHONUTF8"] = "1";
        env.Environment["HERMES_PORTABLE_ROOT"] = root;
        Console.WriteLine("Launching Hermes Desktop (offline portable)");
        Console.WriteLine("  HERMES_HOME = " + dataRoot);
        Console.WriteLine("  work dir    = " + workRoot);
        var p = Process.Start(env);
        p.WaitForExit();
        Environment.Exit(p.ExitCode);
    }
}
