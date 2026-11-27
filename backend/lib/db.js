import pg from 'pg';
import {problem} from './routes.js';
let pool;
function connection() {
  // No production cutover from this candidate. Only a dedicated non-owner login.
  if(process.env.PETITA_MODE!=='homologacao' || !process.env.DATABASE_URL || !process.env.PETITA_DB_LOGIN) throw problem(503,'Banco não configurado');
  const url=new URL(process.env.DATABASE_URL);
  if(!['postgresql:','postgres:'].includes(url.protocol) || url.searchParams.get('sslmode')!=='verify-full') throw problem(503,'TLS obrigatório');
  if(decodeURIComponent(url.username)!==process.env.PETITA_DB_LOGIN) throw problem(503,'Login inesperado');
  if(!pool) pool=new pg.Pool({connectionString:process.env.DATABASE_URL,max:2,connectionTimeoutMillis:5000,idleTimeoutMillis:10000});
  return pool;
}
export async function execute(operation,identity) {
  if(!operation.isPublic && !identity) throw problem(401,'Autenticação necessária');
  const client=await connection().connect();
  let discard=false;
  try {
    await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
    await client.query("SET LOCAL statement_timeout='5s'");
    const {rows:[role]}=await client.query("select session_user as login,rolsuper,rolbypassrls,rolcreaterole,rolcreatedb from pg_roles where rolname=session_user");
    if(!role || role.login!==process.env.PETITA_DB_LOGIN || role.rolsuper || role.rolbypassrls || role.rolcreaterole || role.rolcreatedb) throw problem(503,'Login de banco inadequado');
    await client.query('SET LOCAL ROLE petita_runtime');
    const {rows:[runtime]}=await client.query("select current_user as role,rolbypassrls,rolsuper,rolcanlogin from pg_roles where rolname=current_user");
    if(runtime?.role!=='petita_runtime' || runtime.rolbypassrls || runtime.rolsuper || runtime.rolcanlogin) throw problem(503,'Role insegura');
    await client.query("select set_config('petita.issuer',$1,true),set_config('petita.subject',$2,true)",[identity?.issuer??'',identity?.subject??'']);
    if(identity) {
      const {rows:[verified]}=await client.query('select petita.auth_identity_active() as active');
      if(verified?.active!==true) throw problem(401,'Identidade inativa');
    }
    if(identity && !operation.enrollment) {
      const {rows:[actor]}=await client.query('select petita_private.actor_id() as id');
      if(!actor?.id) throw problem(403,'Perfil ainda não habilitado');
    }
    if(operation.actorLock) await client.query("select pg_advisory_xact_lock(hashtextextended(petita_private.actor_id()::text, 1))");
    const result=await client.query(operation.sql,operation.params);
    if(operation.requireRow && result.rowCount!==1) throw problem(409,'Conflito ou operação já registrada');
    await client.query('COMMIT');
    return result.rows;
  } catch(error) {
    try { await client.query('ROLLBACK'); } catch { discard=true; }
    throw error;
  } finally { client.release(discard); }
}
