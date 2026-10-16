# ============================================================
#  우가투스투스 미션 — 정답 검증
#
#  src\student.html 에서 카드 속성 · 미션별 카드 세트 · 말 대본 · 일기를
#  직접 읽어 와서, 아래를 하나하나 확인합니다.
#
#   1. 세 미션의 정답이 모두 다른가
#   2. 각 미션의 자료에 적힌 조건으로 걸렀을 때, 남는 카드가 "정확히 한 장"인가
#      (= 학생이 자료만 보고 정답을 틀림없이 도출할 수 있는가)
#   3. 그 한 장이 코드가 정답으로 정해 둔 카드와 같은가
#   4. 자료 본문에 그 조건이 실제로 적혀 있는가 (코드와 글이 따로 놀지 않는가)
#   5. 난이도가 같은가 (정답과 한 가지만 다른 "함정 카드" 수가 세 미션 모두 같은가)
#   6. 말 대본에서 핵심 낱말이 딱 한 번씩만 나오는가
#
#  실행:  powershell -File 검사\정답검증.ps1
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src  = [System.IO.File]::ReadAllText((Join-Path $root 'src\student.html'), [System.Text.Encoding]::UTF8)

$fail = 0
$warn = 0
function Ok   ($m) { Write-Host ("   [통과] " + $m) -ForegroundColor Green }
function Bad  ($m) { $script:fail++; Write-Host ("   [실패] " + $m) -ForegroundColor Red }
function Warn ($m) { $script:warn++; Write-Host ("   [주의] " + $m) -ForegroundColor Yellow }
function Head ($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }

# ------------------------------------------------------------
# 1) student.html 에서 자료 읽어오기
# ------------------------------------------------------------
# --- 카드와 그 성질 ---
$POOL = @{}
$poolBlock = [regex]::Match($src, 'var CARD_POOL = \[(.*?)\n\];', 'Singleline').Groups[1].Value
if (-not $poolBlock) { throw 'CARD_POOL 을 찾지 못했습니다.' }
foreach ($m in [regex]::Matches($poolBlock, '\{\s*id:"(\w+)",\s*cat:"(\w+)",\s*label:"([^"]*)",\s*attr:\{([^}]*)\}')) {
  $attr = @{}
  foreach ($a in [regex]::Matches($m.Groups[4].Value, '(\w+)\s*:\s*"([^"]*)"')) {
    $attr[$a.Groups[1].Value] = $a.Groups[2].Value
  }
  $POOL[$m.Groups[1].Value] = [pscustomobject]@{
    id = $m.Groups[1].Value; cat = $m.Groups[2].Value; label = $m.Groups[3].Value; attr = $attr
  }
}

# --- 미션별 카드 세트 (맨 앞이 정답) ---
$SETS = @{}
$setBlock = [regex]::Match($src, 'var MISSION_CARDS = \{(.*?)\n\};', 'Singleline').Groups[1].Value
foreach ($mm in [regex]::Matches($setBlock, '(speech|picture|text)\s*:\s*\{(.*?)\}', 'Singleline')) {
  $byCat = @{}
  foreach ($cm in [regex]::Matches($mm.Groups[2].Value, '(st|hd|vn|or)\s*:\s*\[([^\]]*)\]')) {
    $ids = @()
    foreach ($im in [regex]::Matches($cm.Groups[2].Value, '"(\w+)"')) { $ids += $im.Groups[1].Value }
    $byCat[$cm.Groups[1].Value] = $ids
  }
  $SETS[$mm.Groups[1].Value] = $byCat
}

# --- 화면 배치 순서 ---
$ORDER = @{}
$ordLine = [regex]::Match($src, 'var CARD_ORDER = \{([^}]*)\}').Groups[1].Value
foreach ($om in [regex]::Matches($ordLine, '(st|hd|vn|or)\s*:\s*\[([^\]]*)\]')) {
  $ORDER[$om.Groups[1].Value] = @($om.Groups[2].Value -split ',' | ForEach-Object { [int]$_.Trim() })
}

# --- 미션 자료 본문 ---
$speechBlock = [regex]::Match($src, 'var SPEECH_STEPS = \[(.*?)\n\];', 'Singleline').Groups[1].Value
$SPEECH = (([regex]::Matches($speechBlock, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value }) -join ' ')

