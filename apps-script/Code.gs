/**
 * 우가투스투스 미션 — 결과 저장소 (Google Apps Script)
 *
 * 이 파일을 Google 스프레드시트의 [확장 프로그램 > Apps Script]에 붙여넣고
 * [배포 > 새 배포 > 웹 앱]으로 배포하면, 학생용 웹앱 3개와 교사용 결과판이
 * 하나의 시트에 결과를 모읍니다.
 *
 * 배포 설정
 *   실행 계정      : 나
 *   액세스 권한    : 모든 사용자   ← 학생이 로그인 없이 제출하려면 반드시 필요합니다.
 *
 * 배포 후 나오는 https://script.google.com/macros/s/....../exec 주소를
 * 학생용 웹앱 3개와 교사용 결과판에 똑같이 넣어 주세요.
 */

var SHEET_NAME = '응답';

var HEADERS = [
  '제출일시', '이름', '번호', '미션', '점수', '성공여부',
  '정답개수', '오답개수', '소요시간(초)', '시도', '선택한답', '어려웠던점', '기록ID'
];

/* ============================================================
   요청 처리
   ============================================================ */

function doGet(e) {
  return handle((e && e.parameter) || {});
}

function doPost(e) {
  var p = {};
  try {
    p = JSON.parse(e.postData.contents);
  } catch (err) {
    p = (e && e.parameter) || {};
  }
  return handle(p);
}

function handle(p) {
  var out;
  try {
    var action = p.action || 'list';
    if (action === 'submit')       out = actionSubmit(p);
    else if (action === 'reflect') out = actionReflect(p);
    else if (action === 'list')    out = actionList();
    else                           out = { ok: false, error: 'unknown action: ' + action };
  } catch (err) {
    out = { ok: false, error: String(err && err.message ? err.message : err) };
  }
  return reply(out, p.callback);
}

/**
 * JSONP(callback 지정)와 순수 JSON을 모두 지원합니다.
 * 학교망이나 Canva 임베드에서 CORS가 막히는 경우가 있어 JSONP를 기본으로 씁니다.
 */
function reply(obj, callback) {
  var json = JSON.stringify(obj);
  if (callback && /^[A-Za-z_][A-Za-z0-9_]*$/.test(callback)) {
    return ContentService
      .createTextOutput(callback + '(' + json + ');')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService
    .createTextOutput(json)
    .setMimeType(ContentService.MimeType.JSON);
}

/* ============================================================
   동작
   ============================================================ */

function actionSubmit(p) {
  if (!p['이름']) return { ok: false, error: '이름이 비어 있습니다.' };

  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var sh = getSheet();
    var id = p['기록ID'] || Utilities.getUuid();

    // 같은 기록ID가 이미 있으면 다시 쓰지 않습니다 (중복 제출 방지).
    if (findRowById(sh, id) > 0) return { ok: true, id: id, duplicated: true };

    sh.appendRow([
      p['제출일시'] || new Date().toISOString(),
      p['이름'] || '',
      p['번호'] || '',
      p['미션'] || '',
      toNum(p['점수']),
      p['성공여부'] || '',
      toNum(p['정답개수']),
      toNum(p['오답개수']),
      toNum(p['소요시간(초)']),
      toNum(p['시도']) || 1,
      p['선택한답'] || '',
      p['어려웠던점'] || '',
      id
    ]);
    return { ok: true, id: id };
  } finally {
    lock.releaseLock();
  }
}

function actionReflect(p) {
  var id = p['기록ID'];
  if (!id) return { ok: false, error: '기록ID가 없습니다.' };

  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var sh = getSheet();
    var row = findRowById(sh, id);
    if (row < 1) return { ok: false, error: '해당 기록을 찾을 수 없습니다.' };
    var col = HEADERS.indexOf('어려웠던점') + 1;
    sh.getRange(row, col).setValue(p['어려웠던점'] || '');
    return { ok: true, id: id };
  } finally {
    lock.releaseLock();
  }
}

