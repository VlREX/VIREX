// VIREX AutoBridge v3.1.4 candidate - no automatic submission.
const name=String(uiv.getVar('!cmd_var1')||'');
const target=String(uiv.getVar('!cmd_var2')||'');
const id=String(uiv.getVar('!cmd_var3')||'');
if(!/^[0-9a-f]{32}$/.test(id)||name!=='virex-'+id+'.csv'||!/^https:\/\/chatgpt\.com\/(?:c\/|g\/g-[A-Za-z0-9_-]+\/c\/)[0-9a-fA-F-]{36}$/.test(target))throw new Error('Start from VIREX Studio.');
const ack='virex-'+id+'-ack.csv';
function editorHelpers(){
  const norm=s=>String(s??'').replace(/\r\n?/g,'\n').replace(/\u00a0/g,' ');
  function editor(){
    const list=Array.from(document.querySelectorAll('#prompt-textarea,div.ProseMirror[contenteditable="true"],[contenteditable="true"][role="textbox"]')).filter(e=>{
      const r=e.getBoundingClientRect(),s=getComputedStyle(e);
      return (e.isContentEditable||e.tagName==='TEXTAREA')&&r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden';
    });
    return list.length===1?list[0]:null;
  }
  function plain(root){
    const blocks=new Set(['P','DIV','PRE','LI','BLOCKQUOTE','H1','H2','H3','H4','H5','H6']);
    function walk(node){
      if(node.nodeType===3)return node.nodeValue||'';
      if(node.nodeType!==1)return '';
      if(node.tagName==='BR'){
        if(node.classList.contains('ProseMirror-trailingBreak')||node.parentNode.childNodes.length===1)return '';
        return '\n';
      }
      let out='',previousBlock=false,seen=false;
      for(const child of node.childNodes){
        if(child.nodeType!==1&&child.nodeType!==3)continue;
        const block=child.nodeType===1&&blocks.has(child.tagName);
        if(seen&&(block||previousBlock))out+='\n';
        out+=walk(child);
        seen=true;previousBlock=block;
      }
      return out;
    }
    return walk(root);
  }
  function candidates(e){
    if(e.tagName==='TEXTAREA')return [norm(e.value)];
    return [norm(plain(e)),norm(e.innerText),norm(Array.from(e.children).map(c=>c.innerText).join('\n'))];
  }
  function hasDraft(e){
    return candidates(e).some(s=>s.trim().length>0)||!!e.querySelector('img,video,iframe,[contenteditable="false"]:not(.ProseMirror-separator)');
  }
  function verify(target,report){
    if(location.href!==target)return 'WRONG_TARGET';
    const e=editor();if(!e)return 'EDITOR_NOT_UNIQUE';
    const expected=norm(report),values=candidates(e);
    const terminal=s=>s.endsWith('\n')?s.slice(0,-1):s;
    if(values.some(v=>v===expected||v===terminal(expected)||terminal(v)===expected))return 'VERIFIED';
    const firstDiff=(a,b)=>{let i=0;while(i<a.length&&i<b.length&&a[i]===b[i])i++;return i;};
    return 'MISMATCH expected='+expected.length+' candidates='+values.map(v=>v.length).join(',')+' firstDiff='+values.map(v=>firstDiff(v,expected)).join(',');
  }
  return {norm,editor,candidates,hasDraft,verify};
}
try{
  const rows=uiv.csv.read(name);
  if(rows.length!==1||rows[0].length!==1)throw new Error('Invalid report file.');
  const raw=JSON.parse(rows[0][0]);
  if(typeof raw!=='string'||!raw.length||raw.length>100000)throw new Error('Invalid report.');
  const report=raw.replace(/\r\n?/g,'\n');
  const tabs=uiv.tabs.list().filter(t=>t.url===target);
  if(tabs.length!==1)throw new Error('Open exactly one target conversation.');
  uiv.tabs.select(tabs[0].index);
  const helpers='const h=('+editorHelpers.toString()+')();const target='+JSON.stringify(target)+';const report='+JSON.stringify(report)+';';
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
  uiv.csv.write(ack,[['OK:'+id]]);
  uiv.log('VIREX AUTOBRIDGE | PASS | REPORT VERIFIED','green');
}catch(e){
  try{uiv.csv.write(ack,[['FAIL:'+id]]);}catch(_){}
  uiv.log('VIREX AUTOBRIDGE | FAIL','red');
  throw e;
}
