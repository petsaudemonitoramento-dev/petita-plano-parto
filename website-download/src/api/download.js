// Mantem o APK publico de teste atual ate a nova versao passar em homologacao.
const APK = 'https://github.com/petsaudemonitoramento-dev/petita-plano-parto/releases/download/petita-teste-20261029/Petita-Teste-Android-2026-10-29.apk';
module.exports = function handler(req,res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.setHeader('Allow','GET, HEAD');
    return res.status(405).send('Metodo nao permitido');
  }
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  return res.redirect(302,APK);
};
