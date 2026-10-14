// Host files, SHA256, paths and counters only. No BF/model execution or arithmetic.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Tartarus.IOAuditV2
{
    public sealed class PhaseTiming
    {
        public string Phase;
        public long Completed;
        public long Total;
        public long ElapsedMilliseconds;
        public bool Complete;
    }
    public sealed class AuditReport
    {
        public string Status = "PASS";
        public string Operation;
        public long Bindings;
        public long Origins;
        public long UniqueRawFiles;
        public string SHA256;
        public int Workers;
        public long ElapsedMilliseconds;
        public bool ModelArithmetic = false;
        public int BFExecutions = 0;
        public Dictionary<string, long> Kinds = new Dictionary<string, long>(StringComparer.Ordinal);
        public List<PhaseTiming> Phases = new List<PhaseTiming>();
    }
    public sealed class ProgressPhase : IDisposable
    {
        private readonly string name;
        private readonly AuditReport report;
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private readonly object gate = new object();
        private readonly Timer timer;
        private readonly int every;
        private long completed;
        private long total;
        private long printed;
        private bool closed;
        private bool success;
        public ProgressPhase(AuditReport reportValue, string phase, long count, int progressEvery, int seconds)
        {
            report = reportValue; name = phase; total = count; every = progressEvery;
            if (every > 0 || seconds > 0) Print("START");
            if (seconds > 0) timer = new Timer(delegate { lock (gate) { if (!closed) Print("WORK"); } }, null, seconds * 1000, seconds * 1000);
        }
        private void Print(string state)
        {
            Console.WriteLine("IO {0} {1} {2}/{3} elapsed={4:F1}s", state, name,
                Interlocked.Read(ref completed), total < 0 ? "?" : total.ToString(), clock.Elapsed.TotalSeconds);
        }
        public void Tick()
        {
            long value = Interlocked.Increment(ref completed);
            if (every > 0 && value % every == 0)
                lock (gate) { if (!closed && value > printed) { printed = value; Print("WORK"); } }
        }
        public void Finish(long exactTotal) { total = exactTotal; success = true; }
        public void Dispose()
        {
            lock (gate)
            {
                closed = true; if (timer != null) timer.Dispose(); clock.Stop();
                report.Phases.Add(new PhaseTiming { Phase = name, Completed = completed, Total = total,
                    ElapsedMilliseconds = clock.ElapsedMilliseconds, Complete = success });
                if (every > 0 || timer != null) Print(success ? "DONE" : "FAIL");
            }
        }
    }
    public sealed class HashEntry
    {
        public string Path;
        public byte[] Expected;
        public string Actual;
    }
    public static class Files
    {
        public static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
        public static string Root(string value)
        {
            string root = Path.GetFullPath(value).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (!Directory.Exists(root + Path.DirectorySeparatorChar)) throw new InvalidDataException("Audit root missing");
            return root;
        }
        public static string Within(string root, string value)
        {
            if (String.IsNullOrWhiteSpace(value)) throw new InvalidDataException("Audit path empty");
            string path = Path.GetFullPath(Path.Combine(root + Path.DirectorySeparatorChar, value));
            if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Audit path outside root");
            return path;
        }
        public static byte[] HashBytes(string text)
        {
            if (text == null || text.Length != 64) throw new InvalidDataException("Audit SHA256 shape");
            var value = new byte[32];
            for (int i = 0; i < value.Length; i++)
            {
                int a = Hex(text[i * 2]), b = Hex(text[i * 2 + 1]);
                if (a < 0 || b < 0) throw new InvalidDataException("Audit SHA256 shape");
                value[i] = (byte)(a * 16 + b);
            }
            return value;
        }
        private static int Hex(char ch) { return ch >= '0' && ch <= '9' ? ch - '0' : ch >= 'A' && ch <= 'F' ? ch - 'A' + 10 : -1; }
        public static string HexHash(byte[] value) { return BitConverter.ToString(value).Replace("-", ""); }
        public static bool Same(byte[] a, byte[] b)
        { if (a.Length != b.Length) return false; for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false; return true; }
        public static string Hash(string path)
        {
            using (var hash = SHA256.Create()) using (var stream = ReadFile(path)) return HexHash(hash.ComputeHash(stream));
        }
        public static FileStream ReadFile(string path)
        {
            try { return new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 65536, FileOptions.SequentialScan); }
            catch (Exception error) { throw new IOException("Audit file unavailable: " + path, error); }
        }
        public static Dictionary<string, object> ReadObject(string path)
        { using (var json = MetadataJson.Open(path)) return MetadataJson.Object(json.Read()); }
        public static void WriteNew(string path, string text)
        {
            using (var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                byte[] bytes = Utf8.GetBytes(text); file.Write(bytes, 0, bytes.Length); file.Flush(true);
            }
        }
        public static void HashAll(List<HashEntry> entries, AuditReport report, string phase, int workers, int every, int seconds, bool create)
        {
            using (var progress = new ProgressPhase(report, phase, entries.Count, every, seconds))
            {
                try
                {
                    Parallel.For(0, entries.Count, new ParallelOptions { MaxDegreeOfParallelism = workers },
                        () => SHA256.Create(), (i, state, hash) =>
                        {
                            HashEntry entry = entries[i];
                            using (var stream = ReadFile(entry.Path))
                            {
                                if (entry.Expected != null || create)
                                {
                                    byte[] actual = hash.ComputeHash(stream);
                                    if (entry.Expected != null && !Same(actual, entry.Expected))
                                        throw new InvalidDataException("Audit SHA256 mismatch: " + entry.Path);
                                    if (create) entry.Actual = HexHash(actual);
                                }
                            }
                            progress.Tick(); return hash;
                        }, hash => hash.Dispose());
                }
                catch (AggregateException failure)
                { Exception first = failure.Flatten().InnerExceptions[0]; throw new InvalidDataException(first.Message, first); }
                progress.Finish(entries.Count);
            }
        }
        private static AuditReport Report(string operation, int workers)
        {
            if (workers < 1 || workers > 16) throw new ArgumentOutOfRangeException("workers");
            return new AuditReport { Operation = operation, Workers = workers };
        }
        public static AuditReport VerifyManifest(string rootValue, string manifestValue, string sealValue, int workers, int every, int seconds)
        {
            var clock = Stopwatch.StartNew(); var report = Report("verify-manifest", workers);
            string root = Root(rootValue), manifest = Within(root, manifestValue), seal = Within(root, sealValue);
            long count; string expected;
            using (var phase = new ProgressPhase(report, "manifest-seal", 1, every, seconds))
            {
                var value = ReadObject(seal); count = MetadataJson.Integer(value, "Bindings");
                expected = MetadataJson.Text(value, "SHA256"); HashBytes(expected);
                if (!String.Equals(Hash(manifest), expected, StringComparison.Ordinal)) throw new InvalidDataException("Audit manifest seal mismatch");
                phase.Tick(); phase.Finish(1);
            }
            var entries = new List<HashEntry>(); var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (var phase = new ProgressPhase(report, "manifest-read", count, every, seconds))
            using (var json = MetadataJson.Open(manifest))
            {
                json.ArrayObjects(row =>
                {
                    string path = Within(root, MetadataJson.Text(row, "Path"));
                    if (!seen.Add(path)) throw new InvalidDataException("Audit duplicate path");
                    entries.Add(new HashEntry { Path = path, Expected = HashBytes(MetadataJson.Text(row, "SHA256")) });
                    phase.Tick();
                });
                if (entries.Count != count) throw new InvalidDataException("Audit manifest count mismatch");
                phase.Finish(count);
            }
            HashAll(entries, report, "artifact-hash", workers, every, seconds, false);
            report.Bindings = entries.Count; report.SHA256 = expected; report.ElapsedMilliseconds = clock.ElapsedMilliseconds;
            return report;
        }
        public static AuditReport BuildManifest(string rootValue, string directoryValue, string manifestValue, string sealValue,
            string[] excludedValues, int workers, int every, int seconds)
        {
            var clock = Stopwatch.StartNew(); var report = Report("build-manifest", workers);
            string root = Root(rootValue), directory = Within(root, directoryValue);
            string manifest = Within(root, manifestValue), seal = Within(root, sealValue);
            if (String.Equals(manifest, seal, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Audit output paths collide");
            string partial = manifest + ".partial";
            foreach (string path in new[] { manifest, seal, partial })
                if (File.Exists(path) || Directory.Exists(path)) throw new InvalidDataException("Audit output already exists: " + path);
            var exclude = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { manifest, seal, partial };
            if (excludedValues != null) foreach (string path in excludedValues) exclude.Add(Within(root, path));
            var entries = new List<HashEntry>();
            using (var phase = new ProgressPhase(report, "artifact-enumerate", -1, every, seconds))
            {
                var pending = new Stack<string>(); pending.Push(directory);
                while (pending.Count > 0)
                {
                    string parent = pending.Pop();
                    if ((File.GetAttributes(parent) & FileAttributes.ReparsePoint) != 0) throw new InvalidDataException("Audit reparse directory");
                    foreach (string path in Directory.EnumerateFileSystemEntries(parent))
                    {
                        if (exclude.Contains(path)) continue;
                        FileAttributes attributes = File.GetAttributes(path);
                        if ((attributes & FileAttributes.ReparsePoint) != 0) throw new InvalidDataException("Audit reparse entry");
                        if ((attributes & FileAttributes.Directory) != 0) pending.Push(path);
                        else { entries.Add(new HashEntry { Path = path }); phase.Tick(); }
                    }
                }
                entries.Sort((a, b) => StringComparer.Ordinal.Compare(a.Path, b.Path)); phase.Finish(entries.Count);
            }
            HashAll(entries, report, "artifact-hash", workers, every, seconds, true);
            using (var phase = new ProgressPhase(report, "manifest-write", entries.Count, every, seconds))
            {
                using (var file = new FileStream(partial, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    using (var writer = new StreamWriter(file, Utf8, 65536, true))
                    {
                        writer.Write('['); bool first = true;
                        foreach (HashEntry entry in entries)
                        {
                            if (!first) writer.Write(','); first = false;
                            writer.Write("{\"Path\":" + MetadataJson.Quote(entry.Path.Substring(root.Length + 1)) +
                                ",\"SHA256\":" + MetadataJson.Quote(entry.Actual) + "}"); phase.Tick();
                        }
                        writer.Write(']'); writer.Flush();
                    }
                    file.Flush(true);
                }
                File.Move(partial, manifest); report.SHA256 = Hash(manifest);
                WriteNew(seal, MetadataJson.Encode(new Dictionary<string, object> { { "Bindings", entries.Count }, { "SHA256", report.SHA256 } }));
                phase.Finish(entries.Count);
            }
            report.Bindings = entries.Count; report.ElapsedMilliseconds = clock.ElapsedMilliseconds; return report;
        }
        public static AuditReport AuditRaw(string rootValue, string directoryValue, string[] inventories, int workers, int every, int seconds)
        {
            var clock = Stopwatch.StartNew(); var report = Report("audit-legacy-raw", workers);
            string root = Root(rootValue), directory = Within(root, directoryValue);
            if (inventories == null || inventories.Length == 0) throw new InvalidDataException("Audit inventories required");
            var entries = new List<HashEntry>(); var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (var phase = new ProgressPhase(report, "raw-inventories", -1, every, seconds))
            {
                foreach (string inventory in inventories)
                using (var json = MetadataJson.Open(Within(directory, inventory)))
                    json.ArrayObjects(row =>
                    {
                        string kind = MetadataJson.Text(row, "Kind");
                        foreach (string field in new[] { "InputPath", "OutputPath", "MetadataPath" })
                        {
                            string path = Within(directory, MetadataJson.Text(row, field));
                            if (!seen.Add(path)) throw new InvalidDataException("Audit raw duplicate path");
                            entries.Add(new HashEntry { Path = path, Expected = field == "MetadataPath" ? null :
                                HashBytes(MetadataJson.Text(row, field == "InputPath" ? "InputSHA256" : "OutputSHA256")) });
                        }
                        if (!report.Kinds.ContainsKey(kind)) report.Kinds.Add(kind, 0);
                        report.Kinds[kind]++; report.Origins++; phase.Tick();
                    });
                phase.Finish(report.Origins);
            }
            HashAll(entries, report, "raw-hash-and-presence", workers, every, seconds, false);
            report.UniqueRawFiles = entries.Count; report.ElapsedMilliseconds = clock.ElapsedMilliseconds; return report;
        }
        public static long CompareManifests(string rootValue, string first, string second)
        {
            string root = Root(rootValue);
            var rows = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            using (var json = MetadataJson.Open(Within(root, first)))
                json.ArrayObjects(row =>
                {
                    string path = Within(root, MetadataJson.Text(row, "Path"));
                    string hash = MetadataJson.Text(row, "SHA256"); HashBytes(hash);
                    if (rows.ContainsKey(path)) throw new InvalidDataException("Compare duplicate path");
                    rows.Add(path, hash);
                });
            long count = rows.Count;
            using (var json = MetadataJson.Open(Within(root, second)))
                json.ArrayObjects(row =>
                {
                    string path = Within(root, MetadataJson.Text(row, "Path")); string expected;
                    if (!rows.TryGetValue(path, out expected) || !String.Equals(expected, MetadataJson.Text(row, "SHA256"), StringComparison.Ordinal))
                        throw new InvalidDataException("Compare manifest entry mismatch");
                    rows.Remove(path);
                });
            if (rows.Count != 0) throw new InvalidDataException("Compare manifest coverage mismatch");
            return count;
        }
    }
}
