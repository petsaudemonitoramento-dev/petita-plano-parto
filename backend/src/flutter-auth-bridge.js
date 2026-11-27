const error=status=>JSON.stringify({error:{status:Number.isInteger(status)?status:503}});
// Same-origin HTTPS: the session cookie is HttpOnly and never exposed to Flutter.
globalThis.petitaNeonAuthCall=async(action,payload)=>{
 try {
  const {body={}}=JSON.parse(payload);
  if(!['signup','login','verify','resend','requestReset','reset','session','token','logout'].includes(action))return error(400);
  const r=await fetch('/petita-auth/'+action,{method:'POST',headers:{'Content-Type':'application/json'},credentials:'same-origin',body:JSON.stringify(body),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(16000)});
  if(!r.ok)return error(r.status);
  const result=await r.json();
  if(!result||typeof result.data!=='object'||result.data===null)return error(503);
  return JSON.stringify({data:result.data});
 }catch{return error(503);}
};
