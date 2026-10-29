// Redirect only to the immutable APK of the inspected 2026-10-29 prerelease.
// GitHub serves the actual binary; no 166 MB serverless proxy or ZIP extraction.
const URL='https://github.com/petsaudemonitoramento-dev/petita-plano-parto/releases/download/petita-teste-20261029/Petita-Teste-Android-2026-10-29.apk';

module.exports=function handler(req,res){
 if(req.method!=='GET'&&req.method!=='HEAD'){res.setHeader('Allow','GET, HEAD');return res.status(405).send('Método não permitido');}
 res.setHeader('Cache-Control','no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 return res.redirect(302,URL);
};
