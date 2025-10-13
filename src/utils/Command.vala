/*
 * SSHer - Subprocess Command Utilities
 *
 * Shared helpers to execute commands and capture output consistently.
 */

namespace KeyMaker {
    public class Command {
        public class Result : Object {
            public int status { get; construct; }
            public string stdout { get; construct; }
            public string stderr { get; construct; }

            public Result (int status, string stdout, string stderr) {
                Object (status: status, stdout: stdout, stderr: stderr);
            }
        }

        public static async Result run_capture (string[] argv, Cancellable? cancellable = null) throws KeyMakerError {
            try {
                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                yield subprocess.wait_async (cancellable);

                int status = subprocess.get_exit_status ();

                var out_stream = subprocess.get_stdout_pipe ();
                var err_stream = subprocess.get_stderr_pipe ();

                var out_reader = new DataInputStream (out_stream);
                var err_reader = new DataInputStream (err_stream);

                var out_buf = new StringBuilder ();
                var err_buf = new StringBuilder ();

                // Read all stdout lines (best-effort)
                while (true) {
                    string? line;
                    try {
                        line = cancellable != null ? (yield out_reader.read_line_async (GLib.Priority.DEFAULT, cancellable)) : out_reader.read_line ();
                    } catch (Error e) {
                        break;
                    }
                    if (line == null) break;
                    out_buf.append (line);
                    out_buf.append ("\n");
                }

                // Read all stderr lines (best-effort)
                while (true) {
                    string? line;
                    try {
                        line = cancellable != null ? (yield err_reader.read_line_async (GLib.Priority.DEFAULT, cancellable)) : err_reader.read_line ();
                    } catch (Error e) {
                        break;
                    }
                    if (line == null) break;
                    err_buf.append (line);
                    err_buf.append ("\n");
                }

                return new Result (status, out_buf.str, err_buf.str);
            } catch (IOError.CANCELLED e) {
                // Handle cancellation gracefully - don't re-throw as unhandled error
                throw new KeyMakerError.OPERATION_CANCELLED ("Command was cancelled");
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to run command: %s", e.message);
            }
        }
        
        /**
         * Execute a command with a timeout
         */
        public static async Result run_capture_with_timeout (string[] command, int timeout_ms, Cancellable? cancellable = null) throws KeyMakerError {
            try {
                KeyMaker.Log.debug("COMMAND", "Executing command with timeout: %s", string.joinv(" ", command));
                
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (command);
                
                // Set up timeout
                var timeout_reached = false;
                var timeout_source = Timeout.add (timeout_ms, () => {
                    timeout_reached = true;
                    subprocess.force_exit ();
                    return false;
                });
                
                try {
                    yield subprocess.wait_async (cancellable);
                } finally {
                    Source.remove (timeout_source);
                }
                
                if (timeout_reached) {
                    throw new KeyMakerError.OPERATION_FAILED ("Command timed out after %d ms", timeout_ms);
                }
                
                var status = subprocess.get_exit_status ();
                
                // Read stdout
                var out_stream = subprocess.get_stdout_pipe ();
                var out_buf = new StringBuilder ();
                if (out_stream != null) {
                    var data_stream = new DataInputStream (out_stream);
                    string? line;
                    while ((line = data_stream.read_line ()) != null) {
                        out_buf.append (line).append ("\n");
                    }
                }
                
                // Read stderr
                var err_stream = subprocess.get_stderr_pipe ();
                var err_buf = new StringBuilder ();
                if (err_stream != null) {
                    var data_stream = new DataInputStream (err_stream);
                    string? line;
                    while ((line = data_stream.read_line ()) != null) {
                        err_buf.append (line).append ("\n");
                    }
                }
                
                return new Result (status, out_buf.str, err_buf.str);
            } catch (IOError.CANCELLED e) {
                // Handle cancellation gracefully - don't re-throw as unhandled error
                throw new KeyMakerError.OPERATION_CANCELLED ("Command was cancelled");
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to run command: %s", e.message);
            }
        }
    }
}
