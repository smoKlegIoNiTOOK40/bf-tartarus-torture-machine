using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace Tartarus.Gui {
    // The job owns this worker and its BF children. Closing it stops only this run.
    public sealed class OwnedWorker : IDisposable {
        [StructLayout(LayoutKind.Sequential)]
        private struct BasicLimits {
            public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass, SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters { public ulong A, B, C, D, E, F; }
        [StructLayout(LayoutKind.Sequential)]
        private struct ExtendedLimits {
            public BasicLimits BasicLimitInformation;
            public IoCounters IoInfo;
            public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimits limits, uint length);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool QueryInformationJobObject(IntPtr job, int infoClass, IntPtr information, uint length, out uint required);
        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        private IntPtr job;
        public Process Process { get; private set; }
        public Task<string> StandardOutput { get; private set; }
        public Task<string> StandardError { get; private set; }

        public OwnedWorker(string executable, string arguments, string directory) {
            job = CreateJobObject(IntPtr.Zero, null);
            if (job == IntPtr.Zero) throw new Win32Exception();
            var limits = new ExtendedLimits();
            limits.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if (!SetInformationJobObject(job, 9, ref limits, (uint)Marshal.SizeOf(limits))) {
                int error = Marshal.GetLastWin32Error(); Dispose(); throw new Win32Exception(error);
            }
            Process = new Process { StartInfo = new ProcessStartInfo {
                FileName = executable, Arguments = arguments, WorkingDirectory = directory,
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true
            }};
            try {
                Process.Start();
                if (!AssignProcessToJobObject(job, Process.Handle)) {
                    int error = Marshal.GetLastWin32Error();
                    Process.Kill(); throw new Win32Exception(error);
                }
                StandardOutput = Process.StandardOutput.ReadToEndAsync();
                StandardError = Process.StandardError.ReadToEndAsync();
            } catch { Dispose(); throw; }
        }
        public void Cancel() {
            if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
        }
        public int[] GetProcessIds() {
            if (job == IntPtr.Zero) return new int[0];
            // Query only our job. No machine-wide process inventory or WMI permission.
            int length = 8 + 1024 * IntPtr.Size;
            IntPtr buffer = Marshal.AllocHGlobal(length);
            try {
                uint required;
                if (!QueryInformationJobObject(job, 3, buffer, (uint)length, out required)) throw new Win32Exception();
                int count = Marshal.ReadInt32(buffer, 4);
                var ids = new int[count];
                for (int i = 0; i < count; i++) ids[i] = checked((int)Marshal.ReadIntPtr(buffer, 8 + i * IntPtr.Size).ToInt64());
                return ids;
            } finally { Marshal.FreeHGlobal(buffer); }
        }
        public void Dispose() {
            Cancel();
            if (Process != null) { Process.Dispose(); Process = null; }
        }
    }
    public static class WindowAppearance {
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
        public static void UseDarkTitleBar(IntPtr window) {
            int enabled = 1;
            DwmSetWindowAttribute(window, 20, ref enabled, sizeof(int));
        }
    }
}
