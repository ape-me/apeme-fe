const cache=new Map(), pending=new Map(), failedPaths=new Set();
function snapshotFor(path){
 const pathname=path.split('?')[0],query=new URLSearchParams(path.split('?')[1]||'');
 if(pathname.endsWith('/history')){const data=SNAP[pathname];return data&&(!query.get('range')||query.get('range')===data.range)?data:{points:[]};}
 if(pathname.endsWith('/candles')){const data=SNAP[pathname];return data&&(!data.tf||query.get('tf')===data.tf)?data:{candles:[]};}
 if(pathname.startsWith('/wallet/'))return pathname==='/wallet/'+DEMO_ADDR?SNAP['/wallet/']:null;
 const key=Object.keys(SNAP).sort((a,b)=>b.length-a.length).find(k=>path===k||path.startsWith(k+'&')||(!k.includes('?')&&pathname===k));
 if(!key)return null;const data=JSON.parse(JSON.stringify(SNAP[key]));
 if(data.tokens&&pathname.endsWith('/tokens')){const sorts={vol24h:'vol24hUsd',new:'createdAt',mcap:'mcapUsd',progress:'progressPct'},field=sorts[query.get('sort')];if(field)data.tokens.sort((a,b)=>(b[field]||0)-(a[field]||0));}
 return data;
}
async function requestData(path){
 if(pending.has(path))return pending.get(path);
 const work=(async()=>{const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),7000);
 try{const r=await fetch(API+path,{signal:controller.signal});if(!r.ok)throw new Error(r.status);const d=visible(await r.json());cache.set(path,{t:Date.now(),d});failedPaths.delete(path);state.online=failedPaths.size===0;updateDataStatus();return d;}
 catch(e){failedPaths.add(path);state.online=false;updateDataStatus();const old=cache.get(path);if(old)return old.d;const snap=snapshotFor(path);if(snap)return snap;throw e;}
 finally{clearTimeout(timeout);pending.delete(path);}})();pending.set(path,work);return work;
}
/* Assets that must never reach the screen, whatever the API returns. Not a hard-coded stock
   list — everything else renders as the BE sends it — this is the one deny-list. */
const HIDDEN=new Set(['SPCXX']);
const visible=d=>{ if(!d||typeof d!=='object') return d;
  if(Array.isArray(d.stocks)) d.stocks=d.stocks.filter(x=>!HIDDEN.has((x.symbol||'').toUpperCase()));
  if(Array.isArray(d.items)) d.items=d.items.filter(x=>!HIDDEN.has((x.symbol||'').toUpperCase()));
  if(Array.isArray(d.collections)) d.collections.forEach(c=>{ if(Array.isArray(c.stocks)) c.stocks=c.stocks.filter(x=>!HIDDEN.has((x.symbol||'').toUpperCase())); });
  ['gainers','losers','mostTraded'].forEach(k=>{ if(Array.isArray(d[k])) d[k]=d[k].filter(x=>!HIDDEN.has((x.symbol||'').toUpperCase())); });
  return d; };

async function api(path,ttl=5000){const c=cache.get(path);if(c&&ttl>0){if(Date.now()-c.t>=ttl)requestData(path).catch(()=>{});return c.d;}return requestData(path);}
