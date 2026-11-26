// The Neon SDK can inject the signed JWT from set-auth-jwt into the
// authenticated getSession response. Never forward an opaque session secret.
// Shape checks are defensive only; the institutional API verifies signature,
// issuer, audience, expiry and subject independently.
export function isAccessJWT(value) {
  return typeof value === 'string' && value.length <= 16384 &&
    /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value);
}

export async function sessionAccessToken(auth) {
  const session = await auth.getSession();
  if (session?.error) return {error: session.error};
  if (!session?.data?.user?.id) return {error:{status:401}};
  const candidate = session.data.session?.token;
  if (isAccessJWT(candidate)) return {data:{token:candidate}};
  // Some SDK/provider combinations expose the JWT only through the plugin.
  const result = await auth.token();
  if (result?.error) return {error:result.error};
  if (!isAccessJWT(result?.data?.token)) return {error:{status:503}};
  return {data:{token:result.data.token}};
}