$diaryBlock = [regex]::Match($src, 'var DIARY = \[(.*?)\n\];', 'Singleline').Groups[1].Value
$DIARY = (([regex]::Matches($diaryBlock, 't:"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value }) -join ' ')

Write-Host ("읽어온 카드 {0}장 · 미션 {1}개 · 말 대본 {2}자 · 일기 {3}자" -f $POOL.Count, $SETS.Count, $SPEECH.Length, $DIARY.Length)

# ------------------------------------------------------------
# 2) 각 미션의 자료가 알려 주는 조건
#    - 말 / 문자 : 대본과 일기에 적힌 그대로
#    - 그림      : 벽화가 "그림으로 보여 줄 수 있는 것"만 적습니다.
#                  벽화1(돌)과 벽화4(장신구)는 흑백 선화라 색을 나타내지 못하므로
#                  색 조건을 넣지 않았습니다. 벽화2(손잡이)는 흰 나무를 희게,
#                  탄 나무를 검게 그려 색이 구분되므로 색 조건을 넣었습니다.
#    말풀이 : 조건은 (성질, 값, 자료에 그렇게 적혀 있는지 확인할 말) 입니다.
# ------------------------------------------------------------
$COND = @{
  speech = @{
    st = @( @('색','검은','검은색'), @('이끼','있음','이끼가 자랄'), @('모양','뾰족','뾰족하게 갈아라') )
    hd = @( @('길이','긴','길게 다듬어야'), @('색','흰','흰색 나무'), @('구움','안 구움','구우면') )
    vn = @( @('가시','있음','가시는 그대로 두어야'), @('이파리','없음','이파리는 하나도 남김없이 훑어내고') )
    or = @( @('색','흰','흰색 열매'), @('모양','네모','네모나게 깎고'),
            @('가시','없음','가시든 이파리든 하나도 남기지'), @('이파리','없음','가시든 이파리든 하나도 남기지') )
  }
  # 그림 미션에는 색 조건을 하나도 넣지 않았습니다.
  # 벽화에서 색이 전혀 구분되지 않아도 정답이 하나로 좁혀지는지 보기 위해서입니다.
  # (벽화2는 흰 나무와 탄 나무를 밝고 어둡게 그려 놓았지만, 그것에 기대지 않습니다.)
  picture = @{
    st = @( @('이끼','있음','벽화1: 달과 새싹 = 이끼가 자람'), @('모양','뾰족','벽화1: 갈아서 뾰족하게') )
    hd = @( @('길이','긴','벽화2: 긴 통나무를 깎음'), @('구움','구움','벽화2: 모닥불에 굽는 장면') )
    vn = @( @('가시','없음','벽화3: 가시를 떼어 바닥에 흩뿌림'), @('이파리','있음','벽화3: 이파리 달린 넝쿨로 엮음') )
    or = @( @('모양','네모','벽화4: 열매를 네모로 깎음'), @('가시','있음','벽화4: 네모에 가시가 남아 있음'),
            @('이파리','없음','벽화4: 이파리를 떼어냄') )
  }
  text = @{
    st = @( @('색','푸른','푸른색 돌을 찾아라'), @('이끼','있음','이끼가 자랄 때까지'), @('모양','둥근','둥근 모양으로 깎아야한다') )
    hd = @( @('길이','짧은','짧게 깎아야 한다'), @('색','흰','흰색 나무를 찾아라'), @('구움','구움','불에 살짝 구워라') )
    vn = @( @('가시','있음','가시와 이파리가 모두 달린 넝쿨'), @('이파리','있음','가시와 이파리가 모두 달린 넝쿨') )
    or = @( @('색','흰','흰색 열매를 구해'), @('모양','네모','네모 모양으로 깎아라'),
            @('가시','있음','가시와 이파리는 하나도 떼지 말고'), @('이파리','있음','가시와 이파리는 하나도 떼지 말고') )
  }
}

$MISSION_NAME = @{ speech = '🗣️ 말'; picture = '🎨 그림'; text = '📖 문자' }
$CAT_NAME     = @{ st = '망치 머리'; hd = '손잡이'; vn = '넝쿨'; or = '장신구' }
$MATERIAL     = @{ speech = $SPEECH; text = $DIARY }   # 그림은 본문이 없으므로 글자 대조에서 제외

# ------------------------------------------------------------
# 3) 미션마다: 조건으로 걸러서 한 장만 남는가 / 그게 정답인가
# ------------------------------------------------------------
$answers  = @{}
$trapHits = @{}

foreach ($mid in @('speech','picture','text')) {
  Head ("■ " + $MISSION_NAME[$mid] + " 미션")
  $answers[$mid]  = @{}
  $trapHits[$mid] = 0

  foreach ($cat in @('st','hd','vn','or')) {
    $ids      = $SETS[$mid][$cat]
    $declared = $ids[0]
    $conds    = $COND[$mid][$cat]

    # --- (a) 조건으로 거르기 ---
    $survivors = @()
    foreach ($id in $ids) {
      $card = $POOL[$id]
      $pass = $true
      foreach ($c in $conds) {
        if ($card.attr[$c[0]] -ne $c[1]) { $pass = $false; break }
      }
      if ($pass) { $survivors += $id }
    }

    $condText = ($conds | ForEach-Object { $_[0] + '=' + $_[1] }) -join ', '
    Write-Host ("  · {0,-9} 조건 [{1}]" -f $CAT_NAME[$cat], $condText)

    if ($survivors.Count -eq 1 -and $survivors[0] -eq $declared) {
      Ok ("남는 카드 1장 = 정답  →  " + $POOL[$declared].label)
      $answers[$mid][$cat] = $declared
    }
    elseif ($survivors.Count -eq 0) {
      Bad ("조건에 맞는 카드가 하나도 없습니다. 자료나 카드 세트가 어긋났습니다.")
    }
    elseif ($survivors.Count -gt 1) {
      Bad ("조건만으로 좁혀지지 않습니다. 남는 카드 " + $survivors.Count + "장: " +
           (($survivors | ForEach-Object { $POOL[$_].label }) -join ' / ') + "  ← 학생이 찍어야 합니다")
    }
    else {
      Bad ("남는 카드(" + $POOL[$survivors[0]].label + ")가 정해 둔 정답(" + $POOL[$declared].label + ")과 다릅니다.")
    }

    # --- (b) 자료 본문에 정말 그렇게 적혀 있는가 (말·문자만) ---
    if ($MATERIAL.ContainsKey($mid)) {
      $saidAll = $true
      foreach ($c in $conds) {
        if ($MATERIAL[$mid] -notlike ('*' + $c[2] + '*')) {
          Bad ("자료 본문에 '" + $c[2] + "' 라는 말이 없습니다 (" + $c[0] + '=' + $c[1] + " 조건)")
          $saidAll = $false
        }
      }
      if ($saidAll) { Ok ('조건이 모두 본문에 실제로 적혀 있습니다.') }

      # --- 옛 문장이 남아 다른 미션의 조건을 함께 말하고 있지 않은가 ---
      foreach ($other in @('speech','text')) {
        if ($other -eq $mid) { continue }
        foreach ($oc in $COND[$other][$cat]) {
          $mine = @($conds | Where-Object { $_[0] -eq $oc[0] })
          if ($mine.Count -eq 0 -or $mine[0][1] -eq $oc[1]) { continue }   # 값이 같으면 겹쳐도 됩니다
          if ($MATERIAL[$mid] -like ('*' + $oc[2] + '*')) {
            Bad ("본문에 다른 미션 조건 '" + $oc[2] + "' (" + $oc[0] + '=' + $oc[1] +
                 ") 가 남아 있습니다. 우리 조건은 " + $oc[0] + '=' + $mine[0][1] + ' 입니다.')
          }
        }
      }
    }

    # --- (c) 정답과 "한 가지만" 다른 함정 카드 세기 ---
    $traps = 0
    foreach ($id in $ids) {
      if ($id -eq $declared) { continue }
      $diff = 0
      foreach ($k in $POOL[$declared].attr.Keys) {
        if ($POOL[$id].attr[$k] -ne $POOL[$declared].attr[$k]) { $diff++ }
      }
      if ($diff -eq 1) { $traps++ }
      if ($diff -eq 0) { Bad ("카드 " + $id + " 가 정답과 성질이 완전히 같습니다 (구분 불가)") }
    }
    $trapHits[$mid] += $traps
    Write-Host ("            함정 카드(한 가지만 다름) {0}장 / 보기 {1}장" -f $traps, $ids.Count)

    # --- (d) 자료를 안 보고도 "혼자 튀는 것"을 찍어서 맞힐 수 있는가 ---
    #     정답만 가진 성질이 있으면, 네 장을 눈으로 견주는 것만으로 답이 드러납니다.
    foreach ($k in $POOL[$declared].attr.Keys) {
      $mine = $POOL[$declared].attr[$k]
      $same = @($ids | Where-Object { $POOL[$_].attr[$k] -eq $mine })
      if ($same.Count -eq 1) {
        Warn ("보기 네 장 가운데 '" + $k + '=' + $mine + "' 인 카드가 정답 하나뿐입니다. 자료를 안 들어도 찍힐 수 있습니다.")
      }
    }
  }
}

# ------------------------------------------------------------
# 4) 세 미션의 정답이 서로 다른가
# ------------------------------------------------------------
Head '■ 세 미션의 정답이 서로 다른가'
foreach ($cat in @('st','hd','vn','or')) {
  $trio = @($answers['speech'][$cat], $answers['picture'][$cat], $answers['text'][$cat])
  $uniq = ($trio | Select-Object -Unique)
  if ($uniq.Count -eq 3) {
    Ok ("{0,-9} 말={1} / 그림={2} / 문자={3}" -f $CAT_NAME[$cat],
        $POOL[$trio[0]].label, $POOL[$trio[1]].label, $POOL[$trio[2]].label)
  } else {
    Bad ($CAT_NAME[$cat] + ' 정답이 겹칩니다: ' + ($trio -join ', '))
  }
}

# ------------------------------------------------------------
# 5) 난이도 — 함정 카드 총수가 세 미션 모두 같은가
# ------------------------------------------------------------
Head '■ 그림 미션이 색에 기대지 않는가'
#   벽화는 동굴 그림이라 색이 흐릿하거나 아예 구분되지 않을 수 있습니다.
#   "색을 하나도 못 알아보는 학생"을 가정하고도 답이 하나로 좁혀져야 합니다.
$colorFree = $true
foreach ($cat in @('st','hd','vn','or')) {
  $used = @($COND['picture'][$cat] | Where-Object { $_[0] -eq '색' })
  if ($used.Count -gt 0) {
    Bad ($CAT_NAME[$cat] + ' 조건에 색이 들어 있습니다. 벽화로는 색을 장담할 수 없습니다.')
    $colorFree = $false
  }
}
if ($colorFree) { Ok '그림 미션 조건에 색이 하나도 쓰이지 않았습니다. 흑백으로 보여도 답이 나옵니다.' }

# 색을 빼고 남은 조건만으로도 정말 한 장만 남는지 다시 한 번 계산합니다.
foreach ($cat in @('st','hd','vn','or')) {
  $ids = $SETS['picture'][$cat]
  $surv = @()
  foreach ($id in $ids) {
    $pass = $true
    foreach ($c in $COND['picture'][$cat]) { if ($POOL[$id].attr[$c[0]] -ne $c[1]) { $pass = $false; break } }
    if ($pass) { $surv += $id }
  }
  if ($surv.Count -eq 1 -and $surv[0] -eq $ids[0]) {
    Ok ($CAT_NAME[$cat] + ' — 색 없이도 1장: ' + $POOL[$ids[0]].label)
  } else {
    Bad ($CAT_NAME[$cat] + ' — 색을 빼면 ' + $surv.Count + '장이 남습니다. 그림팀이 찍어야 합니다.')
  }
}
# 보기 네 장 가운데 색이 같은 카드가 섞여 있어도 괜찮은지 (색을 못 봐도 헷갈릴 일이 없는지)
foreach ($cat in @('st','hd','vn','or')) {
  $ids = $SETS['picture'][$cat]
  $ans = $ids[0]
  foreach ($id in $ids) {
    if ($id -eq $ans) { continue }
    $diffNonColor = 0
    foreach ($k in $POOL[$ans].attr.Keys) {
      if ($k -eq '색') { continue }
      if ($POOL[$id].attr[$k] -ne $POOL[$ans].attr[$k]) { $diffNonColor++ }
    }
    if ($diffNonColor -eq 0) {
      Bad ($POOL[$id].label + ' 는 색 말고는 정답과 똑같습니다. 그림팀이 구분할 수 없습니다.')
    }
  }
}

Head '■ 난이도 (정답과 한 가지만 다른 함정 카드 총수)'
$counts = @('speech','picture','text') | ForEach-Object { $trapHits[$_] }
foreach ($mid in @('speech','picture','text')) {
  Write-Host ("  {0,-8} {1}장" -f $MISSION_NAME[$mid], $trapHits[$mid])
}
if (($counts | Select-Object -Unique).Count -eq 1) { Ok ('세 미션 모두 ' + $counts[0] + '장으로 같습니다.') }
else { Bad '미션마다 함정 카드 수가 다릅니다. 한쪽이 더 어렵습니다.' }

# ------------------------------------------------------------
# 6) 말 대본 — 핵심 낱말이 딱 한 번씩만 나오는가
#    (여러 번 반복하면 듣고 기억하기가 쉬워져 다른 미션과 조건이 달라집니다)
# ------------------------------------------------------------
Head '■ 말 대본에서 핵심 낱말이 한 번씩만 나오는가'
foreach ($w in @('검은색','뾰족','흰색 나무','길게','네모','이끼')) {
  $n = ([regex]::Matches($SPEECH, [regex]::Escape($w))).Count
  if ($n -eq 1) { Ok ("'" + $w + "' " + $n + '번') }
  else          { Warn ("'" + $w + "' 가 " + $n + '번 나옵니다') }
}

# ------------------------------------------------------------
# 7) 자질구레한 확인
# ------------------------------------------------------------
Head '■ 그 밖의 확인'
foreach ($mid in @('speech','picture','text')) {
  foreach ($cat in @('st','hd','vn','or')) {
    $ids = $SETS[$mid][$cat]
    if ($ids.Count -ne 4) { Bad ($MISSION_NAME[$mid] + ' ' + $CAT_NAME[$cat] + ' 보기가 ' + $ids.Count + '장입니다 (4장이어야 합니다)') }
    if (($ids | Select-Object -Unique).Count -ne $ids.Count) { Bad ($MISSION_NAME[$mid] + ' ' + $CAT_NAME[$cat] + ' 에 같은 카드가 두 번 들어 있습니다') }
    foreach ($id in $ids) {
      if (-not $POOL.ContainsKey($id)) { Bad ('없는 카드를 가리킵니다: ' + $id) }
      elseif ($POOL[$id].cat -ne $cat) { Bad ($id + ' 는 ' + $CAT_NAME[$cat] + ' 가 아닙니다') }
    }
  }
}
foreach ($cat in @('st','hd','vn','or')) {
  $o = $ORDER[$cat] | Sort-Object
  if (($o -join ',') -ne '0,1,2,3') { Bad ($CAT_NAME[$cat] + ' 배치 순서가 0~3 네 자리가 아닙니다: ' + ($ORDER[$cat] -join ',')) }
}
# 카드 그림 파일이 다 있는가
$missing = @()
foreach ($mid in @('speech','picture','text')) {
  foreach ($cat in @('st','hd','vn','or')) {
    foreach ($id in $SETS[$mid][$cat]) {
      $p = Join-Path $root ('assets\cards\' + $id + '.jpg')
      if (-not (Test-Path $p)) { $missing += $id }
    }
  }
}
if ($missing.Count -eq 0) { Ok '쓰이는 카드 그림 파일이 모두 있습니다.' }
else { Bad ('카드 그림이 없습니다: ' + (($missing | Select-Object -Unique) -join ', ')) }

# 빌드 스크립트가 쓰이는 카드를 모두 심는가
$buildText = [System.IO.File]::ReadAllText((Join-Path $root 'build.ps1'), [System.Text.Encoding]::UTF8)
$notBuilt = @()
foreach ($mid in @('speech','picture','text')) {
  foreach ($cat in @('st','hd','vn','or')) {
    foreach ($id in $SETS[$mid][$cat]) { if ($buildText -notlike ("*'" + $id + "'*")) { $notBuilt += $id } }
  }
}
if ($notBuilt.Count -eq 0) { Ok 'build.ps1 이 쓰이는 카드를 모두 심습니다.' }
else { Bad ('build.ps1 에 빠진 카드: ' + (($notBuilt | Select-Object -Unique) -join ', ')) }

# 학생 QR 코드가 가리키는 배포 파일이 지금 템플릿과 같은 내용인가
# (이게 어긋나면 학생은 옛 미션을 받게 됩니다)
$pairs = @(
  @{ mid = 'speech';  deploy = 'mal.html';    answer = 'st_w4' },
  @{ mid = 'picture'; deploy = 'geurim.html'; answer = 'st_ok' },
  @{ mid = 'text';    deploy = 'munja.html';  answer = 'st_w2' }
)
$stale = @()
foreach ($p in $pairs) {
  $f = Join-Path $root $p.deploy
  if (-not (Test-Path $f)) { $stale += ($p.deploy + ' (없음)'); continue }
  $txt = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
  $dSet = [regex]::Match($txt, 'var MISSION_CARDS = \{(.*?)\n\};', 'Singleline').Groups[1].Value
  $sSet = [regex]::Match($src, 'var MISSION_CARDS = \{(.*?)\n\};', 'Singleline').Groups[1].Value
  $dDia = [regex]::Match($txt, 'var DIARY = \[(.*?)\n\];', 'Singleline').Groups[1].Value
  $sDia = [regex]::Match($src, 'var DIARY = \[(.*?)\n\];', 'Singleline').Groups[1].Value
  $dSpe = [regex]::Match($txt, 'var SPEECH_STEPS = \[(.*?)\n\];', 'Singleline').Groups[1].Value
  $sSpe = [regex]::Match($src, 'var SPEECH_STEPS = \[(.*?)\n\];', 'Singleline').Groups[1].Value
  if ($dSet -ne $sSet -or $dDia -ne $sDia -or $dSpe -ne $sSpe) { $stale += $p.deploy }
}
if ($stale.Count -eq 0) { Ok '학생 QR 코드가 가리키는 배포 파일이 지금 내용과 같습니다.' }
else { Bad ('배포 파일이 옛 내용입니다 → build.ps1 을 다시 돌리세요: ' + ($stale -join ', ')) }

# 말 미션 음성이 지금 대본으로 만들어진 것인가
# (대본만 고치고 소리를 다시 만들지 않으면 말 미션은 풀 수 없는 문제가 됩니다)
$spoken = Join-Path $root 'audio\story.txt'
$speechSteps = @([regex]::Matches($speechBlock, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value })
$nowStory = ($speechSteps -join ' ... ')
if (-not (Test-Path $spoken)) {
  Warn 'audio\story.txt 가 없어 음성이 지금 대본으로 만든 것인지 확인할 수 없습니다. 음성만들기.ps1 을 한 번 돌려 주세요.'
} elseif ([System.IO.File]::ReadAllText($spoken, [System.Text.Encoding]::UTF8).Trim() -ne $nowStory.Trim()) {
  Bad '말 미션 음성(audio\story.wav)이 지금 대본과 다릅니다 → 음성만들기.ps1 을 다시 돌리세요.'
} else {
  Ok '말 미션 음성이 지금 대본으로 만들어졌습니다.'
}

# ------------------------------------------------------------
Write-Host ''
Write-Host ('=' * 56)
if ($fail -eq 0) {
  Write-Host ("  모두 통과했습니다." + $(if ($warn) { "  (주의 " + $warn + "건)" } else { "" })) -ForegroundColor Green
  Write-Host '  세 미션 모두 자료만 보고 정답이 하나로 정해집니다.' -ForegroundColor Green
} else {
  Write-Host ("  실패 " + $fail + "건. 위 [실패] 항목을 고쳐야 합니다.") -ForegroundColor Red
}
Write-Host ('=' * 56)
exit $(if ($fail -eq 0) { 0 } else { 1 })
