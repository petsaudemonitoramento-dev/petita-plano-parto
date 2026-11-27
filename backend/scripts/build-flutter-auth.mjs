import {build} from 'esbuild';
await build({entryPoints:['src/flutter-auth-bridge.js'],bundle:true,platform:'browser',format:'esm',target:'es2022',outfile:'../web/neon_auth_bridge.js',minify:true,logLevel:'warning'});
