// A pagina publica so muda para o APK 0.3.0 DEPOIS que a release assinada
// existir no GitHub. Ate la, mantem o download anterior sem links quebrados.
const REPO='petsaudemonitoramento-dev/petita-plano-parto';
const RELEASE_TAG='petita-v0.3.0-20261104';
const ASSET='Petita-Android-v0.3.0-arm64.apk';
const FALLBACK='https://github.com/'+REPO+'/releases/download/petita-teste-20261029/Petita-Teste-Android-2026-10-29.apk';
module.exports=async function handler(req,res) {
  if(req.method!=='GET' && req.method!=='HEAD'){
    res.setHeader('Allow','GET, HEAD');
    return res.status(405).send('Metodo nao permitido');
  }
  res.setHeader('Cache-Control','no-store, max-age=0');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','no-referrer');
  let destination=FALLBACK;
  try{
    const controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),4500);
    try{
      const rsp=await fetch('https://api.github.com/repos/'+REPO+'/releases/tags/'+RELEASE_TAG,{
        headers:{Accept:'application/vnd.github+json','User-Agent':'petita-download'},
        signal:controller.signal,
      });
      if(rsp.ok){
        const release=await rsp.json();
        const apk=release.assets?.find(x=>x.name===ASSET && x.size>3000000);
        if(release.tag_name===RELEASE_TAG && apk?.browser_download_url?.startsWith(
          'https://github.com/'+REPO+'/releases/download/'+RELEASE_TAG+'/')){
          destination=apk.browser_download_url;
        }
      }
    }finally{clearTimeout(timeout);}
  }catch(_){/* GitHub temporariamente indisponivel: manter download anterior */ }
  return res.redirect(302,destination);
};
