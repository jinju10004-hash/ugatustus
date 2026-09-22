# Apps Script 주소를 웹앱에 넣고 전부 다시 만드는 스크립트
#
# 사용법 (PowerShell에서):
#   .\주소넣기.ps1 "https://script.google.com/macros/s/AKfy...../exec"
#
# 하는 일
#   1) src\student.html 의 SHEET_ENDPOINT 에 주소를 넣습니다
#   2) build.ps1 을 돌려 학생용 3종을 다시 만듭니다
#   3) 영문 이름 파일(mal/geurim/munja/teacher)도 갱신합니다
#   4) 제대로 들어갔는지 확인해서 보여 줍니다
#
# 그다음 GitHub Desktop 에서 Commit → Push 만 하시면 됩니다.

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$주소
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- 주소가 올바른 모양인지 확인 ---
$주소 = $주소.Trim().Trim('"').Trim("'")
if ($주소 -notmatch '^https://script\.google\.com/macros/s/[^/]+/exec$') {
  Write-Output ''
  Write-Output '주소 모양이 맞지 않습니다.'
  Write-Output '  이렇게 생겨야 합니다:'
  Write-Output '  https://script.google.com/macros/s/AKfycb..................../exec'
  Write-Output ''
  Write-Output ('  받은 값: ' + $주소)
  Write-Output ''
  Write-Output '  확인할 것: 끝이 /exec 인지 (/dev 가 아니라), 주소 전체를 복사했는지'
  exit 1
}

# --- 1) 원본에 주소 넣기 ---
$tplPath = Join-Path $root 'src\student.html'
$enc = New-Object System.Text.UTF8Encoding($false)
$tpl = [System.IO.File]::ReadAllText($tplPath, $enc)

if ($tpl -notmatch 'SHEET_ENDPOINT:\s*"[^"]*"') {
  Write-Output 'src\student.html 에서 SHEET_ENDPOINT 를 찾지 못했습니다.'
  exit 1
}
$tpl = [regex]::Replace($tpl, 'SHEET_ENDPOINT:\s*"[^"]*"', ('SHEET_ENDPOINT: "' + $주소 + '"'), 1)
[System.IO.File]::WriteAllText($tplPath, $tpl, $enc)
Write-Output '1) src\student.html 에 주소를 넣었습니다.'

# --- 2) 학생용 3종 다시 만들기 ---
Write-Output '2) 학생용 3종을 다시 만듭니다...'
& (Join-Path $root 'build.ps1') | ForEach-Object { Write-Output ('   ' + $_) }

# --- 3) 영문 이름 파일 갱신 ---
$쌍 = @{
  '1_말미션_학생용.html'   = 'mal.html'
  '2_그림미션_학생용.html' = 'geurim.html'
  '3_문자미션_학생용.html' = 'munja.html'
  'teacher-dashboard.html' = 'teacher.html'
}
foreach ($k in $쌍.Keys) {
  Copy-Item (Join-Path $root $k) (Join-Path $root $쌍[$k]) -Force
}
Write-Output '3) 영문 이름 파일도 갱신했습니다.'

# --- 4) 확인 ---
Write-Output ''
Write-Output '4) 확인'
$모두정상 = $true
foreach ($f in @('mal.html', 'geurim.html', 'munja.html')) {
  $t = [System.IO.File]::ReadAllText((Join-Path $root $f), $enc)
  $m = [regex]::Match($t, 'SHEET_ENDPOINT:\s*"([^"]*)"')
  $v = $m.Groups[1].Value
  if ($v -eq $주소) {
    Write-Output ('   OK   ' + $f)
  } else {
    Write-Output ('   실패 ' + $f + '  (들어간 값: "' + $v + '")')
    $모두정상 = $false
  }
}

Write-Output ''
if ($모두정상) {
  Write-Output '전부 들어갔습니다.'
  Write-Output ''
  Write-Output '다음 할 일'
  Write-Output '  - GitHub Desktop 에서 Commit 하고 Push origin'
  Write-Output '  - 학생용 링크를 열어 맨 위 노란 띠가 사라졌는지 확인'
} else {
  Write-Output '일부가 들어가지 않았습니다. 위 내용을 알려 주세요.'
  exit 1
}
