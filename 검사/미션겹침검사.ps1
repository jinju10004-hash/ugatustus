# ============================================================
#  한 미션을 끝낸 학생이 다른 미션을 해도 무리가 없는지 확인합니다.
#
#  빨리 끝낸 학생에게 다른 팀 미션을 더 시키는 경우를 가정합니다.
#  확인하는 것:
#   1. 앞 미션에서 고른 정답 카드가 다음 미션 보기에도 들어 있는가
#      (들어 있으면, 자료를 안 보고 그대로 고를 때 0점을 맞습니다)
#   2. 그렇게 "앞 미션 답 그대로" 냈을 때 몇 점이 되는가
#   3. 앞 미션 경험이 다음 미션에서 유리하게 작용하는가 (공정성)
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src  = [System.IO.File]::ReadAllText((Join-Path $root 'src\student.html'), [System.Text.Encoding]::UTF8)

$POOL = @{}
$poolBlock = [regex]::Match($src, 'var CARD_POOL = \[(.*?)\n\];', 'Singleline').Groups[1].Value
foreach ($m in [regex]::Matches($poolBlock, '\{\s*id:"(\w+)",\s*cat:"(\w+)",\s*label:"([^"]*)",\s*attr:\{([^}]*)\}')) {
  $attr = @{}
  foreach ($a in [regex]::Matches($m.Groups[4].Value, '(\w+)\s*:\s*"([^"]*)"')) { $attr[$a.Groups[1].Value] = $a.Groups[2].Value }
  $POOL[$m.Groups[1].Value] = [pscustomobject]@{ id=$m.Groups[1].Value; cat=$m.Groups[2].Value; label=$m.Groups[3].Value; attr=$attr }
}

$SETS = @{}
$setBlock = [regex]::Match($src, 'var MISSION_CARDS = \{(.*?)\n\};', 'Singleline').Groups[1].Value
foreach ($mm in [regex]::Matches($setBlock, '(speech|picture|text)\s*:\s*\{(.*?)\}', 'Singleline')) {
  $byCat = @{}
  foreach ($cm in [regex]::Matches($mm.Groups[2].Value, '(st|hd|vn|or)\s*:\s*\[([^\]]*)\]')) {
    $ids = @(); foreach ($im in [regex]::Matches($cm.Groups[2].Value, '"(\w+)"')) { $ids += $im.Groups[1].Value }
    $byCat[$cm.Groups[1].Value] = $ids
  }
  $SETS[$mm.Groups[1].Value] = $byCat
}

$NAME = @{ speech='🗣️ 말'; picture='🎨 그림'; text='📖 문자' }
$CATNAME  = @{ st='망치 머리'; hd='손잡이'; vn='넝쿨'; or='장신구' }
$MIDS = @('speech','picture','text')
$fail = 0; $warn = 0
function Ok($m){ Write-Host ("   [통과] "+$m) -ForegroundColor Green }
function Bad($m){ $script:fail++; Write-Host ("   [실패] "+$m) -ForegroundColor Red }
function Warn($m){ $script:warn++; Write-Host ("   [주의] "+$m) -ForegroundColor Yellow }

Write-Host ''
Write-Host '■ 앞 미션 답을 그대로 냈을 때 몇 점이 되는가' -ForegroundColor Cyan
Write-Host '  (채점: 정답 1개 +25점, 오답 1개 -5점, 최저 0점)'
Write-Host ''

foreach ($from in $MIDS) {
  foreach ($to in $MIDS) {
    if ($from -eq $to) { continue }
    $right = 0; $wrong = 0; $notShown = 0; $detail = @()
    foreach ($cat in @('st','hd','vn','or')) {
      $prev   = $SETS[$from][$cat][0]      # 앞 미션에서 맞혔던 카드
      $nowAns = $SETS[$to][$cat][0]        # 이번 미션의 정답
      $shown  = $SETS[$to][$cat] -contains $prev
      if (-not $shown) {
        $notShown++
        $detail += ($CATNAME[$cat] + ': 그 카드가 보기에 없음 → 다시 고를 수밖에 없음')
      } elseif ($prev -eq $nowAns) {
        $right++
        $detail += ($CATNAME[$cat] + ': 앞 미션 답이 이번에도 정답 (겹침!)')
      } else {
        $wrong++
        $detail += ($CATNAME[$cat] + ': 보기에 있으나 오답 → 그대로 고르면 -5점')
      }
    }
    $score = [math]::Max(0, $right * 25 - $wrong * 5)
    Write-Host ("  {0} 성공 → {1} 미션" -f $NAME[$from], $NAME[$to])
    foreach ($d in $detail) { Write-Host ('      · ' + $d) }
    Write-Host ("      그대로 제출하면  {0}점 (정답 {1} / 오답 {2} / 보기에 없음 {3})" -f $score, $right, $wrong, $notShown)
    if ($right -gt 0) { Bad ('앞 미션 답이 그대로 정답이 되는 칸이 ' + $right + '개 있습니다. 베끼기가 통합니다.') }
    else { Ok '앞 미션 답을 그대로 내면 한 칸도 맞지 않습니다.' }
    Write-Host ''
  }
}

Write-Host '■ 다음 미션에서 "앞에 본 카드"가 얼마나 다시 나오는가' -ForegroundColor Cyan
Write-Host '  (많이 겹쳐도 정답이 다르므로 유리하지 않지만, 참고용입니다)'
foreach ($from in $MIDS) {
  foreach ($to in $MIDS) {
    if ($from -ge $to) { continue }
    $same = 0; $total = 0
    foreach ($cat in @('st','hd','vn','or')) {
      foreach ($id in $SETS[$to][$cat]) { $total++; if ($SETS[$from][$cat] -contains $id) { $same++ } }
    }
    Write-Host ("  {0} ↔ {1}   보기 16장 가운데 {2}장 겹침" -f $NAME[$from], $NAME[$to], $same)
  }
}

Write-Host ''
Write-Host '■ 어느 미션을 먼저 해도 다음 미션이 풀리는가' -ForegroundColor Cyan
#   앞 미션을 했다고 해서 다음 미션의 조건이 달라지지는 않습니다.
#   각 미션은 자기 자료만으로 답이 정해지므로, 순서와 무관하게 풀립니다.
#   여기서는 "앞 미션 답이 다음 미션 보기에 남아 함정이 되는 수"를 셉니다.
foreach ($to in $MIDS) {
  $traps = 0
  foreach ($from in $MIDS) {
    if ($from -eq $to) { continue }
    foreach ($cat in @('st','hd','vn','or')) {
      $prev = $SETS[$from][$cat][0]
      if (($SETS[$to][$cat] -contains $prev) -and $prev -ne $SETS[$to][$cat][0]) { $traps++ }
    }
  }
  Write-Host ("  {0} 미션 — 다른 팀 정답이 오답 보기로 들어 있는 칸 {1}개 / 8개" -f $NAME[$to], $traps)
}

Write-Host ''
Write-Host ('=' * 56)
if ($fail -eq 0) {
  Write-Host ("  통과. 다른 미션을 해도 앞 미션 답으로는 점수를 얻을 수 없습니다." + $(if($warn){"  (주의 $warn 건)"}else{""})) -ForegroundColor Green
} else {
  Write-Host ("  실패 " + $fail + "건.") -ForegroundColor Red
}
Write-Host ('=' * 56)
exit $(if ($fail -eq 0) { 0 } else { 1 })
