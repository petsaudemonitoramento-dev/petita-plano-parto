// Counter based on actual public GitHub Release asset downloads.
// This measures file downloads, not unique people or completed installations.
const RELEASE_API='https://api.github.com/repos/petsaudemonitoramento-dev/petita-plano-parto/releases/tags/petita-teste-20261029';
const FILENAME='Petita-Teste-Android-2026-10-29.apk';

module.exports=async function handler(req,res){
  if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'Método não permitido'});}
  try{
    const upstream=await fetch(RELEASE_API,{headers:{'Accept':'application/vnd.github+json','User-Agent':'petita-download-site','X-GitHub-Api-Version':'2022-11-28'},signal:AbortSignal.timeout(7000)});
    if(!upstream.ok)throw new Error('Release unavailable '+upstream.status);
    const release=await upstream.json();
    const asset=(release.assets||[]).find(a=>a.name===FILENAME);
    if(!asset)throw new Error('Verified release asset not found');
    res.setHeader('Cache-Control','public, s-maxage=120, stale-while-revalidate=300');
    res.setHeader('Content-Type','application/json; charset=utf-8');
    return res.status(200).json({downloads:asset.download_count,bytes:asset.size,available:true,tag:release.tag_name,metric:'downloads_do_arquivo'});
  }catch(e){
    res.setHeader('Cache-Control','no-store');
    return res.status(503).json({downloads:null,available:false,error:'Estatísticas temporariamente indisponíveis'});
  }
};
