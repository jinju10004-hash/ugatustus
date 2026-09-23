# 말 미션 음성 파일 만들기
#
# 브라우저에 음성 읽기 기능이 없는 기기(카카오톡·클래스팅 등 앱 안 브라우저,
# 일부 안드로이드 기기)에서도 소리가 나도록, 대본을 미리 음성 파일로 만들어 둡니다.
#
# src\student.html 의 SPEECH_STEPS 를 그대로 읽어오므로,
# 대본을 고치면 이 스크립트를 다시 실행하기만 하면 됩니다.
#
# 사용법:  .\음성만들기.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech

$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$out   = Join-Path $root 'audio'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# --- src\student.html 에서 대본 읽어오기 ---
$enc  = New-Object System.Text.UTF8Encoding($false)
$html = [System.IO.File]::ReadAllText((Join-Path $root 'src\student.html'), $enc)
$m = [regex]::Match($html, 'var SPEECH_STEPS = \[(.*?)\];', 'Singleline')
if (-not $m.Success) { Write-Output 'SPEECH_STEPS 를 찾지 못했습니다.'; exit 1 }
$steps = [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
Write-Output ("대본 " + $steps.Count + "단계를 읽었습니다.")

# --- 음성 설정 ---
$voiceName = 'Microsoft Heami Desktop'   # 한국어 여성 음성
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
  8000,
  [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
  [System.Speech.AudioFormat.AudioChannel]::Mono)

# 음높이를 낮춰 중년 남성에 가까운 목소리로 만듭니다.
# 이 컴퓨터에는 한국어 음성이 여성(Heami) 하나뿐이라 음높이를 내리는 방식입니다.
# 더 굵게 하려면 -50%, 덜 굵게 하려면 -20% 처럼 바꾸세요.
$pitch = '-35%'

function Make-Wav([string]$text, [string]$path) {
  $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
  try { $s.SelectVoice($voiceName) } catch { }
  $s.Rate = 2
  $s.SetOutputToWaveFile($path, $fmt)
  $esc = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
  $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ko-KR'>" +
          "<prosody pitch='$pitch'>$esc</prosody></speak>"
  try { $s.SpeakSsml($ssml) } catch { $s.Speak($text) }
  $s.SetOutputToNull()
  $s.Dispose()
}

# 5단계를 하나로 이어 붙여 끊김 없이 한 번에 들려줍니다.
# 단계 사이에는 숨 돌릴 틈만 짧게 둡니다.
$story = ($steps -join ' ... ')
$total = 0
$path = Join-Path $out 'story.wav'
Make-Wav $story $path
$kb = [int]((Get-Item $path).Length / 1024)
$total += $kb
Write-Output ('  story.wav  {0,5} KB  (전체 이야기 한 파일)' -f $kb)

# 시작 화면 소리 확인용 (제작 방법은 들어 있지 않습니다)
Make-Wav '잘 들리니? 그럼 시작해 보자!' (Join-Path $out 'soundcheck.wav')
$kb = [int]((Get-Item (Join-Path $out 'soundcheck.wav')).Length / 1024)
$total += $kb
Write-Output ('  soundcheck.wav  {0,5} KB' -f $kb)

Write-Output ''
Write-Output ("전체 {0} KB — 학생은 한 단계에 한 파일씩만 받습니다." -f $total)
