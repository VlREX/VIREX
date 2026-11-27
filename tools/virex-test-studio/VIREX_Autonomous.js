// Bounded autonomous session bridge. Standard browser file input; fail closed.
const name=String(uiv.getVar('!cmd_var1')||'');
const target=String(uiv.getVar('!cmd_var2')||'');
const id=String(uiv.getVar('!cmd_var3')||'');
if(!/^[0-9a-f]{32}$/.test(id)||name!=='virex-auto-'+id+'.csv'||!/^https:\/\/chatgpt\.com\/(?:c\/|g\/g-[A-Za-z0-9_-]+\/c\/)[0-9a-fA-F-]{36}$/.test(target))throw new Error('Start from Studio.');
const ack='virex-auto-'+id+'-ack.csv';
function reply(state,payload){uiv.csv.write(ack,[[id,state,String(payload||'')]]);}
try{
 const rows=uiv.csv.read(name);
 if(rows.length!==1||rows[0].length!==1)throw new Error('Invalid job.');
 const job=JSON.parse(rows[0][0]);
 if(!/^[0-9a-f]{32}$/.test(job.session)||![1,2,3,4].includes(job.round)||job.kind!=='REPORT')throw new Error('Invalid session.');
 const tabs=uiv.tabs.list().filter(t=>t.url===target);
 if(tabs.length!==1)throw new Error('Open one configured conversation.');
 uiv.tabs.select(tabs[0].index);
 const prefix='const target='+JSON.stringify(target)+';const job='+JSON.stringify(job)+';if(location.href!==target)throw new Error("Wrong conversation");';
 const helpers="\n const visible=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'};\n \n const stop=()=>Array.from(document.querySelectorAll('button')).some(b=>visible(b)&&(/stop/i.test(b.getAttribute('data-testid')||'')||/^(stop|leállítás|leállítja a generálást)$/i.test(b.getAttribute('aria-label')||'')));\n const editor=()=>{let es=Array.from(document.querySelectorAll('#prompt-textarea,div.ProseMirror[contenteditable=\"true\"],[contenteditable=\"true\"][role=\"textbox\"]')).filter(e=>visible(e)&&(e.isContentEditable||e.tagName==='TEXTAREA'));if(es.length===0)es=Array.from(document.querySelectorAll('textarea,[contenteditable=\"true\"]')).filter(e=>visible(e)&&(e.isContentEditable||e.tagName==='TEXTAREA'));return es.length===1?es[0]:null};\n const textOf=e=>String(e.value??e.innerText??'').trim();\n const scope=e=>e.closest('form')||e.closest('[data-type=\"unified-composer\"]')||e.parentElement.parentElement;\n const send=e=>{const labels=['send','send message','send prompt','küldés','üzenet küldése','üzenet elküldése','elküldés'];const a=Array.from(scope(e).querySelectorAll('button')).filter(b=>visible(b)&&!b.disabled&&b.getAttribute('aria-disabled')!=='true'&&!/stop|voice|mic/i.test(b.id+' '+b.getAttribute('data-testid'))&&(b.id==='composer-submit-button'||['send-button','composer-send-button'].includes(b.getAttribute('data-testid'))||labels.includes(String(b.getAttribute('aria-label')||'').toLowerCase())));return a.length===1?a[0]:null};\n \n const reportVisible=(marker,file,e)=>{\n   const candidates=Array.from(document.querySelectorAll('body *')).filter(n=>n.children.length===0&&visible(n)&&String(n.innerText||n.textContent||'').includes(marker));\n   return candidates.some(n=>{\n     for(let p=n;p&&p!==document.body;p=p.parentElement){\n       if(e&&p.contains(e))break;\n       const t=String(p.innerText||p.textContent||'');\n       if(t.length>12000)break;\n       if(t.includes(marker)&&t.includes(file))return true;\n     }\n     return false;\n   });\n };\n";
 if(job.kind!=='REPORT')throw new Error('Legacy poll disabled; use Studio GitHub mailbox.');
 {
   if(job.file!=='VIREX_'+job.session+'_R'+job.round+'.txt'||typeof job.base64!=='string'||job.base64.length>1400000)throw new Error('Invalid report.');
   const marker='VIREX AUTONOMOUS REPORT '+job.session+' R'+job.round;
   const header='const marker='+JSON.stringify(marker)+';';
   const attached=uiv.evaluate(prefix+helpers+header+"\n      if(stop())return 'BUSY';\n      const e=editor();if(!e||textOf(e))return 'DRAFT_EXISTS_OR_MISSING';\n      if(reportVisible(marker,job.file,e))return 'REPORT_ALREADY_VISIBLE';\n      const root=scope(e);\n      if(root.querySelector('[data-testid*=\"attachment\"],[data-testid*=\"file-preview\"]'))return 'EXISTING_ATTACHMENT';\n      let inputs=Array.from(root.querySelectorAll('input[type=file]')).filter(f=>!f.disabled);\n      if(inputs.length===0)inputs=Array.from(document.querySelectorAll('input[type=file]')).filter(f=>!f.disabled);\n      if(inputs.length!==1||inputs[0].files.length)return 'FILE_INPUT_NOT_UNIQUE';\n      e.focus();if(document.activeElement!==e||!document.execCommand('insertText',false,marker))return 'INSERT_FAILED';\n      const bytes=Uint8Array.from(atob(job.base64),c=>c.charCodeAt(0));\n      const file=new File([bytes],job.file,{type:'text/plain'});\n      const dt=new DataTransfer();dt.items.add(file);\n      inputs[0].files=dt.files;\n      inputs[0].dispatchEvent(new Event('change',{bubbles:true}));\n      return 'ATTACHED';\n   ");
   if(attached!=='ATTACHED')throw new Error(attached);
   let clicked=false;
   for(let i=0;i<60;i++){
     uiv.sleep('1s');
     const status=uiv.evaluate(prefix+helpers+header+"\n       const e=editor();if(!e||textOf(e)!==marker)return 'DRAFT_CHANGED';\n       const root=scope(e),b=send(e);\n       if(stop()||!b||!String(root.innerText||'').includes(job.file)||root.querySelector('[role=progressbar],[aria-busy=true]'))return 'WAIT';\n       b.click();return 'CLICKED';\n     ");
     if(status==='CLICKED'){clicked=true;break;}
     if(status!=='WAIT')throw new Error(status);
   }
   if(!clicked)throw new Error('Attachment/send not ready.');
   let confirmed=false;
   for(let i=0;i<20;i++){
     uiv.sleep('1s');
     const status=uiv.evaluate(prefix+helpers+header+"\n       const e=editor();\n       return e&&!textOf(e)&&reportVisible(marker,job.file,e)?'SENT':'WAIT';\n");
     if(status==='SENT'){confirmed=true;break;}
   }
   if(!confirmed)throw new Error('SUBMISSION_UNCONFIRMED; do not retry automatically.');
   reply('SENT',job.file);
 }
}catch(e){try{reply('FAIL',String(e.message||e).slice(0,500));}catch(_){}throw e;}
