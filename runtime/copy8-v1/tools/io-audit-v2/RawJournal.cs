// Copies ready input/output bytes. Does not launch BF, cache requests or interpret results.
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
    public sealed class JournalSummary
    {
        public string Status = "SEALED";
        public string Directory;
        public long Origins;
        public int Blocks;
        public long PayloadBytes;
        public int PhysicalFiles;
        public long ElapsedMilliseconds;
        public List<PhaseTiming> Phases = new List<PhaseTiming>();
        public bool ModelArithmetic = false;
        public int BFExecutions = 0;
    }
    public sealed class RecoveredOrigin
    {
        public long Id;
        public string Source;
        public string Phase;
        public string Kind;
        public byte[] Input;
        public byte[] Output;
    }
    public sealed class RawJournalWriter : IDisposable
    {
        private readonly string directory;
        private readonly long byteLimit;
        private readonly int originLimit;
        private readonly int flushEvery;
        private readonly List<object> blocks = new List<object>();
        private FileStream data, indexFile;
        private StreamWriter index;
        private string dataName, indexName;
        private long origins, payloadBytes, blockOrigins, firstOrigin;
        private bool sealedJournal, disposed, faulted;
        public RawJournalWriter(string outputDirectory, long blockBytes, int blockOriginsLimit, int flushInterval)
        {
            if (blockBytes < 1 || blockOriginsLimit < 1 || flushInterval < 1) throw new ArgumentOutOfRangeException("journal limits");
            directory = Path.GetFullPath(outputDirectory);
            if (Directory.Exists(directory) || File.Exists(directory)) throw new InvalidDataException("Journal output already exists");
            Directory.CreateDirectory(directory); byteLimit = blockBytes; originLimit = blockOriginsLimit; flushEvery = flushInterval;
        }
        private void OpenBlock()
        {
            string id = blocks.Count.ToString("D6", System.Globalization.CultureInfo.InvariantCulture);
            dataName = "block-" + id + ".bin"; indexName = "block-" + id + ".jsonl";
            data = new FileStream(Path.Combine(directory, dataName), FileMode.CreateNew, FileAccess.Write, FileShare.Read, 65536);
            indexFile = new FileStream(Path.Combine(directory, indexName), FileMode.CreateNew, FileAccess.Write, FileShare.Read, 65536);
            index = new StreamWriter(indexFile, Files.Utf8, 65536, true);
            firstOrigin = origins; blockOrigins = 0;
        }
        private void CloseBlock()
        {
            if (data == null) return;
            index.Flush(); data.Flush(true); indexFile.Flush(true); long length = data.Position;
            index.Dispose(); index = null; data.Dispose(); data = null; indexFile.Dispose(); indexFile = null;
            blocks.Add(new Dictionary<string, object> {
                { "DataFile", dataName }, { "IndexFile", indexName }, { "FirstOrigin", firstOrigin },
                { "Origins", blockOrigins }, { "DataLength", length },
                { "DataSHA256", Files.Hash(Path.Combine(directory, dataName)) },
                { "IndexSHA256", Files.Hash(Path.Combine(directory, indexName)) }
            });
        }
        public long Append(string source, string phase, string kind, byte[] input, byte[] output)
        {
            if (disposed || sealedJournal || faulted) throw new InvalidOperationException("Journal writer closed or failed");
            if (String.IsNullOrEmpty(source) || String.IsNullOrEmpty(phase) || String.IsNullOrEmpty(kind) || input == null || output == null)
                throw new InvalidDataException("Journal origin fields");
            try
            {
                long length = (long)input.Length + output.Length;
                if (data != null && (blockOrigins >= originLimit || data.Position + length > byteLimit)) CloseBlock();
                if (data == null) OpenBlock();
                long inputOffset = data.Position; data.Write(input, 0, input.Length);
                long outputOffset = data.Position; data.Write(output, 0, output.Length);
                string inputHash, outputHash;
                using (var hash = SHA256.Create()) { inputHash = Files.HexHash(hash.ComputeHash(input)); outputHash = Files.HexHash(hash.ComputeHash(output)); }
                index.WriteLine(MetadataJson.Encode(new Dictionary<string, object> {
                    { "Id", origins }, { "Source", source }, { "Phase", phase }, { "Kind", kind },
                    { "InputOffset", inputOffset }, { "InputLength", input.Length }, { "InputSHA256", inputHash },
                    { "OutputOffset", outputOffset }, { "OutputLength", output.Length }, { "OutputSHA256", outputHash }
                }));
                long id = origins; origins++; blockOrigins++; payloadBytes += length;
                if (blockOrigins % flushEvery == 0) { index.Flush(); data.Flush(); }
                return id;
            }
            catch { faulted = true; throw; }
        }
        public JournalSummary Complete()
        {
            if (disposed || sealedJournal || faulted) throw new InvalidOperationException("Journal writer closed or failed");
            try
            {
                CloseBlock();
                string partial = Path.Combine(directory, "journal-seal.json.partial");
                Files.WriteNew(partial, MetadataJson.Encode(new Dictionary<string, object> {
                    { "Format", "tartarus-raw-blocks-v2" }, { "Closed", true }, { "Origins", origins }, { "Blocks", blocks }
                }));
                File.Move(partial, Path.Combine(directory, "journal-seal.json")); sealedJournal = true;
                return new JournalSummary { Directory = directory, Origins = origins, Blocks = blocks.Count,
                    PayloadBytes = payloadBytes, PhysicalFiles = blocks.Count * 2 + 1 };
            }
            catch { faulted = true; throw; }
        }
        public void Dispose()
        {
            if (disposed) return; disposed = true;
            try { if (index != null) index.Dispose(); }
            finally { try { if (data != null) data.Dispose(); } finally { if (indexFile != null) indexFile.Dispose(); } }
            // Disposal after a failed/incomplete run deliberately never publishes a seal.
        }
    }
    public sealed class JournalBlock
    {
        public string Data, Index, DataHash, IndexHash;
        public long First, Count, Length;
    }
    public static class Journals
    {
        private static List<JournalBlock> Load(string directory, out long origins)
        {
            var seal = Files.ReadObject(Path.Combine(directory, "journal-seal.json")); object closed, blockValue;
            if (MetadataJson.Text(seal, "Format") != "tartarus-raw-blocks-v2" || !seal.TryGetValue("Closed", out closed) || !(closed is bool) || !(bool)closed)
                throw new InvalidDataException("Journal incomplete or format");
            origins = MetadataJson.Integer(seal, "Origins");
            if (!seal.TryGetValue("Blocks", out blockValue) || !(blockValue is List<object>)) throw new InvalidDataException("Journal blocks array");
            var blocks = new List<JournalBlock>(); var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            paths.Add(Path.Combine(directory, "journal-seal.json")); long next = 0;
            foreach (object item in (List<object>)blockValue)
            {
                var row = MetadataJson.Object(item);
                var block = new JournalBlock { Data = Files.Within(directory, MetadataJson.Text(row, "DataFile")),
                    Index = Files.Within(directory, MetadataJson.Text(row, "IndexFile")),
                    DataHash = MetadataJson.Text(row, "DataSHA256"), IndexHash = MetadataJson.Text(row, "IndexSHA256"),
                    First = MetadataJson.Integer(row, "FirstOrigin"), Count = MetadataJson.Integer(row, "Origins"), Length = MetadataJson.Integer(row, "DataLength") };
                Files.HashBytes(block.DataHash); Files.HashBytes(block.IndexHash);
                if (!paths.Add(block.Data) || !paths.Add(block.Index)) throw new InvalidDataException("Journal duplicate path");
                if (block.First != next || block.Count < 1) throw new InvalidDataException("Journal block origin range");
                next = checked(next + block.Count); blocks.Add(block);
            }
            if (next != origins) throw new InvalidDataException("Journal total count");
            foreach (string path in Directory.EnumerateFileSystemEntries(directory))
            {
                FileAttributes attributes = File.GetAttributes(path);
                if ((attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint)) != 0 || !paths.Contains(path))
                    throw new InvalidDataException("Journal untracked file or nonregular entry");
            }
            foreach (string path in paths)
                if (!String.Equals(Path.GetDirectoryName(path), directory, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Journal block must be a direct child");
            return blocks;
        }
        private static void VerifyWhole(FileStream stream, string expected)
        {
            using (var hash = SHA256.Create())
                if (!Files.Same(hash.ComputeHash(stream), Files.HashBytes(expected))) throw new InvalidDataException("Journal file hash mismatch");
            stream.Position = 0;
        }
        private static void VerifySlice(FileStream stream, long length, string expected, SHA256 hash, byte[] buffer)
        {
            if (length > stream.Length - stream.Position) throw new InvalidDataException("Journal slice truncated");
            hash.Initialize(); long remaining = length;
            while (remaining > 0)
            {
                int read = stream.Read(buffer, 0, (int)Math.Min(buffer.Length, remaining));
                if (read == 0) throw new InvalidDataException("Journal slice truncated");
                hash.TransformBlock(buffer, 0, read, buffer, 0); remaining -= read;
            }
            hash.TransformFinalBlock(new byte[0], 0, 0);
            if (!Files.Same(hash.Hash, Files.HashBytes(expected))) throw new InvalidDataException("Journal origin hash mismatch");
        }
        private static Dictionary<string, object> Line(StreamReader reader)
        {
            string line = reader.ReadLine();
            if (line == null) return null;
            if (line.Length == 0) throw new InvalidDataException("Journal empty index line");
            return MetadataJson.Object(MetadataJson.Parse(line));
        }
        public static AuditReport Audit(string rootValue, string directoryValue, int workers, int every, int seconds)
        {
            if (workers < 1 || workers > 16) throw new ArgumentOutOfRangeException("workers");
            var clock = Stopwatch.StartNew(); var report = new AuditReport { Operation = "audit-block-journal", Workers = workers };
            string root = Files.Root(rootValue), directory = Files.Within(root, directoryValue);
            long total; List<JournalBlock> blocks;
            using (var phase = new ProgressPhase(report, "journal-seal", 1, every, seconds))
            { blocks = Load(directory, out total); phase.Tick(); phase.Finish(1); }
            using (var phase = new ProgressPhase(report, "journal-blocks-and-origins", total, every, seconds))
            {
                try
                {
                    Parallel.ForEach(blocks, new ParallelOptions { MaxDegreeOfParallelism = workers }, block =>
                    {
                        var kinds = new Dictionary<string, long>(StringComparer.Ordinal); long count = 0;
                        using (var data = Files.ReadFile(block.Data)) using (var index = Files.ReadFile(block.Index))
                        using (var hash = SHA256.Create())
                        {
                            if (data.Length != block.Length) throw new InvalidDataException("Journal block length");
                            VerifyWhole(data, block.DataHash); VerifyWhole(index, block.IndexHash);
                            using (var reader = new StreamReader(index, Files.Utf8, true, 65536, true))
                            {
                                var buffer = new byte[65536]; Dictionary<string, object> row;
                                while ((row = Line(reader)) != null)
                                {
                                    if (MetadataJson.Integer(row, "Id") != block.First + count) throw new InvalidDataException("Journal origin id order");
                                    MetadataJson.Text(row, "Source"); MetadataJson.Text(row, "Phase"); string kind = MetadataJson.Text(row, "Kind");
                                    if (MetadataJson.Integer(row, "InputOffset") != data.Position) throw new InvalidDataException("Journal input offset");
                                    VerifySlice(data, MetadataJson.Integer(row, "InputLength"), MetadataJson.Text(row, "InputSHA256"), hash, buffer);
                                    if (MetadataJson.Integer(row, "OutputOffset") != data.Position) throw new InvalidDataException("Journal output offset");
                                    VerifySlice(data, MetadataJson.Integer(row, "OutputLength"), MetadataJson.Text(row, "OutputSHA256"), hash, buffer);
                                    if (!kinds.ContainsKey(kind)) kinds.Add(kind, 0); kinds[kind]++; count++; phase.Tick();
                                }
                            }
                            if (count != block.Count || data.Position != block.Length) throw new InvalidDataException("Journal coverage/count");
                        }
                        lock (report)
                        {
                            report.Origins += count;
                            foreach (var pair in kinds) { if (!report.Kinds.ContainsKey(pair.Key)) report.Kinds.Add(pair.Key, 0); report.Kinds[pair.Key] += pair.Value; }
                        }
                    });
                }
                catch (AggregateException failure)
                { Exception first = failure.Flatten().InnerExceptions[0]; throw new InvalidDataException(first.Message, first); }
                if (report.Origins != total) throw new InvalidDataException("Journal origin total"); phase.Finish(total);
            }
            report.Bindings = blocks.Count * 2 + 1; report.ElapsedMilliseconds = clock.ElapsedMilliseconds; return report;
        }
        public static RecoveredOrigin ReadOrigin(string directoryValue, long id)
        {
            string directory = Files.Root(directoryValue); long total; var blocks = Load(directory, out total);
            if (id < 0 || id >= total) throw new ArgumentOutOfRangeException("id");
            foreach (JournalBlock block in blocks)
            {
                if (id < block.First || id >= block.First + block.Count) continue;
                using (var data = Files.ReadFile(block.Data)) using (var index = Files.ReadFile(block.Index))
                {
                    if (data.Length != block.Length) throw new InvalidDataException("Journal block length");
                    VerifyWhole(data, block.DataHash); VerifyWhole(index, block.IndexHash);
                    using (var reader = new StreamReader(index, Files.Utf8, true, 65536, true))
                    {
                        Dictionary<string, object> row;
                        while ((row = Line(reader)) != null)
                        {
                            if (MetadataJson.Integer(row, "Id") != id) continue;
                            long inLength = MetadataJson.Integer(row, "InputLength"), outLength = MetadataJson.Integer(row, "OutputLength");
                            long inOffset = MetadataJson.Integer(row, "InputOffset"), outOffset = MetadataJson.Integer(row, "OutputOffset");
                            if (inLength > Int32.MaxValue || outLength > Int32.MaxValue || inOffset > data.Length || inLength > data.Length - inOffset ||
                                outOffset != inOffset + inLength || outLength > data.Length - outOffset) throw new InvalidDataException("Journal recovery range");
                            var input = new byte[(int)inLength]; var output = new byte[(int)outLength]; data.Position = inOffset;
                            using (var binary = new BinaryReader(data, Files.Utf8, true)) { input = binary.ReadBytes(input.Length); output = binary.ReadBytes(output.Length); }
                            if (input.Length != inLength || output.Length != outLength) throw new InvalidDataException("Journal recovery truncated");
                            using (var hash = SHA256.Create())
                                if (!Files.Same(hash.ComputeHash(input), Files.HashBytes(MetadataJson.Text(row, "InputSHA256"))) ||
                                    !Files.Same(hash.ComputeHash(output), Files.HashBytes(MetadataJson.Text(row, "OutputSHA256")))) throw new InvalidDataException("Journal recovery hash");
                            return new RecoveredOrigin { Id = id, Source = MetadataJson.Text(row, "Source"), Phase = MetadataJson.Text(row, "Phase"),
                                Kind = MetadataJson.Text(row, "Kind"), Input = input, Output = output };
                        }
                    }
                }
            }
            throw new InvalidDataException("Journal recovery missing origin");
        }
        public static JournalSummary PackLegacy(string sourceDirectoryValue, string[] inventories, string destination, long blockBytes, int blockOrigins)
        { return PackLegacy(sourceDirectoryValue, inventories, destination, blockBytes, blockOrigins, 25000, 10); }
        public static JournalSummary PackLegacy(string sourceDirectoryValue, string[] inventories, string destination, long blockBytes, int blockOrigins, int every, int seconds)
        {
            var clock = Stopwatch.StartNew(); var report = new AuditReport { Operation = "pack-legacy-bytes" };
            string sourceDirectory = Files.Root(sourceDirectoryValue);
            if (inventories == null || inventories.Length == 0) throw new InvalidDataException("Pack inventories required");
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            JournalSummary summary;
            using (var phase = new ProgressPhase(report, "pack-legacy-bytes", -1, every, seconds))
            using (var writer = new RawJournalWriter(destination, blockBytes, blockOrigins, 1))
            {
                foreach (string inventory in inventories)
                using (var json = MetadataJson.Open(Files.Within(sourceDirectory, inventory)))
                    json.ArrayObjects(row =>
                    {
                        string inputPath = Files.Within(sourceDirectory, MetadataJson.Text(row, "InputPath"));
                        string outputPath = Files.Within(sourceDirectory, MetadataJson.Text(row, "OutputPath"));
                        string metadataPath = Files.Within(sourceDirectory, MetadataJson.Text(row, "MetadataPath"));
                        if (!seen.Add(inputPath) || !seen.Add(outputPath) || !seen.Add(metadataPath)) throw new InvalidDataException("Pack duplicate origin path");
                        using (var metadata = Files.ReadFile(metadataPath)) { }
                        byte[] input = File.ReadAllBytes(inputPath), output = File.ReadAllBytes(outputPath);
                        using (var hash = SHA256.Create())
                            if (!Files.Same(hash.ComputeHash(input), Files.HashBytes(MetadataJson.Text(row, "InputSHA256"))) ||
                                !Files.Same(hash.ComputeHash(output), Files.HashBytes(MetadataJson.Text(row, "OutputSHA256")))) throw new InvalidDataException("Pack source hash mismatch");
                        writer.Append(MetadataJson.Text(row, "Source"), MetadataJson.Text(row, "Phase"), MetadataJson.Text(row, "Kind"), input, output);
                        phase.Tick();
                    });
                summary = writer.Complete(); phase.Finish(summary.Origins);
            }
            summary.ElapsedMilliseconds = clock.ElapsedMilliseconds; summary.Phases = report.Phases; return summary;
        }
    }
}
