Output test-recording.mp4
Set Width 1200
Set Height 600
Set FontSize 16
Set Theme "Catppuccin Mocha"

Type "echo 'Hello from VHS recording test!'"
Enter
Sleep 1s

Type "echo '测试中文显示和时间戳:' $(date)"
Enter
Sleep 1s

Type "ls -la agent-file-preview/"
Enter
Sleep 2s

Type "echo '录制完成 ✓'"
Enter
Sleep 1s
