import {createAuthClient} from '@neon/auth';
let auth, origin;
const error=status=>({error:{status:Number.isInteger(status)?status:503}});
// A local generated bundle of the pinned official SDK; no CDN, tokens in
// localStorage, credential logging, arbitrary redirects or anonymous fallback.
globalThis.petitaNeonAuthCall=async(action,payload)=>{
  try {
    const {url,body={}}=JSON.parse(payload);
    const u=new URL(url);
    if(u.protocol!=='https:'||!u.hostname.endsWith('.neon.tech')||u.username||u.password||u.search||u.hash) return JSON.stringify(error(503));
    if(origin && origin!==u.href) return JSON.stringify(error(503));
    if(!auth){auth=createAuthClient(u.href);origin=u.href;}
    let result;
    switch(action){
      case 'signup': result=await auth.signUp.email(body);break;
      case 'login': result=await auth.signIn.email(body);break;
      case 'verify': result=await auth.emailOtp.verifyEmail(body);break;
      case 'resend': result=await auth.emailOtp.sendVerificationOtp(body);break;
      case 'requestReset': result=await auth.emailOtp.requestPasswordReset(body);break;
      case 'reset': result=await auth.emailOtp.resetPassword(body);break;
      case 'session': result=await auth.getSession();break;
      case 'token': result=await auth.token();break;
      case 'logout': result=await auth.signOut();break;
      default:return JSON.stringify(error(400));
    }
    if(result?.error) return JSON.stringify(error(result.error.status));
    const data=result?.data??{};
    if(action==='token')return JSON.stringify({data:{token:data.token}});
    // Never send Better Auth's session secret to Flutter Web or its storage.
    const user=data.user;
    return JSON.stringify({data:user?{user:{id:user.id,name:user.name,email:user.email,emailVerified:user.emailVerified},session:{expiresAt:data.session?.expiresAt}}:{}});
  }catch{return JSON.stringify(error(503));}
};
