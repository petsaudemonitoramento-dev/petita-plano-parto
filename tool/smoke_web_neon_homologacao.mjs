// Browser integration against the fixed homologation hostname, no credentials in logs.
import { chromium, webkit } from 'playwright';
import { randomUUID, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
const cfg=JSON.parse(readFileSync(new URL('../config/homologacao.json',import.meta.url)));
const origin='https://petita-flutter-web-homologacao.vercel.app';
const api='https://petita-api-neon-homologacao-petsaudemonitoramento-devs-projects.vercel.app';
if(cfg.PETITA_API_ORIGIN!==api||!cfg.PETITA_AUTH_URL.endsWith('/neondb/auth'))throw Error('homologation guard');
let failed=false;
for(const [name,engine] of [['chromium',chromium],['webkit',webkit]]){
 let browser;
 try{
  browser=await engine.launch({headless:true});
  const context=await browser.newContext({viewport:{width:390,height:844}});
  const page=await context.newPage();
  await page.goto(origin,{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForFunction(()=>typeof globalThis.petitaNeonAuthCall==='function',{},{timeout:30000});
  const email='petita-web-smoke-'+randomUUID()+'@example.com',password='Test!'+randomBytes(24).toString('hex');
  const result=await page.evaluate(async ({auth,api,email,password})=>{
   const steps=[];
   async function call(action,body={}){
    const raw=await globalThis.petitaNeonAuthCall(action,JSON.stringify({url:auth,body}));
    const r=JSON.parse(raw);
    steps.push(action+':'+(r.error?'error '+r.error.status:'ok'));
    if(r.error)throw Error(action+' '+r.error.status);
    return r.data;
   }
   async function request(path,method,token,body){
    const r=await fetch(api+path,{method,headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,redirect:'error',signal:AbortSignal.timeout(15000)});
    steps.push(path+':'+r.status);
    if(r.status!==200)throw Error(path+' '+r.status);
    return r.json();
   }
   try{
    await call('signup',{name:'SYNTHETIC WEB',email,password});
    await call('login',{email,password});
    const session=await call('session');
    if(!session.user?.id||session.user.emailVerified!==false)throw Error('session identity');
    const {token}=await call('token');
    if(typeof token!=='string'||token.split('.').length!==3)throw Error('missing signed JWT');
    await request('/api/profile','POST',token,{});
    const p=await request('/api/me','GET',token);
    if(p.data?.[0]?.role!=='patient')throw Error('patient role');
    await call('logout');
    return {ok:true,steps};
   }catch(e){return {ok:false,steps,error:String(e?.message??'unknown').slice(0,100)};}
  },{auth:cfg.PETITA_AUTH_URL,api,email,password});
  console.log(name,JSON.stringify(result));
  if(!result.ok)failed=true;
  await context.close();
 }catch(e){console.error(name,'browser infrastructure failure:',String(e?.message??'unknown').split('\n')[0].slice(0,160));failed=true;}
 finally{await browser?.close();}
}
if(failed)process.exitCode=1;
