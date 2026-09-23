/* ============ news & insights (BE: /stocks/:mint/insights, /news) ============ */
const NEWS_BY_ID=new Map();
const SESSION_LABEL={pre:'Pre-market',open:'Market open',post:'After hours',closed:'Closed'};

/* Only material and worse earns a badge — minor is noise, none/null is nothing (BE's call). */
function newsBadges(i){
  let out='';
  if(i.impact==='material'||i.impact==='major'||i.impact==='critical') out+=`<span class="nb ${i.impact}">${i.impact}</span>`;
  if(i.direction) out+=`<span class="nb ${i.direction}">${i.direction}</span>`;
  return out;
}
const newsImg=i=>i.articleImage||i.image;

/* [logo] SYM ▲1.14% · Source · 2h ago [MATERIAL][BEARISH] / two-line title */
function newsRow(i,{sym=true,thumb=true}={}){
  NEWS_BY_ID.set(i.id,i);
  const b=newsBadges(i);
  const pic=thumb?newsImg(i):i.articleImage;
  return `<div class="nrow">
    ${pic?`<span class="nthumb" data-nstock="${esc(i.mint)}"><img src="${esc(imgSrc(pic))}" alt="" onerror="this.parentElement.remove()"></span>`:''}
    <span class="ngrow" data-nid="${esc(i.id)}">
      <span class="nmeta">${sym?`<b class="nsym" data-nstock="${esc(i.mint)}">${esc(i.symbol)}${i.change24h!=null?` <span class="${fmt.cls(i.change24h)}">${fmt.arrow(i.change24h,2)}</span>`:''}</b><span class="faint">·</span>`:''}<span>${esc(i.source)}</span><span class="faint">·</span><span>${fmt.ago(i.publishedAt)} ago</span>${b?`<span class="nbs">${b}</span>`:''}</span>
      <span class="ntitle">${esc(i.title)}</span>
    </span></div>`;
}

function newsLead(i){
  NEWS_BY_ID.set(i.id,i);
  const b=newsBadges(i);
  return `<div class="nlead" data-nid="${esc(i.id)}">
    <img src="${esc(imgSrc(i.articleImage))}" alt="" onerror="this.closest('.nlead').classList.add('nopic')">
    <div class="nmeta" style="margin-top:10px"><b class="nsym" data-nstock="${esc(i.mint)}">${esc(i.symbol)}${i.change24h!=null?` <span class="${fmt.cls(i.change24h)}">${fmt.arrow(i.change24h,2)}</span>`:''}</b><span class="faint">·</span><span>${esc(i.source)}</span><span class="faint">·</span><span>${fmt.ago(i.publishedAt)} ago</span>${b?`<span class="nbs">${b}</span>`:''}</div>
    <div class="nleadtitle">${esc(i.title)}</div></div>`;
}

function bindNews(scope){
  scope.querySelectorAll('[data-nid]').forEach(e=>e.onclick=ev=>{ ev.stopPropagation(); const i=NEWS_BY_ID.get(e.dataset.nid); if(i) articleSheet(i); });
  scope.querySelectorAll('[data-nstock]').forEach(e=>e.onclick=ev=>{ ev.stopPropagation(); push(state.mode==='ape'?'floor':'stock',{mint:e.dataset.nstock}); });
}

/* The article lives on the publisher's site — the app opens it in Safari Reader without leaving. */
function articleSheet(i){
  openSheet(`<div class="grab"></div>
    <div class="sheet-title"><div style="display:flex;align-items:center;gap:10px">${logo({symbol:i.symbol,logo:i.image},28)}<div><div class="h3">${esc(i.symbol)}</div><div class="sub">${esc(i.source)} · ${fmt.ago(i.publishedAt)} ago</div></div></div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>
    <div style="display:flex;flex-direction:column;gap:12px">
      ${newsBadges(i)?`<div class="nbs">${newsBadges(i)}</div>`:''}
      <div class="h2" style="line-height:27px;text-wrap:balance">${esc(i.title)}</div>
      ${i.articleImage?`<img src="${esc(imgSrc(i.articleImage))}" alt="" style="width:100%;max-height:200px;object-fit:cover;border-radius:14px;display:block" onerror="this.remove()">`:''}
      ${i.summary?`<div style="font-size:15px;line-height:22px;color:var(--muted)">${esc(i.summary)}</div>`:''}
      <button class="btn ghost" id="read">Read on ${esc(i.source)} ↗</button>
      <div style="font-size:12px;color:var(--faint);text-align:center;line-height:16px">In the app this opens in Safari Reader — you stay inside ApeMe.</div>
    </div>
    <div style="flex:1;min-height:12px"></div>
    <button class="btn buy" id="trade">Trade ${esc(i.symbol)}</button>`,w=>{
    w.querySelector('#read').onclick=()=>window.open(i.url,'_blank','noopener');
    w.querySelector('#trade').onclick=()=>{ w.close(); const s=state.stocksByMint[i.mint];
      push(state.mode==='ape'?'floor':'stock',{mint:i.mint});
      if(s) setTimeout(()=>buyFlow('stock',s,s),360); };
  });
}

