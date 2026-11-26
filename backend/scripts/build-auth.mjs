import {build} from 'esbuild';
await build({entryPoints:['src/auth-preview.js'],bundle:true,platform:'browser',format:'esm',target:'es2022',outfile:'public/auth-preview.js',minify:true,logLevel:'warning'});
