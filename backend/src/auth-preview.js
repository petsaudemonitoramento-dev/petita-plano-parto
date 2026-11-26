import {createAuthClient} from '@neondatabase/auth';
const status=document.querySelector('#status');
const form=document.querySelector('#auth');
const buttons=[...form.querySelectorAll('button')];
const get=id=>document.getElementById(id);
let auth;
const show=s=>{status.textContent=s;};
function requireOk(result){if(result?.error)throw Error('auth');return result?.data;}
async function profile(){
  const {data}=await auth.token();
  const token=data?.token;
  if(typeof token!=='string'||!token)throw Error('session');
  const headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'};
  const enrolled=await fetch('/api/profile',{method:'POST',headers,body:'{}',cache:'no-store',redirect:'error'});
  if(!enrolled.ok)throw Error('profile:'+enrolled.status);
  const me=await fetch('/api/me',{headers,cache:'no-store',redirect:'error'});
  if(!me.ok)throw Error('profile:'+me.status);
  const body=await me.json();
  if(!Array.isArray(body.data)||body.data.length!==1||body.data[0].role!=='patient')throw Error('profile');
  show('Perfil comum de gestante confirmado no Neon.');
}
async function action(name){
  const email=get('email').value.trim();
  const password=get('password').value;
  try{
    if(name==='signup'){requireOk(await auth.signUp.email({name:get('name').value.trim(),email,password}));show('Cadastro solicitado. Verifique o código enviado por e-mail.');}
    else if(name==='login'){requireOk(await auth.signIn.email({email,password}));show('Login realizado. Verifique a sessão e crie o perfil.');}
    else if(name==='resend'){requireOk(await auth.emailOtp.sendVerificationOtp({email,type:'email-verification'}));show('Solicitação de reenvio concluída.');}
    else if(name==='verify'){requireOk(await auth.emailOtp.verifyEmail({email,otp:get('otp').value.trim()}));show('E-mail confirmado. Entre com sua conta para continuar.');}
    else if(name==='session'){const data=requireOk(await auth.getSession());show(data?.user?'Sessão autenticada.':'Nenhuma sessão autenticada.');}
    else if(name==='profile'){await profile();}
    else if(name==='logout'){requireOk(await auth.signOut());show('Sessão encerrada.');}
  }catch(e){show('Operação não concluída. Confirme os dados e a configuração do ambiente. '+(/^profile:[0-9]{3}$/.test(e.message)?'HTTP '+e.message.slice(8):''));}
  finally{get('password').value='';get('otp').value='';}
}
async function init(){
  buttons.forEach(b=>b.disabled=true);
  try{
    const res=await fetch('/api/auth-preview-config',{cache:'no-store',redirect:'error'});
    if(!res.ok)throw Error('config');
    const {auth_url}=await res.json();
    const u=new URL(auth_url);
    if(u.protocol!=='https:'||!u.hostname.endsWith('.neon.tech')||u.username||u.password||u.search||u.hash)throw Error('config');
    auth=createAuthClient(u.href);
    form.addEventListener('submit',e=>e.preventDefault());
    form.addEventListener('click',async e=>{
      const b=e.target.closest('button[data-action]');if(!b||b.disabled)return;
      buttons.forEach(x=>x.disabled=true);
      try{await action(b.dataset.action);}finally{buttons.forEach(x=>x.disabled=false);}
    });
    buttons.forEach(b=>b.disabled=false);
    show('Ambiente pronto. Use uma conta de teste.');
  }catch{show('Ambiente de autenticação indisponível.');}
}
init();
