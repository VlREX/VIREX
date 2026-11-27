// VIREX Batch Import v1 - no execution, no send, only a marked assistant plan.
const name=String(uiv.getVar('!cmd_var1')||'');
const target=String(uiv.getVar('!cmd_var2')||'');
const id=String(uiv.getVar('!cmd_var3')||'');
if(!/^[0-9a-f]{32}$/.test(id)||name!=='virex-import-'+id+'.csv'||!/^https:\/\/chatgpt\.com\/(?:c\/|g\/g-[A-Za-z0-9_-]+\/c\/)[0-9a-fA-F-]{36}$/.test(target))throw new Error('Start from Studio.');
try{
  const tabs=uiv.tabs.list().filter(t=>t.url===target);
  if(tabs.length!==1)throw new Error('Open exactly one configured conversation.');
  uiv.tabs.select(tabs[0].index);
  const raw=uiv.evaluate('if(location.href!=='+JSON.stringify(target)+')throw new Error("Wrong conversation");const messages=Array.from(document.querySelectorAll("[data-message-author-role]"));const latest=messages[messages.length-1];if(!latest||latest.getAttribute("data-message-author-role")!=="assistant")throw new Error("No completed assistant plan");if(document.querySelector("button[data-testid=stop-button],button#composer-submit-button[aria-label=Stop]"))throw new Error("Response still generating");const matches=Array.from(latest.querySelectorAll("pre code")).map(e=>e.textContent).filter(s=>{try{const p=JSON.parse(s);return p&&p.virex_batch===1&&Array.isArray(p.profiles)}catch(_){return false}});if(matches.length!==1)throw new Error("Expected exactly one marked VIREX batch");return JSON.stringify(JSON.parse(matches[0]).profiles);');
  if(typeof raw!=='string'||raw.length>60000)throw new Error('Invalid or oversized plan.');
  const plan=JSON.parse(raw);
  if(!Array.isArray(plan)||plan.length<1||plan.length>12)throw new Error('Invalid profile count.');
  uiv.csv.write(name,[[id,'OK',raw]]);
  uiv.log('VIREX IMPORT | '+plan.length+' profiles | awaiting local approval','green');
}catch(e){
  try{uiv.csv.write(name,[[id,'FAIL',String(e.message||e).slice(0,500)]]);}catch(_){}
  throw e;
}
