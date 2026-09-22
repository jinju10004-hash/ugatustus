# 우가투스투스 미션 — 학생용 웹앱 3종 생성 스크립트
# src\student.html 템플릿에 부품 사진과 벽화를 data URI로 심어
# 말 / 그림 / 문자 미션 웹앱을 각각 독립 실행 파일로 만듭니다.

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets = Join-Path $root 'assets'
$tpl    = Get-Content (Join-Path $root 'src\student.html') -Raw -Encoding UTF8

function DataUri($path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  return 'data:image/jpeg;base64,' + [Convert]::ToBase64String($bytes)
}

# ---- 부품 사진 20장 ----
$cardIds = @('st_ok','st_w1','st_w2','st_w3','st_w4',
             'hd_ok','hd_w1','hd_w2','hd_w3','hd_w4',
             'vn_ok','vn_w1','vn_w2','vn_w3',
             'or_ok','or_w1','or_w2','or_w3','or_w4','or_w5')
$cardParts = @()
foreach ($id in $cardIds) {
  $cardParts += ('{0}:"{1}"' -f $id, (DataUri (Join-Path $assets "cards\$id.jpg")))
}
$cardsJs = $cardParts -join ','

# ---- 동굴 벽화 4장 (그림 미션에만 넣습니다) ----
$muralParts = @()
foreach ($n in 1..4) {
  $muralParts += ('"{0}"' -f (DataUri (Join-Path $assets "mural\mural$n.jpg")))
}
$muralsJs = $muralParts -join ','

$targets = @(
  @{ id = 'speech';  file = '1_말미션_학생용.html'   },
  @{ id = 'picture'; file = '2_그림미션_학생용.html' },
  @{ id = 'text';    file = '3_문자미션_학생용.html' }
)

$enc = New-Object System.Text.UTF8Encoding($false)
foreach ($t in $targets) {
  $html = $tpl.Replace('__MISSION__', $t.id)
  $html = $html.Replace('/*INJECT_CARDS*/', $cardsJs)
  # 벽화는 그림 미션에만 넣어 다른 두 앱의 용량을 줄입니다.
  if ($t.id -eq 'picture') { $html = $html.Replace('/*INJECT_MURALS*/', $muralsJs) }
  else                     { $html = $html.Replace('/*INJECT_MURALS*/', '') }

  $out = Join-Path $root $t.file
  [System.IO.File]::WriteAllText($out, $html, $enc)
  Write-Output ('{0,-28} {1,7} KB' -f $t.file, [int]((Get-Item $out).Length / 1024))
}

$td = Join-Path $root 'teacher-dashboard.html'
if (Test-Path $td) {
  Write-Output ('{0,-28} {1,7} KB' -f '교사용 결과판', [int]((Get-Item $td).Length / 1024))
}
Write-Output ''
Write-Output '완료. 각 파일을 Canva Code에 붙여넣거나 브라우저로 바로 열 수 있습니다.'
