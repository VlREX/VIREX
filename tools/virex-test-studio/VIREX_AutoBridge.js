// VIREX AutoBridge v3.1.6 candidate - automatic submission after verified insertion.
const name=String(uiv.getVar('!cmd_var1')||'');
const target=String(uiv.getVar('!cmd_var2')||'');
const id=String(uiv.getVar('!cmd_var3')||'');
if(!/^[0-9a-f]{32}$/.test(id)||name!=='virex-'+id+'.csv'||!/^https:\/\/chatgpt\.com\/(?:c\/|g\/g-[A-Za-z0-9_-]+\/c\/)[0-9a-fA-F-]{36}$/.test(target))throw new Error('Start from VIREX Studio.');
const ack='virex-'+id+'-ack.csv';

try{
  const rows=uiv.csv.read(name);
  if(rows.length!==1||rows[0].length!==1)throw new Error('Invalid report file.');
  const raw=JSON.parse(rows[0][0]);
  if(typeof raw!=='string'||!raw.length||raw.length>100000)throw new Error('Invalid report.');
  const report=raw.replace(/\r\n?/g,'\n');
  const tabs=uiv.tabs.list().filter(t=>t.url===target);
  if(tabs.length!==1)throw new Error('Open exactly one target conversation.');
  uiv.tabs.select(tabs[0].index);
  const helpers="const h=(function editorHelpers(){\n  const norm=s=>String(s??'').replace(/\\r\\n?/g,'\\n').replace(/\\u00a0/g,' ');\n  function editor(){\n    const list=Array.from(document.querySelectorAll('#prompt-textarea,div.ProseMirror[contenteditable=\"true\"],[contenteditable=\"true\"][role=\"textbox\"]')).filter(e=>{\n      const r=e.getBoundingClientRect(),s=getComputedStyle(e);\n      return (e.isContentEditable||e.tagName==='TEXTAREA')&&r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden';\n    });\n    return list.length===1?list[0]:null;\n  }\n  function plain(root){\n    const blocks=new Set(['P','DIV','PRE','LI','BLOCKQUOTE','H1','H2','H3','H4','H5','H6']);\n    function walk(node){\n      if(node.nodeType===3)return node.nodeValue||'';\n      if(node.nodeType!==1)return '';\n      if(node.tagName==='BR'){\n        if(node.classList.contains('ProseMirror-trailingBreak')||node.parentNode.childNodes.length===1)return '';\n        return '\\n';\n      }\n      let out='',previousBlock=false,seen=false;\n      for(const child of node.childNodes){\n        if(child.nodeType!==1&&child.nodeType!==3)continue;\n        const block=child.nodeType===1&&blocks.has(child.tagName);\n        if(seen&&(block||previousBlock))out+='\\n';\n        out+=walk(child);\n        seen=true;previousBlock=block;\n      }\n      return out;\n    }\n    return walk(root);\n  }\n  function candidates(e){\n    if(e.tagName==='TEXTAREA')return [norm(e.value)];\n    return [norm(plain(e)),norm(e.innerText),norm(Array.from(e.children).map(c=>c.innerText).join('\\n'))];\n  }\n  function hasDraft(e){\n    return candidates(e).some(s=>s.trim().length>0)||!!e.querySelector('img,video,iframe,[contenteditable=\"false\"]:not(.ProseMirror-separator)');\n  }\n  function verify(target,report){\n    if(location.href!==target)return 'WRONG_TARGET';\n    const e=editor();if(!e)return 'EDITOR_NOT_UNIQUE';\n    const expected=norm(report),values=candidates(e);\n    const terminal=s=>s.endsWith('\\n')?s.slice(0,-1):s;\n    if(values.some(v=>v===expected||v===terminal(expected)||terminal(v)===expected))return 'VERIFIED';\n    const firstDiff=(a,b)=>{let i=0;while(i<a.length&&i<b.length&&a[i]===b[i])i++;return i;};\n    return 'MISMATCH expected='+expected.length+' candidates='+values.map(v=>v.length).join(',')+' firstDiff='+values.map(v=>firstDiff(v,expected)).join(',');\n  }\n  return {norm,editor,candidates,hasDraft,verify};\n})();const target="+JSON.stringify(target)+';const report='+JSON.stringify(report)+';';
  const result=uiv.evaluate(helpers+'if(location.href!==target)return "WRONG_TARGET";const e=h.editor();if(!e)return "EDITOR_NOT_UNIQUE";if(h.hasDraft(e))return "DRAFT_EXISTS";e.focus();if(document.activeElement!==e)return "FOCUS_FAILED";return document.execCommand("insertText",false,report)?"INSERTED":"INSERT_FAILED";');
  if(result!=='INSERTED')throw new Error(result);
  let verified=false;
  for(let i=0;i<5;i++){
    uiv.sleep('1s');
    const state=uiv.evaluate(helpers+'return h.verify(target,report);');
    uiv.log('Verification '+(i+1)+': '+state);
    if(state==='VERIFIED'){verified=true;break;}
    if(state==='WRONG_TARGET')throw new Error(state);
  }
  if(!verified)throw new Error('Inserted but not verified. Draft retained.');
  // User opted into automatic submission by installing this macro.
  // Revalidate destination and report immediately before one send click.
  let submission='SEND_BUTTON_NOT_READY';
  for(let i=0;i<10;i++){
    submission=uiv.evaluate(helpers+"\nif(h.verify(target,report)!==\"VERIFIED\")return \"DRAFT_CHANGED\";\nconst editor=h.editor();\nif(!editor)return \"EDITOR_NOT_UNIQUE\";\nconst visible=b=>{const r=b.getBoundingClientRect(),s=getComputedStyle(b);return r.width>0&&r.height>0&&s.display!==\"none\"&&s.visibility!==\"hidden\"&&!b.disabled&&b.getAttribute(\"aria-disabled\")!==\"true\"};\nconst labels=new Set([\"send\",\"send prompt\",\"send message\",\"küldés\",\"üzenet küldése\",\"üzenet elküldése\",\"elküldés\",\"prompt küldése\"]);\nconst isSend=b=>{\n  const id=b.id||\"\",test=b.getAttribute(\"data-testid\")||\"\";\n  if(/stop|voice|mic|dictat/i.test(id+\" \"+test))return false;\n  return id===\"composer-submit-button\"||test===\"send-button\"||test===\"composer-send-button\"||[b.getAttribute(\"aria-label\"),b.getAttribute(\"title\"),b.getAttribute(\"data-tooltip\")].some(x=>labels.has(String(x||\"\").trim().toLowerCase()));\n};\nconst form=editor.closest(\"form\");\nlet buttons=Array.from((form||document).querySelectorAll(\"button\")).filter(b=>visible(b)&&isSend(b));\nif(buttons.length===0&&form)buttons=Array.from(document.querySelectorAll(\"button\")).filter(b=>visible(b)&&isSend(b));\nif(buttons.length!==1){\n  const diagnostic=Array.from((form||document).querySelectorAll(\"button\")).filter(visible).map(b=>[b.id,b.getAttribute(\"data-testid\"),b.getAttribute(\"aria-label\"),b.getAttribute(\"title\")].filter(Boolean).join(\"/\")).filter(Boolean).slice(-15).join(\" | \");\n  return \"SEND_BUTTON_NOT_READY:\"+buttons.length+\":\"+diagnostic;\n}\nconst button=buttons[0];\nif(location.href!==target||h.verify(target,report)!==\"VERIFIED\")return \"DRAFT_CHANGED\";\nconst count=document.querySelectorAll(\"[data-message-author-role=user]\").length;\nbutton.click();\nreturn \"CLICKED:\"+count;");
    if(/^CLICKED:\d+$/.test(submission))break;
    uiv.log('Send attempt '+(i+1)+': '+submission);
    if(!submission.startsWith('SEND_BUTTON_NOT_READY'))throw new Error(submission);
    uiv.sleep('1s');
  }
  if(!/^CLICKED:\d+$/.test(submission))throw new Error(submission);
  const count=Number(submission.split(':')[1]);
  let confirmed=false;
  for(let i=0;i<12;i++){
    uiv.sleep('1s');
    const state=uiv.evaluate(helpers+'if(location.href!==target)return "WRONG_TARGET";const e=h.editor();if(!e)return "WAIT";const count=document.querySelectorAll("[data-message-author-role=user]").length;return !h.hasDraft(e)&&count>'+count+'?"SENT":"WAIT";');
    if(state==='SENT'){confirmed=true;break;}
    if(state==='WRONG_TARGET')break;
  }
  if(!confirmed)throw new Error('SUBMISSION_UNCONFIRMED: inspect conversation; do not retry automatically.');
  uiv.csv.write(ack,[['OK:'+id]]);
  uiv.log('VIREX AUTOBRIDGE | PASS | REPORT SENT','green');
}catch(e){
  try{uiv.csv.write(ack,[['FAIL:'+id]]);}catch(_){}
  uiv.log('VIREX AUTOBRIDGE | FAIL','red');
  throw e;
}
