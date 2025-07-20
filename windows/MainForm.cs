using System;
using System.Collections.Generic;
using System.Drawing;
using System.Net.Http;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Configuration;

namespace ClipboardReceiver
{
    public partial class MainForm : Form
    {
        [DllImport("User32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SetClipboardViewer(IntPtr hWndNewViewer);

        [DllImport("User32.dll", CharSet = CharSet.Auto)]
        public static extern bool ChangeClipboardChain(IntPtr hWndRemove, IntPtr hWndNewNext);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SendMessage(IntPtr hwnd, int wMsg, IntPtr wParam, IntPtr lParam);

        private const int WM_DRAWCLIPBOARD = 0x308;
        private const int WM_CHANGECBCHAIN = 0x030D;

        private IntPtr nextClipboardViewer;
        private long lastProcessedTimestamp = 0;
        private string lastReceivedContent = "";
        private Button toggleButton;
        private Panel statusPanel;
        private Label statusLabel;
        private Panel contentPanel;
        private PictureBox contentImage;
        private Label contentText;
        private System.Windows.Forms.Timer pollingTimer;
        private NotifyIcon trayIcon;
        
        private bool isPaused = false;
        private string serverUrl = "http://localhost:3000";
        private string apiKey = "your-api-key";
        private HttpClient httpClient;
        
        public MainForm()
        {
            LoadConfig();
            InitializeComponent();
            InitializeHttpClient();
            SetupTrayIcon();
            SetupClipboardMonitoring();
            InitializePolling();
        }
        
        private void LoadConfig()
        {
            try
            {
                // Load from app.config
                serverUrl = ConfigurationManager.AppSettings["ServerUrl"] ?? serverUrl;
                apiKey = ConfigurationManager.AppSettings["ApiKey"] ?? apiKey;
                
                if (string.IsNullOrEmpty(apiKey) || apiKey == "your-api-key-here")
                {
                    MessageBox.Show("API key not configured in app.config", "Configuration Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error loading config: {ex.Message}", "Config Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        
        private void InitializeComponent()
        {
            this.Text = "Clipboard Sync";
            this.Size = new Size(400, 350);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            
            // Status panel with toggle button and indicator
            statusPanel = new Panel
            {
                Height = 70,
                Dock = DockStyle.Top,
                BackColor = Color.LightGray
            };
            
            toggleButton = new Button
            {
                Text = "Pause",
                Size = new Size(80, 30),
                Location = new Point(10, 10),
                BackColor = Color.White
            };
            toggleButton.Click += ToggleButton_Click;
            
            statusLabel = new Label
            {
                Text = "●",
                Font = new Font("Arial", 16, FontStyle.Bold),
                ForeColor = Color.Green,
                Size = new Size(30, 30),
                Location = new Point(100, 10),
                TextAlign = ContentAlignment.MiddleCenter
            };

            var modeLabel = new Label
            {
                Text = "Mode: Send & Receive",
                Font = new Font("Arial", 9, FontStyle.Bold),
                ForeColor = Color.DarkBlue,
                Size = new Size(200, 20),
                Location = new Point(10, 45),
                TextAlign = ContentAlignment.MiddleLeft
            };
            
            statusPanel.Controls.Add(toggleButton);
            statusPanel.Controls.Add(statusLabel);
            statusPanel.Controls.Add(modeLabel);
            
            // Content display area
            contentPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle,
                Padding = new Padding(10)
            };
            
            contentText = new Label
            {
                Dock = DockStyle.Fill,
                Text = "Ready to sync clipboard...\nCopy something to test!",
                TextAlign = ContentAlignment.TopLeft,
                Font = new Font("Arial", 10),
                AutoSize = false,
            };
            
            contentImage = new PictureBox
            {
                Dock = DockStyle.Fill,
                SizeMode = PictureBoxSizeMode.Zoom,
                Visible = false
            };
            
            contentPanel.Controls.Add(contentText);
            contentPanel.Controls.Add(contentImage);
            
            this.Controls.Add(contentPanel);
            this.Controls.Add(statusPanel);
        }
        
        private void InitializeHttpClient()
        {
            httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.Add("x-api-key", apiKey);
        }
        
        private void SetupTrayIcon()
        {
            trayIcon = new NotifyIcon
            {
                Icon = SystemIcons.Information,
                Text = "Clipboard Receiver",
                Visible = true
            };
            
            var contextMenu = new ContextMenuStrip();
            contextMenu.Items.Add("Show", null, (s, e) => { this.Show(); this.WindowState = FormWindowState.Normal; });
            contextMenu.Items.Add("Exit", null, (s, e) => Application.Exit());
            
            trayIcon.ContextMenuStrip = contextMenu;
            trayIcon.DoubleClick += (s, e) => { this.Show(); this.WindowState = FormWindowState.Normal; };
        }
        
        private void SetupClipboardMonitoring()
        {
            nextClipboardViewer = SetClipboardViewer(this.Handle);
        }
        
        private void InitializePolling()
        {
            pollingTimer = new System.Windows.Forms.Timer
            {
                Interval = 2000 // Poll every 2 seconds
            };
            pollingTimer.Tick += async (s, e) => await PollClipboard();
            pollingTimer.Start();
        }
        
        private void ToggleButton_Click(object sender, EventArgs e)
        {
            isPaused = !isPaused;
            
            if (isPaused)
            {
                toggleButton.Text = "Unpause";
                statusLabel.ForeColor = Color.Red;
                pollingTimer.Stop();
            }
            else
            {
                toggleButton.Text = "Pause";
                statusLabel.ForeColor = Color.Green;
                pollingTimer.Start();
            }
        }
        
        private async Task PollClipboard()
        {
            try
            {
                var response = await httpClient.GetAsync($"{serverUrl}/clipboard");
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    var clipboardData = JsonConvert.DeserializeObject<ClipboardData>(json);
                    
                    if (clipboardData?.Formats != null && clipboardData.Timestamp > lastProcessedTimestamp)
                    {
                        // Only process if this is newer data and not from our own app
                        if (clipboardData.Source != "windows")
                        {
                            await SetLocalClipboard(clipboardData.Formats);
                            lastProcessedTimestamp = clipboardData.Timestamp;
                        }
                        DisplayClipboardContent(clipboardData.Formats);
                    }
                }
            }
            catch (Exception ex)
            {
                contentText.Text = $"Polling error: {ex.Message}";
                contentText.Visible = true;
                contentImage.Visible = false;
            }
        }

        private async Task SetLocalClipboard(dynamic formats)
        {
            await Task.Run(() =>
            {
                this.Invoke((MethodInvoker)delegate
                {
                    try
                    {
                        var formatsDict = formats as Newtonsoft.Json.Linq.JObject;
                        if (formatsDict == null) 
                        {
                            return;
                        }

                        // Priority: text, then image, then files
                        if (formatsDict["text"] != null)
                        {
                            var text = formatsDict["text"].ToString();
                            lastReceivedContent = text; // Track what we're setting
                            Clipboard.SetText(text);
                            contentText.Text = $"📥 Set clipboard text: {text.Substring(0, Math.Min(50, text.Length))}...";
                        }
                        else if (formatsDict["image"] != null)
                        {
                            try
                            {
                                var base64Data = formatsDict["image"].ToString();
                                if (base64Data.StartsWith("data:image"))
                                {
                                    var base64 = base64Data.Substring(base64Data.IndexOf(',') + 1);
                                    var imageBytes = Convert.FromBase64String(base64);
                                    using (var ms = new MemoryStream(imageBytes))
                                    {
                                        var image = Image.FromStream(ms);
                                        Clipboard.SetImage(image);
                                        contentText.Text = "📥 Set clipboard image";
                                    }
                                }
                            }
                            catch (Exception ex)
                            {
                                contentText.Text = $"Error setting image: {ex.Message}";
                            }
                        }
                        else if (formatsDict["files"] != null)
                        {
                            try
                            {
                                var filesArray = formatsDict["files"] as Newtonsoft.Json.Linq.JArray;
                                if (filesArray != null)
                                {
                                    var tempDir = Path.Combine(Path.GetTempPath(), "ClipboardSync");
                                    Directory.CreateDirectory(tempDir);
                                    
                                    var fileList = new System.Collections.Specialized.StringCollection();
                                    var decodedFiles = new List<string>();
                                    
                                    foreach (var fileObj in filesArray)
                                    {
                                        try
                                        {
                                            var fileName = fileObj["name"]?.ToString();
                                            var content = fileObj["content"]?.ToString();
                                            var isDirectory = fileObj["isDirectory"]?.ToObject<bool>() ?? false;
                                            
                                            if (string.IsNullOrEmpty(fileName)) continue;
                                            
                                            var tempFilePath = Path.Combine(tempDir, fileName);
                                            
                                            if (isDirectory)
                                            {
                                                // Create directory
                                                Directory.CreateDirectory(tempFilePath);
                                                fileList.Add(tempFilePath);
                                                decodedFiles.Add(fileName + " (folder)");
                                            }
                                            else if (!string.IsNullOrEmpty(content))
                                            {
                                                // Decode and save file
                                                var fileBytes = Convert.FromBase64String(content);
                                                File.WriteAllBytes(tempFilePath, fileBytes);
                                                fileList.Add(tempFilePath);
                                                decodedFiles.Add(fileName);
                                            }
                                        }
                                        catch (Exception ex)
                                        {
                                            contentText.Text = $"Error decoding file: {ex.Message}";
                                            continue;
                                        }
                                    }
                                    
                                    if (fileList.Count > 0)
                                    {
                                        Clipboard.SetFileDropList(fileList);
                                        contentText.Text = $"📥 Set clipboard files: {string.Join(", ", decodedFiles)}";
                                    }
                                    else
                                    {
                                        contentText.Text = "No valid files to decode";
                                    }
                                }
                            }
                            catch (Exception ex)
                            {
                                contentText.Text = $"Error setting files: {ex.Message}";
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        contentText.Text = $"Error setting clipboard: {ex.Message}";
                    }
                });
            });
        }
        
        private void DisplayClipboardContent(dynamic formats)
        {
            try
            {
                var formatsDict = formats as Newtonsoft.Json.Linq.JObject;
                if (formatsDict == null) return;
                
                if (formatsDict["text"] != null)
                {
                    contentText.Text = formatsDict["text"].ToString();
                    contentText.Visible = true;
                    contentImage.Visible = false;
                }
                else if (formatsDict["image"] != null)
                {
                    try
                    {
                        var base64Data = formatsDict["image"].ToString();
                        if (base64Data.StartsWith("data:image"))
                        {
                            var base64 = base64Data.Substring(base64Data.IndexOf(',') + 1);
                            var imageBytes = Convert.FromBase64String(base64);
                            using (var ms = new MemoryStream(imageBytes))
                            {
                                contentImage.Image = Image.FromStream(ms);
                                contentImage.Visible = true;
                                contentText.Visible = false;
                            }
                        }
                    }
                    catch
                    {
                        contentText.Text = "Error displaying image";
                        contentText.Visible = true;
                        contentImage.Visible = false;
                    }
                }
                else
                {
                    var formatNames = string.Join(", ", formatsDict.Properties().Select(p => p.Name));
                    contentText.Text = $"File formats: {formatNames}";
                    contentText.Visible = true;
                    contentImage.Visible = false;
                }
            }
            catch (Exception ex)
            {
                contentText.Text = $"Error parsing content: {ex.Message}";
                contentText.Visible = true;
                contentImage.Visible = false;
            }
        }
        
        protected override void SetVisibleCore(bool value)
        {
            base.SetVisibleCore(value);
            if (value && WindowState == FormWindowState.Minimized)
            {
                Hide();
            }
        }
        
        protected override void WndProc(ref Message m)
        {
            switch (m.Msg)
            {
                case WM_DRAWCLIPBOARD:
                    this.Invoke((MethodInvoker)delegate
                    {
                        contentText.Text = "Clipboard changed detected...";
                        contentText.Visible = true;
                        contentImage.Visible = false;
                    });
                    
                    if (!isPaused)
                    {
                        _ = Task.Run(async () => await OnClipboardChanged());
                    }
                    else
                    {
                        this.Invoke((MethodInvoker)delegate
                        {
                            contentText.Text = "Clipboard changed but paused";
                        });
                    }
                    SendMessage(nextClipboardViewer, m.Msg, m.WParam, m.LParam);
                    break;

                case WM_CHANGECBCHAIN:
                    if (m.WParam == nextClipboardViewer)
                        nextClipboardViewer = m.LParam;
                    else
                        SendMessage(nextClipboardViewer, m.Msg, m.WParam, m.LParam);
                    break;

                default:
                    base.WndProc(ref m);
                    break;
            }
        }

        private async Task OnClipboardChanged()
        {
            try
            {
                this.Invoke((MethodInvoker)delegate
                {
                    contentText.Text = "Capturing clipboard data...";
                });

                // Small delay to ensure clipboard is ready
                await Task.Delay(100);

                var clipboardData = await CaptureClipboardData();
                
                if (clipboardData != null)
                {
                    this.Invoke((MethodInvoker)delegate
                    {
                        contentText.Text = "Sending to server...";
                    });
                    
                    await SendClipboardToServer(clipboardData);
                }
                else
                {
                    this.Invoke((MethodInvoker)delegate
                    {
                        contentText.Text = "No valid clipboard data found";
                    });
                }
            }
            catch (Exception ex)
            {
                this.Invoke((MethodInvoker)delegate
                {
                    contentText.Text = $"Error in OnClipboardChanged: {ex.Message}";
                    contentText.Visible = true;
                    contentImage.Visible = false;
                });
            }
        }

        private async Task<object> CaptureClipboardData()
        {
            var tcs = new TaskCompletionSource<object>();
            
            this.Invoke((MethodInvoker)delegate
            {
                try
                {
                    contentText.Text = "Checking clipboard formats...";
                    
                    var formats = new Dictionary<string, object>();

                    if (Clipboard.ContainsText())
                    {
                        var text = Clipboard.GetText();
                        
                        // Don't send if this is the same content we just received from server
                        if (text == lastReceivedContent)
                        {
                            contentText.Text = "Skipping - same as received content";
                            tcs.SetResult(null);
                            return;
                        }
                        
                        formats["text"] = text;
                        contentText.Text = $"Found text: {text.Substring(0, Math.Min(50, text.Length))}...";
                    }

                    if (Clipboard.ContainsImage())
                    {
                        using (var image = Clipboard.GetImage())
                        {
                            using (var ms = new MemoryStream())
                            {
                                image.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                                var base64 = Convert.ToBase64String(ms.ToArray());
                                formats["image"] = $"data:image/png;base64,{base64}";
                            }
                        }
                        contentText.Text = "Found image data";
                    }

                    if (Clipboard.ContainsFileDropList())
                    {
                        var files = Clipboard.GetFileDropList();
                        var fileData = new List<object>();
                        
                        foreach (string filePath in files)
                        {
                            try
                            {
                                if (File.Exists(filePath))
                                {
                                    var fileInfo = new FileInfo(filePath);
                                    // Limit file size to 50MB to stay under server's 100MB limit
                                    if (fileInfo.Length <= 50 * 1024 * 1024)
                                    {
                                        var fileBytes = File.ReadAllBytes(filePath);
                                        var base64Content = Convert.ToBase64String(fileBytes);
                                        
                                        fileData.Add(new
                                        {
                                            name = Path.GetFileName(filePath),
                                            content = base64Content,
                                            size = fileInfo.Length,
                                            type = GetMimeType(filePath)
                                        });
                                    }
                                    else
                                    {
                                        contentText.Text = $"File too large: {fileInfo.Name} ({fileInfo.Length / (1024 * 1024)}MB)";
                                        tcs.SetResult(null);
                                        return;
                                    }
                                }
                                else if (Directory.Exists(filePath))
                                {
                                    // For directories, just send the name and indicate it's a directory
                                    fileData.Add(new
                                    {
                                        name = Path.GetFileName(filePath),
                                        content = "", // Empty content for directories
                                        size = 0,
                                        type = "directory",
                                        isDirectory = true
                                    });
                                }
                            }
                            catch (Exception ex)
                            {
                                contentText.Text = $"Error reading file {Path.GetFileName(filePath)}: {ex.Message}";
                                continue;
                            }
                        }
                        
                        if (fileData.Count > 0)
                        {
                            formats["files"] = fileData;
                            contentText.Text = $"Found {fileData.Count} files/folders";
                        }
                        else
                        {
                            contentText.Text = "No valid files found";
                            tcs.SetResult(null);
                            return;
                        }
                    }

                    if (formats.Count > 0)
                    {
                        var result = new
                        {
                            formats = formats,
                            source = "windows"
                        };
                        tcs.SetResult(result);
                    }
                    else
                    {
                        contentText.Text = "No supported clipboard formats found";
                        tcs.SetResult(null);
                    }
                }
                catch (Exception ex)
                {
                    contentText.Text = $"Clipboard capture error: {ex.Message}";
                    tcs.SetException(ex);
                }
            });
            
            return await tcs.Task;
        }

        private string GetMimeType(string filePath)
        {
            var extension = Path.GetExtension(filePath).ToLowerInvariant();
            return extension switch
            {
                ".txt" => "text/plain",
                ".pdf" => "application/pdf",
                ".doc" => "application/msword",
                ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                ".xls" => "application/vnd.ms-excel",
                ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                ".ppt" => "application/vnd.ms-powerpoint",
                ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".gif" => "image/gif",
                ".bmp" => "image/bmp",
                ".svg" => "image/svg+xml",
                ".mp4" => "video/mp4",
                ".avi" => "video/x-msvideo",
                ".mov" => "video/quicktime",
                ".mp3" => "audio/mpeg",
                ".wav" => "audio/wav",
                ".zip" => "application/zip",
                ".rar" => "application/vnd.rar",
                ".7z" => "application/x-7z-compressed",
                ".exe" => "application/vnd.microsoft.portable-executable",
                ".msi" => "application/x-msi",
                ".json" => "application/json",
                ".xml" => "application/xml",
                ".html" => "text/html",
                ".css" => "text/css",
                ".js" => "application/javascript",
                ".py" => "text/x-python",
                ".java" => "text/x-java-source",
                ".cpp" or ".cc" or ".cxx" => "text/x-c++src",
                ".c" => "text/x-csrc",
                ".cs" => "text/x-csharp",
                ".php" => "text/x-php",
                ".rb" => "text/x-ruby",
                ".go" => "text/x-go",
                ".rs" => "text/x-rust",
                _ => "application/octet-stream"
            };
        }

        private async Task SendClipboardToServer(object clipboardData)
        {
            try
            {
                this.Invoke((MethodInvoker)delegate
                {
                    contentText.Text = "Serializing data...";
                });

                var json = JsonConvert.SerializeObject(clipboardData);
                
                this.Invoke((MethodInvoker)delegate
                {
                    contentText.Text = $"Sending to {serverUrl}/clipboard...";
                });

                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await httpClient.PostAsync($"{serverUrl}/clipboard", content);
                
                if (response.IsSuccessStatusCode)
                {
                    this.Invoke((MethodInvoker)delegate
                    {
                        contentText.Text = "✓ Clipboard sent successfully";
                        contentText.Visible = true;
                        contentImage.Visible = false;
                        lastReceivedContent = ""; // Clear so we can receive this content back from other devices
                    });
                }
                else
                {
                    var errorText = await response.Content.ReadAsStringAsync();
                    this.Invoke((MethodInvoker)delegate
                    {
                        contentText.Text = $"✗ Server error: {response.StatusCode}\n{errorText}";
                        contentText.Visible = true;
                        contentImage.Visible = false;
                    });
                }
            }
            catch (Exception ex)
            {
                this.Invoke((MethodInvoker)delegate
                {
                    contentText.Text = $"✗ Network error: {ex.Message}\nServer: {serverUrl}\nAPI Key: {apiKey?.Substring(0, 8)}...";
                    contentText.Visible = true;
                    contentImage.Visible = false;
                });
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
            }
            else
            {
                ChangeClipboardChain(this.Handle, nextClipboardViewer);
                trayIcon?.Dispose();
                httpClient?.Dispose();
                base.OnFormClosing(e);
            }
        }
    }
    
    public class ClipboardData
    {
        public dynamic? Formats { get; set; }
        public long Timestamp { get; set; }
        public string? Source { get; set; }
    }
    
    public class Config
    {
        public string? ServerUrl { get; set; }
        public string? ApiKey { get; set; }
        public int PollingIntervalMs { get; set; } = 2000;
    }
}