/* ---- insights: the brokerage half of the stock page ---- */
const SESSION_LABEL2={pre:'Pre-market',open:'Market open',post:'After hours',closed:'Closed'};

/* The comparison as a card, not a grey run-on line: is the US market open, what does the real
   share cost there, and am I better or worse off here. Tinted by the answer so the verdict reads
   before the words do. Pre-IPO has no Nasdaq listing, so there is no card at all. */
function nasdaqCard(ins){
  const n=ins&&ins.nasdaq; if(!n||n.last==null) return '';
  const open=ins.market&&ins.market.session==='open', p=ins.premiumVsLastPct;
  const tint = p==null?'var(--muted)' : p>1?'var(--amber)' : p<-1?'var(--green)' : 'var(--muted)';
  const fill = p==null?'var(--surface)' : p>1?'var(--amberT)' : p<-1?'var(--greenT)' : 'var(--surface)';
  const target = open?'on Nasdaq':"Nasdaq's last close";
  const verdict = p==null ? (open?'Trading alongside Nasdaq':'Nasdaq is shut — we trade 24/7')
    : Math.abs(p)<0.5 ? `Same price as ${target} right now`
    : p>0 ? `${p.toFixed(2)}% more expensive here than ${target}`
          : `${Math.abs(p).toFixed(2)}% cheaper here than ${target}`;
  return `<div style="margin-top:14px;padding:12px 14px;border-radius:14px;background:${fill};border:1px solid ${tint.replace('var(--','var(--')}22">
    <div style="display:flex;align-items:center;gap:7px">
      <span style="width:7px;height:7px;border-radius:999px;background:${open?'var(--green)':'var(--faint)'};${open?'animation:nqpulse 1.1s ease-in-out infinite':''}"></span>
      <span style="font-size:11px;font-weight:700;letter-spacing:.07em;color:${open?'var(--green)':'var(--muted)'}">${open?'NASDAQ OPEN':'NASDAQ CLOSED'}</span>
      <span style="flex:1"></span>
      <span class="mono" style="font-size:13px;font-weight:600;color:var(--muted);white-space:nowrap">${open?'Real share':'Last close'} ${fmt.usd(n.last)}</span>
    </div>
    <div style="margin-top:8px;font-size:15px;font-weight:600;letter-spacing:-.01em;color:${tint}">${verdict}</div>
    ${open?'':`<div style="margin-top:4px;font-size:12px;color:var(--faint);line-height:16px">The US market is shut. ApeMe trades 24/7 — you don't have to wait for the bell.</div>`}
  </div>`;
}

/* The 52-week range, said out loud: a bar plus one sentence, no vocabulary. */
function yearRange(ins,s){
  const st=ins?.stats; if(!st||st.low52w==null||st.high52w==null||st.high52w<=st.low52w||s.priceUsd==null) return '';
  const at=Math.max(0,Math.min(100,(s.priceUsd-st.low52w)/(st.high52w-st.low52w)*100));
  const where=at>=80?'Near its 12-month high.':at<=20?'Near its 12-month low.':at>=55?'In the upper half of its year.':at<=45?'In the lower half of its year.':'Right in the middle of its year.';
  return `<div><div class="sect">Past 12 months</div><div class="kcard pad" style="display:flex;flex-direction:column;gap:12px">
    <div class="rbar"><span class="rdot" style="left:${at.toFixed(1)}%"></span></div>
    <div class="mono" style="display:flex;justify-content:space-between;font-size:12px;color:var(--muted)"><span>${fmt.usd(st.low52w)} low</span><span>${fmt.usd(st.high52w)} high</span></div>
    <div class="sub" style="color:var(--ink);font-weight:600">${where}</div></div></div>`;
}

/* Our own market — the one thing no brokerage can show them. The depth ladder turns "very large
   orders move the price" into the actual number at each size. */
function tradingHere(s,depth){
  const levels=(depth&&depth.levels)||[];
  const notable=levels.find(l=>l.usd>=1000&&(l.impactPct||0)>1);
  const tint=l=>l.impactPct==null?'var(--faint)':l.impactPct>3?'var(--red)':l.impactPct>1?'var(--amber)':'var(--ink)';
  const txt=l=>l.impactPct==null?'—':(l.impactPct<0.01?'0%':l.impactPct.toFixed(2)+'%');
  const sentence=notable
    ? `This pool is thin — a ${fmt.big(notable.usd)} order moves the price ${notable.impactPct.toFixed(2)}%.`
    : 'Small orders fill at the price above. Very large ones move it.';
  return `<div><div class="sect">Trading here today</div><div class="kcard pad" style="display:flex;flex-direction:column;gap:14px">
    <div style="display:flex;justify-content:space-between;font-size:15px"><span class="muted">Traded</span><b class="mono">${fmt.big(s.stockVol24hUsd)}</b></div>
    <div style="display:flex;justify-content:space-between;font-size:15px"><span class="muted">In the pool</span><b class="mono">${fmt.big(s.liquidityUsd)}</b></div>
    ${splitBar(s.buys24h,s.sells24h,'buys','sells')}
    ${levels.length?`<div style="height:1px;background:var(--line)"></div>
      <div><div style="font-size:12px;font-weight:600;color:var(--faint);margin-bottom:8px">What it costs to buy</div>
      <div style="display:flex;gap:8px">${levels.map(l=>`<div class="mono" style="flex:1;text-align:center;padding:8px 0;border-radius:10px;background:var(--surface2)">
        <div style="font-size:12px;font-weight:600;color:var(--muted)">${fmt.big(l.usd)}</div>
        <div style="font-size:13px;font-weight:700;margin-top:3px;color:${tint(l)}">${txt(l)}</div></div>`).join('')}</div></div>`:''}
    <div class="sub" style="line-height:18px;color:${notable?'var(--amber)':'var(--muted)'}">${sentence}</div></div></div>`;
}

/* Dividends are real here: Backed reinvests them and the token balance grows. Never a bare yield. */
function dividendCard(ins){
  const d=ins?.dividends; if(!d||d.mechanism!=='rebase') return '';
  const grown=d.growthSinceLaunchPct>0;
  return `<div><div class="sect">Dividends</div><div class="kcard pad" style="display:flex;flex-direction:column;gap:6px">
    <div style="font-size:15px;font-weight:600">Paid as extra tokens</div>
    <div class="sub" style="line-height:19px">${grown
      ? `You don't collect anything — your balance just grows. It's up <b style="color:var(--green)">${d.growthSinceLaunchPct.toFixed(2)}%</b> since this token launched.`
      : `Reinvested into your balance automatically, no action needed. Nothing paid out yet.`}</div></div></div>`;
}

const shortDate=d=>d?new Date(d+'T00:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric'}):'';
const coName=ins=>(ins?.company?.name||'').replace(/\s+(Corp|Corporation|Inc|Inc\.|plc|Ltd|Co)\.?$/i,'')||ins?.ticker||'';

/* A date on the calendar, not a warning — and only once it's close enough to act on. */
function earningsNote(ins){
  const e=ins?.earnings; if(!e||e.inDays==null||e.inDays>14||e.inDays<0) return '';
  return `<div class="pad" style="margin-top:14px"><div class="calnote">
    <div style="font-size:15px;font-weight:600">${esc(coName(ins))} reports results in ${e.inDays} day${e.inDays===1?'':'s'}</div>
    <div class="sub" style="margin-top:3px;line-height:18px">${shortDate(e.date)}${e.when==='after close'?', after Nasdaq closes':e.when?', '+esc(e.when):''}. Prices usually move hard — and we're open when other apps aren't.</div></div></div>`;
}

function marketRow(ins,s){ return ''; }

/* The analyst numbers still exist — they just live in About, where reference material belongs. */
function investorRows(ins){
  const st=ins?.stats; if(!st) return '';
  const rows=[];
  if(st.marketCapUsd!=null) rows.push(kv('Market cap',fmt.big(st.marketCapUsd)));
  rows.push(kv('P/E (TTM)',st.peTtm!=null?st.peTtm.toFixed(2):'—'));
  if(st.epsTtm!=null) rows.push(kv('Earnings per share',fmt.usd(st.epsTtm)));
  const e=ins.earnings;
  if(e&&e.date) rows.push(kv('Next earnings',`${shortDate(e.date)}${e.when?' · '+esc(e.when):''}`));
  return rows.length?`<div><div class="sect">For investors</div><div class="kcard">${rows.join('')}</div></div>`:'';
}

function aboutCards(s,ins){
  const c=ins?.company, rows=[];
  if(c){
    if(c.name) rows.push(kv('Company',esc(c.name)));
    if(c.sector) rows.push(kv('Sector',esc(c.sector)));
    if(c.exchange) rows.push(kv('Exchange',esc(c.exchange)));
    if(c.ipo) rows.push(kv('IPO',new Date(c.ipo+'T00:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'})));
    if(c.website) rows.push(kv('Website',`<button data-web="${esc(c.website)}" style="color:var(--ink);font-weight:600">${esc(c.website.replace(/^https?:\/\//,'').replace(/\/$/,''))} ↗</button>`));
  }
  const iss={prestocks:'PreStocks',xstocks:'xStocks',backpack:'Backpack'}[s.issuer]||s.issuer;
  return `<div class="stack" style="padding-top:20px">
    ${rows.length?`<div><div class="sect">Company</div><div class="kcard">${rows.join('')}</div></div>`:''}
    ${investorRows(ins)}
    <div><div class="sect">On chain</div><div class="kcard">${kv('Issued by',esc(iss))}${kv('Trades in','USD')}${kv('Mint address',`<button style="display:inline-flex;gap:6px;align-items:center;color:var(--ink);font-weight:600" id="cpm">${fmt.short(s.mint)} ${I.copy}</button>`)}</div></div>
  </div>`;
}

/* ---- news list, paged with ?before=<publishedAt> ---- */
async function paintNewsList(mount,path,symbol){
  mount.innerHTML=`<div class="pad" style="padding-top:8px">${'<div class="skel" style="height:66px;margin-top:14px"></div>'.repeat(3)}</div>`;
  let items;
  try{ items=(await api(`${path}limit=5`,60000)).items||[]; }
  catch(e){ mount.innerHTML=`<div class="pad" style="padding-top:18px"><div class="errbar">Couldn't load the news.</div></div>`; return; }
  if(!mount.isConnected) return;
  if(!items.length){ mount.innerHTML=`<div class="empty" style="margin-top:20px"><b>No news yet for ${esc(symbol)}</b><span class="sub">Headlines land here within 20 minutes of publication.</span></div>`; return; }
  const render=()=>{
    const [first,...rest]=items;
    const lead=first.articleImage?newsLead(first):'';
    mount.innerHTML=`<div class="pad" style="padding-top:4px">${lead}<div class="nlist">${(lead?rest:items).map(i=>newsRow(i,{sym:false,thumb:false})).join('')}</div>
      ${items.length>=5?`<button class="btn ghost" id="more" style="width:100%;margin-top:16px">More headlines</button>`:''}</div>`;
    bindNews(mount);
    const more=mount.querySelector('#more');
    if(more) more.onclick=async()=>{ more.textContent='Loading…';
      try{ const d=await api(`${path}limit=20&before=${items[items.length-1].publishedAt}`,60000);
        const add=(d.items||[]).filter(x=>!items.some(y=>y.id===x.id));
        if(!add.length){ more.textContent='That’s all for now'; more.disabled=true; return; }
        items=items.concat(add); render();
      }catch(e){ more.textContent='Try again'; } };
  };
  render();
}

/* Watching something is the clearest thing a user ever tells us about what they care about, so
   once the list has anything in it, it leads and Home opens there. Empty, it sits at the back. */
function investTabOrder(){
  return state.watch.length ? ['watch','preipo','movers','news','explore']
                            : ['preipo','movers','news','explore','watch'];
}
function investTabsHtml(){
  const L={preipo:'Pre-IPO',movers:'Movers',news:'News',explore:'Explore',watch:'Watchlist'};
  return investTabOrder().map((k,i)=>`<button data-ht="${k}"${i?'':' class="on"'}>${L[k]}</button>`).join('');
}
