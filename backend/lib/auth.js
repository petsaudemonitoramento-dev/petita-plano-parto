import { createRemoteJWKSet, jwtVerify } from 'jose';
import { problem } from './routes.js';
let cached;
export function authOrigin(base) {
  const u=new URL(base);
  if(u.protocol!=='https:' || u.username || u.password || u.search || u.hash) throw problem(503,'Configuração inválida');
  return u.origin;
}
export function verifiedIdentity(payload,origin) {
  if(payload.iss!==origin || !(payload.aud===origin || (Array.isArray(payload.aud) && payload.aud.includes(origin))) ||
    typeof payload.sub!=='string' || !payload.sub.trim() || payload.sub.length>512 ||
    typeof payload.emailVerified!=='boolean' || payload.banned!==false) throw problem(401,'Sessão inválida');
  return {issuer:origin,subject:payload.sub};
}
export async function identify(header) {
  const base=process.env.NEON_AUTH_BASE_URL, jwks=process.env.NEON_AUTH_JWKS_URL;
  if(!base||!jwks) throw problem(503,'Auth não configurado');
  const origin=authOrigin(base);
  if(new URL(jwks).origin!==origin || jwks!==base.replace(/\/$/,'')+'/.well-known/jwks.json') throw problem(503,'JWKS inválido');
  const token=typeof header==='string' && /^Bearer ([^\s]{1,16384})$/.exec(header);
  if(!token) throw problem(401,'Autenticação necessária');
  try {
    if(!cached || cached.url!==jwks) cached={url:jwks,keys:createRemoteJWKSet(new URL(jwks),{timeoutDuration:5000})};
    return await verifyAccessToken(token[1],cached.keys,origin);
  } catch { throw problem(401,'Sessão inválida'); }
}

// Production identify() always supplies the validated remote JWKS above.
export async function verifyAccessToken(token,keys,origin){
  try{
    const {payload}=await jwtVerify(token,keys,{issuer:origin,audience:origin,algorithms:['EdDSA'],requiredClaims:['sub','iat','exp'],maxTokenAge:'15m',clockTolerance:5});
    return verifiedIdentity(payload,origin);
  }catch{throw problem(401,'Sessão inválida');}
}
