import {isAccessJWT} from '../src/session-access-token.js';
const upstreamName='__Secure-neon-auth.session_token';
const localName='__Secure-petita-session';
const actions={
 signup:['POST','/sign-up/email',['name','email','password']],
 login:['POST','/sign-in/email',['email','password']],
 verify:['POST','/email-otp/verify-email',['email','otp']],
 resend:['POST','/email-otp/send-verification-otp',['email','type']],
 requestReset:['POST','/email-otp/request-password-reset',['email']],
 reset:['POST','/email-otp/reset-password',['email','otp','password']],
 session:['GET','/get-session',[]],
 token:['GET','/get-session',[]],
 logout:['POST','/sign-out',[]]
};
const validCookie=v=>typeof v==='string'&&v.length>0&&v.length<=4096&&/^[\x21-\x3A\x3C-\x7E]+$/.test(v)&&!v.includes(',');
const cookieValue=(header,name)=>{
 const pairs=String(header??'').split(';').map(x=>x.trim()).filter(x=>x.startsWith(name+'='));
 const v=pairs.length===1?pairs[0].slice(name.length+1):null;
 return validCookie(v)?v:null;
};
function setLocal(res,value,age) {
 res.setHeader('Set-Cookie',localName+'='+(value??'')+'; Path=/petita-auth; Secure; HttpOnly; SameSite=Strict'+(age===null?'':'; Max-Age='+age));
}
export async function webAuthProxy(req,res,action,body,env=process.env,fetcher=fetch) {
 const fail=status=>res.status(status).json({error:{status}});
 const ok=data=>res.status(200).json({data});
 if(req.method!=='POST')return fail(405);
 if(env.PETITA_MODE!=='homologacao'||req.headers.origin!==env.PETITA_WEB_ORIGIN||req.headers['sec-fetch-site']==='cross-site')return fail(403);
 if(!Object.hasOwn(actions,action))return fail(404);
 const [method,path,fields]=actions[action];
 if(!body||Array.isArray(body)||Object.keys(body).some(k=>!fields.includes(k))||fields.some(k=>typeof body[k]!=='string'||!body[k].length||body[k].length>512))return fail(400);
 let base;
 try {base=new URL(env.NEON_AUTH_BASE_URL);if(base.protocol!=='https:'||!base.hostname.endsWith('.neon.tech')||base.username||base.password||base.search||base.hash||base.pathname.replace(/\/$/,'')!=='/neondb/auth')return fail(503);}catch{return fail(503);}
 let credential=cookieValue(req.headers.cookie,localName);
 const call=async(m,p,b)=>{
  const headers={Accept:'application/json',Origin:env.PETITA_WEB_ORIGIN};
  if(credential)headers.Cookie=upstreamName+'='+credential;
  if(m==='POST')headers['Content-Type']='application/json';
  const r=await fetcher(base.href.replace(/\/$/,'')+p,{method:m,headers,body:m==='POST'?JSON.stringify(b):undefined,redirect:'error',signal:AbortSignal.timeout(12000)});
  for(const c of r.headers.getSetCookie()){
   const first=c.split(';',1)[0];
   if(!first.startsWith(upstreamName+'='))continue;
   const val=first.slice(upstreamName.length+1);
   const rawAge=c.match(/;\s*max-age=(-?\d+)/i)?.[1];
   const age=rawAge===undefined?null:Math.min(604800,Math.max(0,Number(rawAge)));
   if(!validCookie(val)||age===0){credential=null;setLocal(res,null,0);}
   else {credential=val;setLocal(res,val,age);}
  }
  let data;try{data=await r.json();}catch{data=null;}
  return {r,data};
 };
 try{
  if(action==='login'||action==='signup'){credential=null;setLocal(res,null,0);}
  if((action==='session'||action==='token')&&!credential)return action==='session'?ok({}):fail(401);
  const {r,data}=await call(method,path,body);
  if(action==='logout'){setLocal(res,null,0);return r.ok?ok({}):fail(503);}
  if(!r.ok)return fail([400,401,403,404,409,422,429].includes(r.status)?r.status:503);
  if(action==='login'&&!credential)return fail(503);
  if(action==='token'){
   if(!data?.user?.id)return fail(401);
   let token=r.headers.get('set-auth-jwt')??data.session?.token;
   if(!isAccessJWT(token)){const t=await call('GET','/token',{});if(!t.r.ok)return fail(503);token=t.data?.token;}
   return isAccessJWT(token)?ok({token}):fail(503);
  }
  if(action==='session'&&!data?.user?.id){setLocal(res,null,0);return ok({});}
  const u=data?.user;
  return ok(u?{user:{id:u.id,name:u.name,email:u.email,emailVerified:u.emailVerified},session:{expiresAt:data.session?.expiresAt}}:{});
 }catch{if(action==='logout'||action==='login')setLocal(res,null,0);return fail(503);}
}