function actionList() {
  var sh = getSheet();
  var last = sh.getLastRow();
  if (last < 2) return { ok: true, rows: [] };

  var values = sh.getRange(2, 1, last - 1, HEADERS.length).getValues();
  var rows = values.map(function (r) {
    var o = {};
    for (var i = 0; i < HEADERS.length; i++) {
      var v = r[i];
      o[HEADERS[i]] = (v instanceof Date) ? v.toISOString() : v;
    }
    return o;
  }).filter(function (o) {
    return o['이름'] !== '' && o['이름'] != null;
  });

  return { ok: true, rows: rows };
}

/* ============================================================
   도우미
   ============================================================ */

function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
  }
  if (sh.getLastRow() === 0) {
    sh.appendRow(HEADERS);
    sh.getRange(1, 1, 1, HEADERS.length).setFontWeight('bold');
    sh.setFrozenRows(1);
    서식잡기(sh);
  }
  return sh;
}

/**
 * 읽기 좋게 열 너비와 줄바꿈을 잡아 줍니다.
 * 짧은 항목은 내용에 맞추고, 문장이 긴 항목은 너비를 고정한 뒤 줄바꿈합니다.
 * 시트를 이미 만든 뒤라면 편집기에서 서식다시잡기 를 실행하세요.
 */
function 서식잡기(sh) {
  var 고정너비 = { '선택한답': 320, '어려웠던점': 260, '제출일시': 150, '기록ID': 90 };

  for (var i = 0; i < HEADERS.length; i++) {
    var col = i + 1;
    var name = HEADERS[i];
    if (고정너비[name]) {
      sh.setColumnWidth(col, 고정너비[name]);
    } else {
      sh.autoResizeColumn(col);
      // 자동 맞춤이 머리글보다 좁아지지 않도록 여유를 둡니다.
      if (sh.getColumnWidth(col) < 80) sh.setColumnWidth(col, 80);
    }
  }

  // 긴 문장은 셀 안에서 접히게, 나머지는 한 줄로 둡니다.
  var 줄바꿈열 = ['선택한답', '어려웠던점'];
  for (var j = 0; j < 줄바꿈열.length; j++) {
    var c = HEADERS.indexOf(줄바꿈열[j]) + 1;
    if (c > 0) sh.getRange(1, c, sh.getMaxRows(), 1).setWrap(true);
  }

  sh.getRange(1, 1, 1, HEADERS.length)
    .setBackground('#F1E7D2')
    .setVerticalAlignment('middle');
}

/** 시트를 이미 만든 뒤에 서식만 다시 잡고 싶을 때 실행하세요. */
function 서식다시잡기() {
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
  if (!sh) { Logger.log('"' + SHEET_NAME + '" 시트가 아직 없습니다.'); return; }
  서식잡기(sh);
  Logger.log('서식을 다시 잡았습니다.');
}

function findRowById(sh, id) {
  var last = sh.getLastRow();
  if (last < 2) return -1;
  var col = HEADERS.indexOf('기록ID') + 1;
  var ids = sh.getRange(2, col, last - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) return i + 2;
  }
  return -1;
}

function toNum(v) {
  var n = Number(v);
  return isFinite(n) ? n : 0;
}

/**
 * (선택) 스크립트 편집기에서 한 번 실행해 보면 시트와 머리글이 만들어지고,
 * 권한 승인 창이 떠서 배포 전에 권한을 미리 허용할 수 있습니다.
 *
 * 실행 방법: 저장(Ctrl+S) → 위쪽 함수 목록에서 setup 선택 → [실행]
 *   ※ 저장하기 전에는 함수 목록에 나타나지 않습니다.
 *   ※ 이 단계를 건너뛰고 바로 배포해도 됩니다. 시트는 첫 제출 때 자동으로 만들어집니다.
 */
function setup() {
  getSheet();
  Logger.log('준비 완료: "' + SHEET_NAME + '" 시트를 확인하세요.');
}

/** setup 과 같은 기능입니다. 한글 이름이 편하신 분을 위해 남겨 둡니다. */
function 준비하기() {
  setup();
}
