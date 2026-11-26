import {previewConfig} from '../lib/preview-config.js';
import {identify} from '../lib/auth.js';
import {execute} from '../lib/db.js';
import {route,problem,publicError} from '../lib/routes.js';
const limit=16384;
async function readBody(req) {
  if(req.method!=='POST') return {};
  if(!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type']??'')) throw problem(415,'JSON obrigatório');
  if(Number(req.headers['content-length']??0)>limit) throw problem(413,'Corpo grande');
  let body=req.body;
  if(body===undefined) {
    const chunks=[]; let length=0;
    for await(const chunk of req) { const b=Buffer.from(chunk); length+=b.length; if(length>limit) throw problem(413,'Corpo grande'); chunks.push(b); }
    body=Buffer.concat(chunks).toString('utf8');
  }
  try {
    if(Buffer.isBuffer(body)) body=body.toString('utf8');
    if(typeof body==='string') { if(Buffer.byteLength(body)>limit) throw problem(413,'Corpo grande'); body=JSON.parse(body); }
    if(!body || typeof body!=='object' || Array.isArray(body)) throw problem(400,'Objeto JSON obrigatório');
    if(Buffer.byteLength(JSON.stringify(body))>limit) throw problem(413,'Corpo grande');
    return body;
  } catch(e) { if(e.status) throw e; throw problem(400,'JSON inválido'); }
}
export default async function handler(req,res) {
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Vary','Origin');
  const send=(status,data)=>res.status(status).json(data);
  try {
    // Candidate never enables operations accidentally on production.
    if(process.env.PETITA_MODE!=='homologacao') throw problem(503,'Homologação desativada');
    const origin=req.headers.origin;
    if(origin && origin!==process.env.PETITA_WEB_ORIGIN) throw problem(403,'Origem não permitida');
    if(origin) res.setHeader('Access-Control-Allow-Origin',origin);
    res.setHeader('Access-Control-Allow-Methods','GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');
    if(req.method==='OPTIONS') return res.status(204).end();
    if(!['GET','POST'].includes(req.method)) throw problem(405,'Método não permitido');
    const path=new URL(req.url,'https://petita.invalid').pathname;
    if(req.method==='GET' && path==='/api/auth-preview-config') return send(200,previewConfig(process.env,req.headers.host));
    if(req.method==='GET' && path==='/api/health') return send(200,{status:'ok',mode:'homologacao',database_checked:false});
    const op=route(req.method,path,await readBody(req));
    const identity=op.isPublic?null:await identify(req.headers.authorization);
    return send(200,{data:await execute(op,identity)});
  } catch(e) { const error=publicError(e); return send(error.status,{error:error.message}); }
}
