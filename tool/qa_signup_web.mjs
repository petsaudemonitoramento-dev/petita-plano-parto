import http from 'node:http';
import fs from 'node:fs';
import {spawn} from 'node:child_process';
const bridge = fs.readFileSync('web/neon_auth_bridge.js');
const url = JSON.parse(fs.readFileSync('config/homologacao.json')).PETITA_AUTH_URL;
const page = `<script type="module">
import '/bridge.js';
const suffix = crypto.randomUUID();
const email = 'petita-qa-'+suffix+'@example.invalid', password=crypto.randomUUID()+crypto.randomUUID();
async function report(step){ await fetch('/report',{method:'POST',body:step}); }
async function call(action,body={}) {
  const r=JSON.parse(await globalThis.petitaNeonAuthCall(action, JSON.stringify({url:${JSON.stringify(url)},body})));
  if (r.error) throw Error(action+' '+r.error.status);
  return r.data;
}
try {
 await call('signup',{email,password,name:'Teste automatizado Petita Web'});
 await report('signup');
 await call('login',{email,password});
 await report('login');
 const data=await call('session');
 if(data.user?.email!==email) throw Error('session');
 await report('session');
 const token=await call('token');
 if(!token.token) throw Error('token');
 await call('logout');
 await report('success');
} catch(e) {await report('failure '+e.message);}
</script>`;
let done; const completed=new Promise(resolve=>done=resolve);
const srv=http.createServer((req,res)=>{
 if(req.url==='/report'&&req.method==='POST'){
   let value='';req.on('data',b=>value+=b);req.on('end',()=>{
     res.end();if(!/^(signup|login|session|success|failure (signup|login|session|token|logout)( [0-9]{3})?)$/.test(value)){done(false);return;}
     console.log(value);if(value==='success'||value.startsWith('failure')) done(value==='success');
   });return;
 }
 if(req.url==='/bridge.js'){res.setHeader('content-type','text/javascript');res.end(bridge);return;}
 res.setHeader('content-type','text/html');res.end(page);
});
await new Promise(r=>srv.listen(8767,'127.0.0.1',r));
const chrome=spawn('google-chrome',['--headless=new','--disable-dev-shm-usage','--user-data-dir=/tmp/petita-qa-web-'+process.pid,'http://localhost:8767/'],{stdio:'ignore'});
chrome.on('error',()=>done(false));chrome.on('exit',()=>done(false));
const timer=setTimeout(()=>{console.log('Browser timeout');done(false)},50000);
try{process.exitCode=await completed?0:1;}finally{clearTimeout(timer);chrome.kill();srv.closeAllConnections();srv.close();}
