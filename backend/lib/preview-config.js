import {problem} from './routes.js';
export function previewConfig(env,host){
  if(env.PETITA_MODE!=='homologacao'||env.PETITA_AUTH_PREVIEW!=='enabled'||!env.NEON_AUTH_BASE_URL||!env.PETITA_WEB_ORIGIN)throw problem(404,'Homologação indisponível');
  const origin=new URL(env.PETITA_WEB_ORIGIN);
  if(origin.protocol!=='https:'||origin.host!==host)throw problem(403,'Origem não permitida');
  const auth=new URL(env.NEON_AUTH_BASE_URL);
  if(auth.protocol!=='https:'||!auth.hostname.endsWith('.neon.tech')||auth.username||auth.password||auth.search||auth.hash)throw problem(503,'Configuração inválida');
  return {auth_url:auth.href};
}
