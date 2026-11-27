// VIREX AutoBridge 3.1.0 – local only, never submits.
const name = String(uiv.getVar('!cmd_var1') || '');
const target = String(uiv.getVar('!cmd_var2') || '');
const id = String(uiv.getVar('!cmd_var3') || '');
if (!/^[0-9a-f]{32}$/.test(id) || name !== 'virex-' + id + '.csv' ||
    !/^https:\/\/chatgpt\.com\/(?:c\/|g\/g-[A-Za-z0-9_-]+\/c\/)[0-9a-fA-F-]{36}$/.test(target)) {
  throw new Error('Run via Studio AutoBridge launcher.');
}
const ack = 'virex-' + id + '-ack.csv';
try {
  const rows = uiv.csv.read(name);
  if (rows.length !== 1 || rows[0].length !== 1) throw new Error('Invalid report file.');
  const report = JSON.parse(rows[0][0]);
  if (typeof report !== 'string' || !report.length || report.length > 100000) throw new Error('Invalid report.');
  const matching = uiv.tabs.list().filter(t => t.url === target);
  if (matching.length !== 1) throw new Error('Open exactly one tab with saved conversation.');
  uiv.tabs.select(matching[0].index);
  if (uiv.evaluate('return location.href') !== target) throw new Error('Wrong conversation.');
  const selectors = ['#prompt-textarea','div.ProseMirror[contenteditable="true"]','div[contenteditable="true"][role="textbox"]','textarea#prompt-textarea'];
  let selector = null;
  for (const s of selectors) {
    const matches = uiv.$$('css=' + s, {required:false, timeout:2});
    if (matches.length === 1) { selector = s; break; }
    if (matches.length > 1) throw new Error('Ambiguous composer.');
  }
  if (!selector) throw new Error('Composer not found.');
  const inspect = 'const e=document.querySelector('+JSON.stringify(selector)+'); return {url:location.href, exists:!!e, text:e?(e.value===undefined?e.innerText:e.value):null};';
  const before = uiv.evaluate(inspect);
  if (before.url !== target || !before.exists || String(before.text || '').trim()) throw new Error('Existing draft or wrong destination.');
  // Literal text, not key commands; never press Enter or click Send.
  uiv.page.fill('css='+selector, report);
  const after = uiv.evaluate(inspect);
  const normalize = s => String(s || '').replace(/\r\n/g, '\n').replace(/\u00a0/g, ' ').trim();
  if (after.url !== target || normalize(after.text) !== normalize(report)) throw new Error('Paste could not be verified; check draft manually.');
  uiv.csv.write(ack, [['OK:'+id]]);
  uiv.log('VIREX report inserted; send manually.', 'green');
} catch (e) {
  try { uiv.csv.write(ack, [['FAIL:'+id]]); } catch (_) {}
  throw e;
}
