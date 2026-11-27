const error=status=>JSON.stringify({error:{status:Number.isInteger(status)?status:503}});
async function invoke(action,body){
 const r=await fetch('/petita-auth/'+action,{method:'POST',headers:{'Content-Type':'application/json'},credentials:'same-origin',body:JSON.stringify(body),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(16000)});
 if(!r.ok)return {error:{status:r.status}};
 const result=await r.json();
 if(!result||typeof result.data!=='object'||result.data===null)return {error:{status:503}};
 return {data:result.data};
}
let exchange;
globalThis.petitaNeonAuthCall=async(action,payload)=>{
 try {
  const {body={}}=JSON.parse(payload);
  if(!['signup','login','verify','resend','requestReset','reset','session','token','logout','googleStart'].includes(action))return error(400);
  const current=new URL(location.href);
  const verifier=current.searchParams.get('neon_auth_session_verifier');
  if(verifier && !exchange){
   current.searchParams.delete('neon_auth_session_verifier');
   history.replaceState(history.state,'',current.href);
   exchange=invoke('googleFinish',{verifier});
  }
  if(exchange){
   const result=await exchange;
   exchange=null;
   if(result.error)return JSON.stringify(result);
   if(action==='session')return JSON.stringify(result);
  }
  const result=await invoke(action,body);
  if(action==='googleStart'&&!result.error){
   const url=new URL(result.data.url);
   if(url.protocol!=='https:'||url.username||url.password||!(url.origin==='https://accounts.google.com'||url.hostname.endsWith('.neon.tech')))return error(503);
   location.assign(url.href);
   return JSON.stringify({data:{}});
  }
  return JSON.stringify(result);
 }catch{return error(503);}
};
