import { createRemoteJWKSet, jwtVerify } from 'jose';

let remoteJwks;
export async function identify(req) {
  const baseUrl = process.env.NEON_AUTH_BASE_URL;
  const jwksUrl = process.env.NEON_AUTH_JWKS_URL;
  if (!baseUrl || !jwksUrl || !process.env.DATABASE_URL) {
    throw Object.assign(new Error('Servico nao configurado'), { status: 503 });
  }
  const header = req.headers.authorization ?? '';
  const match = /^Bearer ([^\s]+)$/.exec(header);
  if (!match) throw Object.assign(new Error('Autenticacao obrigatoria'), { status: 401 });
  remoteJwks ??= createRemoteJWKSet(new URL(jwksUrl));
  try {
    // Token Neon Auth, nunca token do Google ou campo de usuario enviado pelo cliente.
    const { payload } = await jwtVerify(match[1], remoteJwks, {
      issuer: baseUrl, algorithms: ['EdDSA'],
    });
    if (typeof payload.sub !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.sub)) {
      throw new Error('sub invalido');
    }
    return payload.sub;
  } catch {
    throw Object.assign(new Error('Sessao invalida ou expirada'), { status: 401 });
  }
}
