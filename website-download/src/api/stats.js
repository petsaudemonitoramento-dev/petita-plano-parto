// Estatisticas sao downloads do asset, nao instalacoes nem pessoas unicas.
const API='https://api.github.com/repos/petsaudemonitoramento-dev/petita-plano-parto/releases/tags/petita-teste-20261029';
const NAME='Petita-Teste-Android-2026-10-29.apk';
module.exports=async function handler(req,res){
 if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'Metodo nao permitido'});}
 try{
   const response=await fetch(API,{headers:{Accept:'application/vnd.github+json','User-Agent':'petita-download'},signal:AbortSignal.timeout(7000)});
   if(!response.ok)throw new Error('Release unavailable');
   const data=await response.json();
   const file=(data.assets||[]).find(a=>a.name===NAME);
   if(!file)throw new Error('File unavailable');
   res.setHeader('Cache-Control','public, s-maxage=120, stale-while-revalidate=300');
   return res.status(200).json({downloads:file.download_count,bytes:file.size,available:true,metric:'downloads_do_arquivo'});
 }catch(_){return res.status(503).json({available:false});}
};
