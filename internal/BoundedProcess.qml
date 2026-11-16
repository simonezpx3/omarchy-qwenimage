import Quickshell.Io

Process {
  id: proc
  property int maxOutBytes: 65536
  property string outBuf: ""
  property bool overflowed: false

  signal finished(string stdoutText, int exitCode, bool wasOverflowed)

  onStarted: {
    outBuf = "";
    overflowed = false;
  }

  stdout: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      if (proc.overflowed) return;
      proc.outBuf += chunk;
      if (proc.outBuf.length > proc.maxOutBytes) {
        proc.overflowed = true;
        proc.outBuf = "";
        proc.signal(15);
      }
    }
  }

  onExited: function(code, status) {
    const out = proc.outBuf.trim();
    const ovf = proc.overflowed;
    proc.outBuf = "";
    proc.finished(out, code, ovf);
  }
}
