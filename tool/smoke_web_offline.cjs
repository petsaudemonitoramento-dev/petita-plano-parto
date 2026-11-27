// Internal Cloud Chromium smoke. Isolated profile; no Auth/API writes or deployment.
const {chromium}=require('playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
(async()=>{
 const root=path.resolve('build/web');
 const server=http.createServer((req,res)=>{
  const file=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname));
  if(!file.startsWith(root+path.sep)&&file!==root){res.writeHead(403).end();return;}
  const target=fs.existsSync(file)&&fs.statSync(file).isDirectory()?path.join(file,'index.html'):file;
  const types={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.json':'application/json','.css':'text/css'};
  if(!fs.existsSync(target)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',types[path.extname(target)]||'application/octet-stream');fs.createReadStream(target).pipe(res);
 });
 await new Promise(resolve=>server.listen(8767,'127.0.0.1',resolve));
 let browser;
 try{
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,chromiumSandbox:true});
  const context=await browser.newContext({viewport:{width:390,height:844}});
  const fixtureMode=process.argv.includes('--institutional-fixtures');
  let granted=false,consentWrites=0,planWrites=0;const trace=[];
  const id='00000000-0000-4000-8000-000000000001';
  await context.route(/https:\/\/.*(?:neon\.tech|vercel\.app)\//,async route=>{
    if(!fixtureMode)return route.abort();
    const req=route.request(),url=new URL(req.url()),p=url.pathname;trace.push(req.method()+' '+p);
    let data;
    if(url.hostname.endsWith('.neon.tech')){
      data=p.endsWith('/token')?{token:'fixture-api-token'}:{user:{id,name:'SYNTHETIC',email:'fixture@example.invalid',emailVerified:true,banned:false},session:{id,token:'opaque-fixture',userId:id,expiresAt:'2027-01-01T00:00:00.000Z',createdAt:'2026-01-01T00:00:00.000Z',updatedAt:'2026-01-01T00:00:00.000Z'}};
    }else{
      let rows=[];
      if(p==='/api/me')rows=[{id,role:'patient',ubs_code:null,display_name:'SYNTHETIC'}];
      if(p==='/api/profile')rows=[{id}];
      if(p==='/api/consent' && req.method()==='POST'){
        const body=req.postDataJSON();
        if(!['accepted_terms','accepted_privacy','accepted_responsibility','accepted_plan_science','accepted_health_data','accepted_online_sync'].every(k=>body[k]===true))throw Error('Consent flag missing');
        granted=true;consentWrites++;
      }
      if(p==='/api/consent')rows=[{terms_version:'2026-10-21-v1',action:granted?'grant':'withdraw'}];
      if(p==='/api/plans' && req.method()==='POST'){
        if(!granted)throw Error('Plan written without consent');planWrites++;
        const body=req.postDataJSON();rows=[{id:body.id,revision:body.expected_revision+1}];
      }
      data={data:rows};
    }
    return route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'http://127.0.0.1:8767','access-control-allow-credentials':'true'},body:JSON.stringify(data)});
  });
  const page=await context.newPage();
  await page.goto('http://127.0.0.1:8767/',{waitUntil:'networkidle',timeout:30000});
  await page.waitForFunction(()=>Object.keys(localStorage).some(k=>k.includes('petita_patient_envelope_v1')),{timeout:30000});
  const semantics=page.locator('flt-semantics-placeholder');
  if(await semantics.count())await semantics.dispatchEvent('click');
  await page.getByText('Seu espaço de cuidado',{exact:false}).waitFor({timeout:20000});
  await page.reload({waitUntil:'networkidle',timeout:30000});
  const enable=page.locator('flt-semantics-placeholder');if(await enable.count())await enable.dispatchEvent('click');
  await page.getByText('Seu espaço de cuidado',{exact:false}).waitFor({timeout:20000});
  if(fixtureMode){
    await page.setViewportSize({width:900,height:8000});
    await page.getByText('Meu perfil',{exact:false}).dispatchEvent('click');
    const localChoices=page.getByRole('checkbox');await localChoices.first().waitFor();
    if(await localChoices.count()!==5)throw Error('Local consent count');
    for(let i=0;i<5;i++)await localChoices.nth(i).dispatchEvent('click');
    await page.getByRole('button',{name:'Concordar e começar',exact:true}).dispatchEvent('click');
    await page.getByRole('button',{name:'Entrar online',exact:true}).dispatchEvent('click');
    await page.getByText('Perfil institucional: patient',{exact:true}).waitFor({timeout:20000});
    const online=page.getByRole('checkbox');
    if(await online.count()!==6)throw Error('Online consent count');
    for(let i=0;i<6;i++)if(await online.nth(i).isChecked())throw Error('Implicit online consent');
    await page.getByRole('button',{name:'Registrar consentimento online',exact:true}).dispatchEvent('click');
    await page.getByText('Não foi possível concluir a operação.',{exact:false}).waitFor();
    if(consentWrites!==0)throw Error('Implicit consent POST');
    for(let i=0;i<6;i++)await online.nth(i).dispatchEvent('click');
    await page.getByRole('button',{name:'Registrar consentimento online',exact:true}).dispatchEvent('click');
    await page.getByText('Consentimento online registrado.',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Salvar e sincronizar meu plano',exact:true}).dispatchEvent('click');
    await page.getByText('Plano salvo e sincronizado.',{exact:false}).waitFor();
    if(consentWrites!==1 || planWrites!==1)throw Error('Write count mismatch');
    const leaked=await page.evaluate(()=>Object.values(localStorage).some(v=>v.includes('fixture-api-token')||v.includes('opaque-fixture')));
    if(leaked)throw Error('Session secret persisted in Web localStorage');
    console.log('PASS: real Flutter/official SDK browser UI with exclusively intercepted fictional Auth/API: six unchecked consent flags, implicit grant blocked, explicit consent and plan ACK. NOT real Neon integration.');
  }
  fs.mkdirSync('build/test_artifacts',{recursive:true});
  await page.screenshot({path:'build/test_artifacts/web-offline-startup.png'});
  if(!fixtureMode)console.log('PASS: real Flutter Web bootstrap, encrypted envelope and reopening; institutional API/Auth unavailable; no credentials or patient data.');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error('Web smoke failed:',e.name,e.message?.split('\n').slice(0,6).join('\n'));process.exitCode=1;});
