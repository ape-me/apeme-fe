/* ============ accounts · wallet · trading · invites (mocked to the BE contract) ============ */
const MOCK_ADDR='CPG6kq2JvY5nQ8hx3ZtW4mLr9sVbNfE1cDaGyH7pMjYi', MOCK_ADDR2='9wUxq1F3mS8bT2rKd7Yn4LhV6pQe5AcZ1jGoR8tN3kBv';
const MOCK={
  me:{ userId:'did:privy:cmubkkkyc010i0bl27oykij6x', handle:null, avatarUrl:null, status:'active', createdAt:1790015019,
    wallets:[{address:MOCK_ADDR,chain:'solana',hdIndex:0,label:'Main',isDefault:true},{address:MOCK_ADDR2,chain:'solana',hdIndex:1,label:'Degen',isDefault:false}],
    settings:{slippageBps:100,quickBuyUsd:[10,25,50,100],quickSellPct:[25,50,100],priority:'normal',confirmBeforeTrade:true,hideDust:false},
    referral:{code:'R4DFAQ',invitesLeft:5,earnedUsd:0.24} },
  referrals:{ code:'R4DFAQ', link:'https://apeme.fun/i/R4DFAQ', invitesLeft:5, earnedUsd:0.24, claimableUsd:0.24,
    referred:[{userId:'did:privy:a1',handle:'sam',joinedAt:1790012000,volumeUsd:120.5},{userId:'did:privy:b2',handle:null,joinedAt:1790013000,volumeUsd:0}], payouts:[] },
  wallets:{ [MOCK_ADDR]:{ address:MOCK_ADDR, cashUsd:500, solUsd:0, costUsd:123.20, pnlUsd:-0.64, pendingSwaps:0,
      holdings:[ {mint:'EPjF',kind:'cash',symbol:'USDC',name:'Cash',amount:500,raw:'500000000',decimals:6,priceUsd:1,valueUsd:500},
        {mint:'Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh',kind:'stock',symbol:'NVDAX',name:'NVIDIA',image:'https://www.stonkfun.xyz/api/asset/quote-logo/Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh',amount:0.5249,raw:'52490000',decimals:8,priceUsd:227.58,valueUsd:119.46,change24h:1.91,costUsd:118.20,pnlUsd:1.26,pnlPct:1.07},
        {mint:'9xhMStAAufkH5jA5nevaGy6M9fCsQ74BZnsXyo93DkfA',kind:'meme',symbol:'ACORNELIUS',name:'acornelius',image:'https://metadata.j7tracker.io/images/40e647c75d0b46fc',quoteSymbol:'OPENAI',amount:1240000,raw:'1240000000000',decimals:6,priceUsd:0.0000025,valueUsd:3.10,change24h:-12.4,costUsd:5,pnlUsd:-1.9,pnlPct:-38} ],
      activity:[ {sig:'4oETxJB7q2mW8dLp1sK9vN3cR6tY5bH0aZfG7jXe5Vmn4',ts:Math.floor(Date.now()/1000)-300,type:'buy',status:'confirmed',source:'apeme',symbol:'NVDAX',image:'https://www.stonkfun.xyz/api/asset/quote-logo/Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh',stockSymbol:null,amount:0.5249,usd:1.00,feeUsd:0.01},
        {sig:'2bQz7kLm9pRt4vXn1cWy6sHd8eJf3aGu5oPi0rTl2Kx',ts:Math.floor(Date.now()/1000)-1500,type:'deposit',status:'confirmed',source:'chain',symbol:'USDC',image:'',usd:500.00,from:'7ov6HkP2rQm8Lz3bWx1nYc5dVe9sFt4aGj6uNi0pR8oEh'},
        {sig:null,ts:Math.floor(Date.now()/1000)-3600,type:'buy',status:'failed',source:'apeme',symbol:'ACORNELIUS',image:'https://metadata.j7tracker.io/images/40e647c75d0b46fc',stockSymbol:'OPENAI',amount:0,usd:5,error:'slippage'} ] },
    [MOCK_ADDR2]:{ address:MOCK_ADDR2, cashUsd:0, solUsd:0, pnlUsd:0, pendingSwaps:0, holdings:[{mint:'EPjF',kind:'cash',symbol:'USDC',name:'Cash',amount:0,raw:'0',decimals:6,priceUsd:1,valueUsd:0}], activity:[] } }
};
const acct={
  active(){ return LS('apeme.active')||MOCK_ADDR; },
  setActive(a){ LSW('apeme.active',a); },
  label(a){ return MOCK.me.wallets.find(w=>w.address===(a||acct.active()))?.label||'Wallet'; },
  wallet(a){ const w=MOCK.wallets[a||acct.active()]; w.totalUsd=w.holdings.reduce((s,h)=>s+(h.valueUsd||0),0); w.cashUsd=w.holdings[0].valueUsd; return w; },
  settings(){ return MOCK.me.settings; },
  holds(mint){ return acct.wallet().holdings.find(h=>h.mint===mint&&h.kind!=='cash'); },
  /* quote to the BE shape */
  quote({side,item,usd,pct,holding,priority}){
    const price=item.priceUsd||holding?.priceUsd||1; const fee=(side==='buy'?usd:(holding.valueUsd*pct/100))*0.01; const rent=side==='buy'&&!acct.holds(item.mint)?0.25:0;
    const outUsd=side==='buy'?usd-fee:(holding.valueUsd*pct/100)-fee;
    return { requestId:'8f0c3a2e-'+Math.random().toString(16).slice(2,8), side, symbol:item.symbol, inUsd:side==='buy'?usd:holding.valueUsd*pct/100, outUsd,
      outQty:side==='buy'?outUsd/price:null, fee:{usd:fee,bps:100}, rent:{usd:rent}, totalChargeUsd:fee+rent, gas:{paidBy:'apeme',priority}, slippageBps:acct.settings().slippageBps,
      premiumPct:item.premiumPct??0.09, markUsd:item.markUsd||price*0.999, expiresAt:Math.floor(Date.now()/1000)+60 };
  },
  /* apply a confirmed trade to the mock wallet */
  settle(q,item,holding){
    const w=acct.wallet(); const price=item.priceUsd||holding?.priceUsd||1;
    if(q.side==='buy'){ w.holdings[0].valueUsd=+(w.holdings[0].valueUsd-q.inUsd-q.totalChargeUsd).toFixed(2); w.holdings[0].amount=w.holdings[0].valueUsd;
      let h=acct.holds(item.mint); if(!h){ h={mint:item.mint,kind:item.kind==='meme'||item.quoteMint?'meme':'stock',symbol:item.symbol,name:item.name,image:item.logo||item.image,quoteSymbol:item.quoteMint?state.stocksByMint[item.quoteMint]?.symbol:undefined,amount:0,raw:'0',decimals:item.quoteMint?6:8,priceUsd:price,valueUsd:0,change24h:item.change24h,costUsd:0,pnlUsd:0,pnlPct:0}; w.holdings.push(h); }
      h.amount+=q.outQty; h.valueUsd=+(h.amount*price).toFixed(2); h.costUsd=(h.costUsd||0)+q.inUsd; h.raw=String(Math.round(h.amount*10**h.decimals));
      w.activity.unshift({sig:'5Kd'+Math.random().toString(36).slice(2,12)+'…',ts:Math.floor(Date.now()/1000),type:'buy',status:'confirmed',source:'apeme',symbol:item.symbol,image:item.logo||item.image,stockSymbol:h.quoteSymbol,amount:q.outQty,usd:q.inUsd,feeUsd:q.fee.usd,rentUsd:q.rent.usd});
    } else { const part=holding.amount*q.pct/100; holding.amount-=part; holding.valueUsd=+(holding.amount*price).toFixed(2); holding.raw=String(Math.round(holding.amount*10**holding.decimals));
      if(holding.amount<=1e-9) w.holdings.splice(w.holdings.indexOf(holding),1);
      w.holdings[0].valueUsd=+(w.holdings[0].valueUsd+q.outUsd).toFixed(2); w.holdings[0].amount=w.holdings[0].valueUsd;
      w.activity.unshift({sig:'3xQ'+Math.random().toString(36).slice(2,12)+'…',ts:Math.floor(Date.now()/1000),type:'sell',status:'confirmed',source:'apeme',symbol:holding.symbol,image:holding.image,stockSymbol:holding.quoteSymbol,amount:part,usd:q.outUsd,feeUsd:q.fee.usd}); }
  }
};
auth.address=()=>state.user?acct.active():null;

/* ---- pseudo-QR (deterministic pattern; the app renders a real one) ---- */
function qrSvg(seed,size=180){ let h=0; for(const c of seed) h=(h*31+c.charCodeAt(0))>>>0; const n=29, cell=size/n; let rects=''; const rnd=()=>{ h^=h<<13; h>>>=0; h^=h>>>17; h^=h<<5; h>>>=0; return h/4294967296; };
  const finder=(x,y)=>`<rect x="${x*cell}" y="${y*cell}" width="${7*cell}" height="${7*cell}" fill="#000"/><rect x="${(x+1)*cell}" y="${(y+1)*cell}" width="${5*cell}" height="${5*cell}" fill="#fff"/><rect x="${(x+2)*cell}" y="${(y+2)*cell}" width="${3*cell}" height="${3*cell}" fill="#000"/>`;
  for(let y=0;y<n;y++) for(let x=0;x<n;x++){ const inF=(x<8&&y<8)||(x>=n-8&&y<8)||(x<8&&y>=n-8); if(!inF&&rnd()<0.45) rects+=`<rect x="${x*cell}" y="${y*cell}" width="${cell}" height="${cell}" fill="#000"/>`; }
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges"><rect width="${size}" height="${size}" fill="#fff"/>${rects}${finder(0,0)}${finder(n-7,0)}${finder(0,n-7)}</svg>`; }

/* ---- deposit (Receive) ---- */
const ICO={ dep:'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v12"/><path d="m6 10 6 6 6-6"/><path d="M4 20h16"/></svg>', wd:'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20V8"/><path d="m6 14 6-6 6 6"/><path d="M4 4h16"/></svg>', buy:'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14"/><path d="M5 12h14"/></svg>', sell:'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/></svg>', share:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v13"/><path d="m7 8 5-5 5 5"/><path d="M5 21h14"/></svg>', sol:'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M5 16.5h13.5l-2.5 2.5H2.5zM5 5h13.5L16 7.5H2.5zM19 10.75H5.5L8 13.25h13.5z"/></svg>' };
function depositSheet(){
  const addr=acct.active(); if(!addr) return;
  const w=openSheet(`<div class="grab"></div><div class="sheet-title"><div class="h2">Deposit</div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>
    <div style="display:flex;justify-content:center"><span class="pill sm" style="gap:8px">${ICO.sol} Solana · USDC</span></div>
    <div style="display:flex;justify-content:center"><div style="position:relative;padding:16px;background:#fff;border-radius:20px">${qrSvg(addr,196)}<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center"><div style="width:44px;height:44px;border-radius:12px;background:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:15px;color:#0a0b0d;letter-spacing:-.04em">Ape</div></div></div></div>
    <button id="addr" style="display:flex;align-items:center;justify-content:center;gap:8px;font-size:15px;font-weight:600" class="mono">${fmt.short(addr)} <span class="muted">${I.copy}</span></button>
    <div class="sub" style="text-align:center;padding:0 12px">Send USDC on the Solana network to this address. Other networks or tokens may be lost.</div>
    <div class="btns"><button class="btn ghost" id="cp">Copy address</button><button class="btn ghost" id="sh">${ICO.share} Share</button></div>
    <div class="cc" style="justify-content:center"><span class="spin"></span> Watching for your deposit…</div>`,w=>{ w.querySelector('#addr').onclick=()=>copy(addr); w.querySelector('#cp').onclick=()=>copy(addr); w.querySelector('#sh').onclick=()=>toast('Share sheet opens'); });
  w.querySelector('.sheet').classList.add('tall');
  setTimeout(()=>{ if(!w.isConnected) return; const wal=acct.wallet(addr); wal.holdings[0].valueUsd=+(wal.holdings[0].valueUsd+20).toFixed(2); wal.holdings[0].amount=wal.holdings[0].valueUsd; wal.activity.unshift({sig:'2bQ'+Math.random().toString(36).slice(2,10)+'…',ts:Math.floor(Date.now()/1000),type:'deposit',status:'confirmed',source:'chain',symbol:'USDC',image:'',usd:20,from:'7ov6HkP2rQm8Lz3bWx1nYc5dVe9sFt4aGj6uNi0pR8oEh'}); w.close(); toast('Received $20.00'); if(state.tab==='portfolio'&&state.stack.length===1) render(false); },8000);
}
/* ---- transaction detail (success screen + activity tap) ---- */
function txSheet(a){
  const title={buy:`Bought ${fmt.qty(a.amount,a.symbol)}`,sell:`Sold ${fmt.qty(a.amount,a.symbol)}`,deposit:`Received ${fmt.usd(a.usd)}`,withdraw:`Sent ${fmt.usd(a.usd)}`}[a.type]||a.type;
  const ok=a.status==='confirmed', pend=a.status==='pending';
  const w=openSheet(`<div class="grab"></div><div class="sheet-title"><div class="h2">${a.type==='deposit'?'Deposit':a.type==='withdraw'?'Withdrawal':'Trade'}</div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>
    <div style="display:flex;flex-direction:column;align-items:center;gap:14px;padding:10px 0 6px;text-align:center"><div class="check" style="${ok?'':pend?'background:var(--surface2);color:var(--muted)':'background:var(--red);color:#fff'}">${ok?I.check:pend?'<span class="spin" style="border-top-color:var(--ink);width:20px;height:20px"></span>':I.x}</div><div class="h1" style="text-wrap:balance">${title}</div>${a.usd!=null&&(a.type==='buy'||a.type==='sell')?`<div class="sub mono">${a.type==='buy'?'for':'for'} ${fmt.usd(a.usd)}${a.stockSymbol?' · on '+esc(a.stockSymbol):''}</div>`:''}</div>
    <div class="kcard">${kv('Date',new Date(a.ts*1000).toLocaleString('en-US',{month:'short',day:'numeric',year:'numeric',hour:'numeric',minute:'2-digit'}))}${kv('Status',`<span class="${ok?'up':pend?'muted':'dn'}">${ok?'Succeeded':pend?'Pending':'Failed'}</span>`)}${a.error?kv('Reason',esc(a.error)):''}${a.feeUsd!=null?kv('Fee',fmt.usd(a.feeUsd)):''}${a.rentUsd?kv('One-time network fee',fmt.usd(a.rentUsd)):''}${a.from?kv('From',fmt.short(a.from)):''}${kv('Network','Solana')}</div>
    <div style="flex:1"></div>
    ${a.sig?`<button class="btn white" id="scan">View on Solscan</button>`:''}`,w=>{ w.querySelector('#scan')?.addEventListener('click',()=>toast('Opens solscan.io/tx/'+a.sig.slice(0,6)+'…')); });
  w.querySelector('.sheet').classList.add('tall'); return w;
}

/* ---- buy / sell ---- */
function buyFlow(kind,item,stock){ tradeSheet({side:'buy',item,stock}); }
function sellFlow(mint){ const h=acct.holds(mint); if(!h){ toast("You don't hold any yet"); return; } tradeSheet({side:'sell',item:{mint:h.mint,symbol:h.symbol,priceUsd:h.priceUsd,logo:h.image,kind:h.kind},holding:h}); }
function tradeSheet({side,item,stock,holding}){
  const isStock=holding?holding.kind==='stock':!item.quoteMint; const verb=side==='sell'?'Sell':isStock?'Buy':'Ape'; const st=acct.settings(); const cash=acct.wallet().cashUsd;
  let amount='', pct=null, priority=st.priority||'normal', q=null, phase='idle', timer=null, review=false;
  const w=openSheet('<div class="grab"></div>'); const sheet=w.querySelector('.sheet'); sheet.classList.add('tall');
  const set=(html,mount)=>{ sheet.innerHTML='<div class="grab"></div>'+html; mount?.(); };
  const usd=()=>Number(amount)||0;
  const youGet=()=>!q?'—':side==='sell'?fmt.usd(q.outUsd):fmt.qty(q.outQty,item.symbol);
  const requote=()=>{ clearTimeout(timer); q=null; if(side==='buy'?usd()<=0:pct==null){ phase='idle'; paint(); return; } if(side==='buy'&&usd()>cash){ phase='insufficient'; paint(); return; } phase='quoting'; paint();
    timer=setTimeout(()=>{ q=acct.quote({side,item,usd:usd(),pct,holding,priority}); if(side==='sell') q.pct=pct; phase=(side==='buy'&&q.inUsd+q.totalChargeUsd>cash)?'insufficient':'ready'; paint(); },180); };
  const header=()=>`<div class="sheet-title"><div style="display:flex;align-items:center;gap:10px">${isStock?logo({symbol:item.symbol,logo:item.logo||item.image},28):avatar({symbol:item.symbol,image:item.logo||item.image},'m')}<div><div class="h3">${verb} ${esc(item.symbol)}</div><div class="sub mono">${side==='sell'?`You hold ${fmt.qty(holding.amount,item.symbol)} · ${fmt.usd(holding.valueUsd)}`:`Cash ${fmt.usd(cash)}`}</div></div></div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>`;
  const details=()=>`<div style="display:flex;flex-direction:column;gap:8px">
    ${isStock&&q?`<div class="sub mono"><span>${stock?.issuer==='prestocks'?'Fair value':'Nasdaq'} ${fmt.usd(q.markUsd)}</span> <span class="faint">·</span> <span style="color:var(--ink)">here ${fmt.pct(q.premiumPct,2)}</span></div>`:''}
    <div style="display:flex;align-items:center;justify-content:space-between"><span class="sub mono">Fee ${fmt.usd(q?.fee.usd||0)} · Gas free</span><button class="pill xs" id="prio" style="background:var(--surface2);color:var(--ink);font-weight:600">⚡ ${priority[0].toUpperCase()+priority.slice(1)}</button></div>
    ${q&&q.rent.usd>0?`<div class="sub mono">One-time network fee ${fmt.usd(q.rent.usd)} to hold ${esc(item.symbol)}</div>`:''}
    ${q&&side==='buy'&&q.premiumPct>5?`<div class="notice">You're paying ${q.premiumPct.toFixed(1)}% over the ${stock?.issuer==='prestocks'?'fair value':'Nasdaq price'}.</div>`:''}</div>`;
  const primary=()=>{ const m={insufficient:['Deposit to buy','white'],quoting:['Getting quote…','off'],signing:['Signing…','off'],submitting:['Submitting…','off'],confirming:['Confirming…','off'],failed:['Try again','ghost'],idle:[side==='buy'?'Enter an amount':'Pick an amount','off']};
    const [l,c]=phase==='ready'?[side==='buy'?`${verb} $${amount} of ${esc(item.symbol)}`:`Sell ${pct}% of ${esc(item.symbol)}`,side==='sell'?'sell':'buy']:m[phase]; return `<button class="btn ${c==='buy'?'cta':c}" id="go" style="${c==='sell'?'background:linear-gradient(90deg,#ff5c5c,#ff8a5c);color:#fff':''}">${l}</button>`; };
  const form=()=>set(`${header()}
    <div style="display:flex;flex-direction:column;align-items:center;gap:4px;padding:8px 0 0">${side==='buy'?`<div class="amountbig"><span class="cur">$</span><span id="amt">${amount||'0'}</span></div>`:`<div class="amountbig"><span id="amt">${pct==null?'—':pct+'%'}</span></div>`}<div class="sub mono">You get ≈ ${phase==='quoting'?'…':youGet()}</div></div>
    <div class="presets">${(side==='buy'?st.quickBuyUsd:st.quickSellPct).map(v=>`<button data-p="${v}" class="${(side==='buy'?usd():pct)===v?'on':''}">${side==='buy'?'$'+v:v+'%'}</button>`).join('')}</div>
    ${details()}
    ${side==='buy'?`<div class="numpad">${['1','2','3','4','5','6','7','8','9','.','0','⌫'].map(k=>`<button data-k="${k}">${k==='⌫'?I.del:k}</button>`).join('')}</div>`:''}
    ${phase==='failed'?`<div class="errbox">Price moved. Try again.</div>`:''}
    <div style="flex:1"></div>${primary()}`,()=>{
    sheet.querySelectorAll('[data-p]').forEach(b=>b.onclick=()=>{ if(side==='buy') amount=String(b.dataset.p); else pct=Number(b.dataset.p); requote(); });
    sheet.querySelectorAll('[data-k]').forEach(b=>b.onclick=()=>{ const k=b.dataset.k; if(k==='⌫') amount=amount.slice(0,-1); else if(k==='.'){ if(!amount.includes('.')) amount=(amount||'0')+'.'; } else if(amount.length<8&&(!amount.includes('.')||amount.split('.')[1].length<2)) amount=amount==='0'?k:amount+k; requote(); });
    sheet.querySelector('#prio').onclick=()=>{ const o=['normal','fast','turbo']; priority=o[(o.indexOf(priority)+1)%3]; requote(); };
    sheet.querySelector('#go').onclick=()=>{ if(phase==='insufficient'){ w.close(); depositSheet(); } else if(phase==='failed') requote(); else if(phase==='ready'){ if(st.confirmBeforeTrade){ review=true; paint(); } else run(); } };
  });
  const reviewV=()=>set(`<div class="sheet-title"><button class="iconbtn" id="b1" aria-label="Back">${I.back}</button><div class="h3">Review</div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>
    <div class="h1" style="padding-top:6px">${side==='buy'?`${verb} $${esc(amount)} of ${esc(item.symbol)}`:`Sell ${pct}% of ${esc(item.symbol)}`}</div>
    <div class="kcard">${kv('You pay',side==='buy'?fmt.usd(q.inUsd):fmt.qty(holding.amount*pct/100,item.symbol))}${kv('You get','≈ '+youGet())}${isStock?kv(stock?.issuer==='prestocks'?'Fair value':'Nasdaq',fmt.usd(q.markUsd)):''}${kv('Fee',fmt.usd(q.fee.usd))}${q.rent.usd>0?kv('One-time network fee',fmt.usd(q.rent.usd)):''}${side==='buy'?kv('Total from cash',fmt.usd(q.inUsd+q.totalChargeUsd)):''}${kv('Gas','Free · ApeMe pays')}${kv('Slippage',(q.slippageBps/100)+'%')}${kv('Account',fmt.short(acct.active()))}</div>
    ${phase==='failed'?`<div class="errbox">Price moved. Try again.</div>`:''}
    <div style="flex:1"></div>
    ${phase==='confirming'?`<div class="btn off"><span class="spin"></span> Confirming on Solana…</div>`:phase==='signing'?`<div class="btn off">Signing…</div>`:phase==='submitting'?`<div class="btn off">Submitting…</div>`:phase==='failed'?`<button class="btn ghost" id="again">Try again</button>`:`<button class="btn ${side==='sell'?'':'cta'}" id="confirm" style="${side==='sell'?'background:linear-gradient(90deg,#ff5c5c,#ff8a5c);color:#fff':''}">Confirm</button>`}`,()=>{
    sheet.querySelector('#b1').onclick=()=>{ review=false; paint(); }; sheet.querySelector('#confirm')?.addEventListener('click',run); sheet.querySelector('#again')?.addEventListener('click',()=>{ review=false; requote(); }); });
  const done=()=>set(`<div class="sheet-title"><div class="h2">Trade</div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div>
    <div style="display:flex;flex-direction:column;align-items:center;gap:14px;padding:10px 0 6px;text-align:center"><div class="check">${I.check}</div><div class="h1" style="text-wrap:balance">${side==='buy'?`Bought ${youGet()}`:`Sold ${fmt.qty(holding.amount*pct/100,item.symbol)}`}</div><div class="sub mono">${side==='buy'?`for ${fmt.usd(q.inUsd)}`:`for ${youGet()}`}${holding?.quoteSymbol||item.quoteMint?` · on ${esc(holding?.quoteSymbol||state.stocksByMint[item.quoteMint]?.symbol||'')}`:''}</div></div>
    <div class="kcard">${kv('Date',new Date().toLocaleString('en-US',{month:'short',day:'numeric',year:'numeric',hour:'numeric',minute:'2-digit'}))}${kv('Status','<span class="up">Succeeded</span>')}${isStock?kv(stock?.issuer==='prestocks'?'Fair value':'Nasdaq',fmt.usd(q.markUsd)):''}${kv('Fee',fmt.usd(q.fee.usd))}${q.rent.usd>0?kv('One-time network fee',fmt.usd(q.rent.usd)):''}${kv('Network','Solana')}</div>
    <div style="flex:1"></div>
    <button class="btn white" id="scan">View on Solscan</button><button class="btn ghost" data-close>Done</button>`,()=>{ sheet.querySelector('#scan').onclick=()=>toast('Opens solscan.io/tx/5Kd…'); });
  const run=async()=>{ const step=(p,ms)=>new Promise(r=>{ phase=p; paint(); setTimeout(r,ms); }); await step('signing',700); await step('submitting',500); await step('confirming',1600); acct.settle(q,item,holding); phase='confirmed'; paint(); const oc=w.close; w.close=()=>{ oc(); if(state.tab==='portfolio'&&state.stack.length===1) setTimeout(()=>render(false),170); }; };
  const paint=()=>{ if(!w.isConnected) return; if(phase==='confirmed') done(); else if(review) reviewV(); else form(); };
  paint();
}

/* ---- accounts ---- */
function accountsSheet(){
  const rows=()=>MOCK.me.wallets.map(x=>{ const on=x.address===acct.active(); const bal=acct.wallet(x.address).totalUsd; return `<button class="row" data-acc="${x.address}"><span class="iconbtn" style="background:none;color:${on?'var(--ink)':'var(--faint)'}">${on?I.check:'○'}</span><div class="grow"><div class="t">${esc(x.label)} ${x.isDefault?'<span class="badge grey">Default</span>':''}</div><div class="s mono">${fmt.short(x.address)}</div></div><div class="r"><div class="px">${fmt.usd(bal)}</div></div></button>`; }).join('');
  const w=openSheet(`<div class="grab"></div><div class="sheet-title"><div class="h2">Accounts</div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div><div class="card" id="accs">${rows()}</div><button class="btn ghost" id="new">+ New account</button><div class="sub" style="color:var(--faint)">Hold a row to rename or make it the default.</div>`,w=>{
    const bind=()=>{ w.querySelectorAll('[data-acc]').forEach(b=>{ b.onclick=()=>{ acct.setActive(b.dataset.acc); w.close(); render(false); }; let t; b.onpointerdown=()=>{ t=setTimeout(()=>{ const x=MOCK.me.wallets.find(y=>y.address===b.dataset.acc); const label=prompt('Rename account',x.label); if(label){ x.label=label; w.querySelector('#accs').innerHTML=rows(); bind(); } },600); }; b.onpointerup=b.onpointerleave=()=>clearTimeout(t); }); };
    bind(); w.querySelector('#new').onclick=()=>{ const b=w.querySelector('#new'); b.textContent='Creating…'; setTimeout(()=>{ const a='A'+Math.random().toString(36).slice(2,12)+'zQ9m'+Math.random().toString(36).slice(2,20); MOCK.me.wallets.push({address:a,chain:'solana',hdIndex:MOCK.me.wallets.length,label:'Account '+(MOCK.me.wallets.length+1),isDefault:false}); MOCK.wallets[a]={address:a,cashUsd:0,solUsd:0,pnlUsd:0,pendingSwaps:0,holdings:[{mint:'EPjF',kind:'cash',symbol:'USDC',name:'Cash',amount:0,raw:'0',decimals:6,priceUsd:1,valueUsd:0}],activity:[]}; w.querySelector('#accs').innerHTML=rows(); bind(); b.textContent='+ New account'; toast('Account created'); },900); };
  });
}

/* ---- wallet tab ---- */
SCREENS.portfolio={
  html(p,skin){ const me=MOCK.me; return `<div class="pad" style="padding-top:12px;display:flex;align-items:center;justify-content:space-between"><button id="acc" style="display:flex;align-items:center;gap:12px;text-align:left"><span class="av" style="width:44px;height:44px;font-size:16px;color:var(--ink)">${(me.handle||state.user?.label||'?')[0].toUpperCase()}</span><span><span class="sub" style="display:block">${me.handle?'@'+esc(me.handle):esc(state.user?.label||'')}</span><span class="h2" style="display:inline-flex;align-items:center;gap:4px">${esc(acct.label())} <span class="muted">${I.chev.replace('width="16"','width="14"').replace('height="16"','height="14"')}</span></span></span></button><button class="iconbtn" id="hist" aria-label="Activity">${I.port.replace('width="24"','width="18"').replace('height="24"','height="18"')}</button></div><div class="scroll"><div id="body" class="pad"></div></div>`; },
  mount(el,p,skin){
    el.querySelector('#acc').onclick=accountsSheet; const body=el.querySelector('#body'); const ape=skin==='ape'; const w=acct.wallet(); const st=acct.settings(); let tab=state._wtab||'positions';
    el.querySelector('#hist').onclick=()=>{ tab='activity'; state._wtab=tab; paint(); };
    const positions=w.holdings.filter(h=>(h.kind==='stock'||h.kind==='meme')&&(!st.hideDust||h.valueUsd>=0.01)).sort((a,b)=>b.valueUsd-a.valueUsd);
    const pnlPct=w.costUsd>0?w.pnlUsd/w.costUsd*100:null;
    const posRow=h=>`<button class="row m" ${h.kind==='meme'?`data-token="${h.mint}"`:`data-stock="${h.mint}"`}><span style="position:relative">${h.kind==='meme'?avatar(h):logo({symbol:h.symbol,logo:h.image})}<span class="badge grey" style="position:absolute;right:-6px;bottom:-4px;padding:2px 5px;font-size:9px;background:var(--surface2)">${h.kind==='meme'?'MEME':'STOCK'}</span></span><div class="grow"><div class="t"><span class="sym">${esc(h.symbol)}</span>${h.quoteSymbol?`<span class="faint" style="font-size:11px;font-weight:500">on ${esc(h.quoteSymbol)}</span>`:''}</div><div class="s mono">${fmt.qty(h.amount,h.symbol)}</div></div><div class="r"><div class="px">${fmt.usd(h.valueUsd)}</div><div class="ch ${fmt.cls(h.pnlUsd??h.change24h)}">${h.pnlUsd!=null?(h.pnlUsd>=0?'+':'−')+fmt.usd(Math.abs(h.pnlUsd)):fmt.arrow(h.change24h,1)}</div></div></button>`;
    const actTitle=a=>({buy:`Bought ${esc(a.symbol)}`,sell:`Sold ${esc(a.symbol)}`,deposit:'Received USDC',withdraw:'Sent USDC'})[a.type]||a.type;
    const actSub=a=>a.status==='failed'?`<span class="dn">Failed · ${esc(a.error||'unknown')}</span>`:a.status==='pending'?'Confirming on Solana…':a.type==='deposit'?`From ${fmt.short(a.from)}`:a.type==='withdraw'?`To ${fmt.short(a.to)}`:`${a.stockSymbol?'on '+esc(a.stockSymbol)+' · ':''}${fmt.usd(a.usd)}${a.feeUsd!=null?' · fee '+fmt.usd(a.feeUsd):''}`;
    const actAmt=a=>a.status==='failed'?'':a.type==='buy'?`<span class="up">+${fmt.qty(a.amount,a.symbol)}</span>`:a.type==='sell'?`<span>−${fmt.qty(a.amount,a.symbol)}</span>`:a.type==='deposit'?`<span class="up">+${fmt.usd(a.usd)}</span>`:`<span>−${fmt.usd(a.usd)}</span>`;
    const actIcon=a=>a.status==='failed'?`<span class="av" style="background:var(--redT);color:var(--red)">${I.x}</span>`:a.symbol==='USDC'?`<span class="av" style="background:var(--surface2);color:var(--ink)">${a.type==='deposit'?ICO.dep:ICO.wd}</span>`:avatar(a);
    const actRow=a=>`<button class="row m" data-tx="${w.activity.indexOf(a)}">${actIcon(a)}<div class="grow"><div class="t"><span class="sym">${actTitle(a)}</span></div><div class="s">${actSub(a)}</div></div><div class="r"><div class="px mono">${actAmt(a)}</div>${a.status==='pending'?'<span class="spin"></span>':''}</div></button>`;
    const dayLabel=ts=>{ const d=new Date(ts*1000), n=new Date(); const same=(x,y)=>x.toDateString()===y.toDateString(); if(same(d,n)) return 'Today'; const y=new Date(n); y.setDate(n.getDate()-1); if(same(d,y)) return 'Yesterday'; return d.toLocaleDateString('en-US',{month:'short',day:'numeric',year:d.getFullYear()!==n.getFullYear()?'numeric':undefined}); };
    const activity=()=>{ if(!w.activity.length) return '<div class="empty"><b>Nothing yet.</b><span class="sub">Your deposits and trades show up here.</span></div>'; const groups=[]; const pend=w.activity.filter(a=>a.status==='pending'); if(pend.length) groups.push(['Pending',pend]); for(const a of w.activity.filter(a=>a.status!=='pending')){ const l=dayLabel(a.ts); const g=groups.find(x=>x[0]===l); if(g) g[1].push(a); else groups.push([l,[a]]); } return groups.map(([l,items])=>`<div class="eyebrow" style="margin-top:18px">${l}</div><div class="card">${items.map(actRow).join('')}</div>`).join(''); };
    const paint=()=>{ body.innerHTML=`<div style="margin-top:8px"><div class="hero">${fmt.cents(w.totalUsd)}</div><div class="mono" style="margin-top:6px;display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600">${w.pnlUsd!=null?`<span class="${fmt.cls(w.pnlUsd)}">${(w.pnlUsd>=0?'+':'−')+fmt.usd(Math.abs(w.pnlUsd))}</span>${pnlPct!=null?`<span class="chip ${w.pnlUsd>=0?'up':'dn'} ${fmt.cls(w.pnlUsd)}" style="height:22px;padding:0 7px;border-radius:999px;display:inline-flex;align-items:center;background:var(--${w.pnlUsd>=0?'greenT':'redT'})">${fmt.arrow(pnlPct,2)}</span>`:''}`:'<span class="muted">No trades yet</span>'}</div></div>
      <div style="margin-top:18px">${actionRow([{id:'dep',label:'Deposit',icon:ICO.dep},{id:'wd',label:'Withdraw',icon:ICO.wd},{id:'buy',label:'Buy',icon:ICO.buy},{id:'sell',label:'Sell',icon:ICO.sell}])}</div>
      <div class="card pad" style="margin-top:18px;display:flex;align-items:center;justify-content:space-between;gap:12px"><div><div class="sub">Cash balance</div><div style="font-size:24px;font-weight:600;letter-spacing:-.03em;font-variant-numeric:tabular-nums;margin-top:2px">${fmt.usd(w.cashUsd)}</div></div><button class="pill acc" id="addcash">Deposit</button></div>
      <div class="tabs" style="margin-top:22px"><button data-wt="positions" class="${tab==='positions'?'on':''}">Positions</button><button data-wt="activity" class="${tab==='activity'?'on':''}">Activity</button></div>
      <div style="margin-top:6px">${tab==='positions'?(positions.length?`<div class="card">${positions.map(posRow).join('')}</div>`:'<div class="empty"><b>No positions yet.</b><span class="sub">Buy a stock or ape a meme to see it here.</span></div>'):activity()}</div>`;
      if(!ape) body.querySelectorAll('[data-token]').forEach(b=>b.removeAttribute('data-token')); bindRows(el);
      body.querySelectorAll('[data-wt]').forEach(b=>b.onclick=()=>{ tab=b.dataset.wt; state._wtab=tab; paint(); });
      body.querySelector('#addcash').onclick=depositSheet; body.querySelector('[data-act="dep"]').onclick=depositSheet; body.querySelector('[data-act="wd"]').onclick=()=>toast('Withdraw is coming soon'); body.querySelector('[data-act="buy"]').onclick=()=>root('markets'); body.querySelector('[data-act="sell"]').onclick=()=>{ if(!positions.length){ toast('Nothing to sell yet'); return; } if(positions.length===1) sellFlow(positions[0].mint); else { tab='positions'; state._wtab=tab; paint(); toast('Pick a position to sell'); } };
      body.querySelectorAll('[data-tx]').forEach(b=>b.onclick=()=>txSheet(w.activity[+b.dataset.tx]));
      /* positions in the wallet open a sell/buy chooser instead of the page */
      body.querySelectorAll('.row[data-stock],.row[data-token]').forEach(b=>{ const mint=b.dataset.stock||b.dataset.token; b.onclick=()=>{ const h=positions.find(x=>x.mint===mint); openSheet(`<div class="grab"></div><div class="sheet-title"><div style="display:flex;align-items:center;gap:10px">${h.kind==='meme'?avatar(h,'m'):logo({symbol:h.symbol,logo:h.image},28)}<div><div class="h3">${esc(h.symbol)}</div><div class="sub mono">${fmt.qty(h.amount,h.symbol)} · ${fmt.usd(h.valueUsd)}</div></div></div><button class="iconbtn" data-close aria-label="Close">${I.x}</button></div><div class="kcard">${kv('Value',fmt.usd(h.valueUsd))}${kv('Cost',h.costUsd!=null?fmt.usd(h.costUsd):'—')}${kv('P&L',h.pnlUsd!=null?`<span class="${fmt.cls(h.pnlUsd)}">${(h.pnlUsd>=0?'+':'−')+fmt.usd(Math.abs(h.pnlUsd))} (${fmt.pct(h.pnlPct,1)})</span>`:'—')}${kv('Price',fmt.usd(h.priceUsd))}</div><div class="btns"><button class="btn cta" id="b">Buy more</button><button class="btn" id="s" style="background:linear-gradient(90deg,#ff5c5c,#ff8a5c);color:#fff">Sell</button></div><button class="lnk" id="open" style="font-size:13px;text-align:center">Open ${h.kind==='meme'?'token':'stock'} page ${I.chev}</button>`,ws=>{ ws.querySelector('#b').onclick=()=>{ ws.close(); const st=state.stocksByMint[h.mint]; if(st) buyFlow('stock',st,st); else toast('Open the page to buy'); }; ws.querySelector('#s').onclick=()=>{ ws.close(); sellFlow(h.mint); }; ws.querySelector('#open').onclick=()=>{ ws.close(); if(h.kind==='meme'){ if(ape) push('token',{mint:h.mint}); else toast('Switch to Ape mode to open memes'); } else push(state.mode==='ape'?'floor':'stock',{mint:h.mint}); }; }); }; });
    };
    paint();
  }
};

/* ---- settings ---- */
SCREENS.settings={
  html(){ return `<div class="topbar"><button class="back" data-back aria-label="Back">${I.back}</button><div class="h2">Settings</div></div><div class="scroll"><div class="pad" id="body" style="display:flex;flex-direction:column;gap:22px;padding-top:8px"></div></div>`; },
  mount(el){ const st=acct.settings(); const body=el.querySelector('#body');
    const sec=(t,inner,note)=>`<div style="display:flex;flex-direction:column;gap:10px"><div class="sect" style="margin:0">${t}</div>${inner}${note?`<div class="sub">${note}</div>`:''}</div>`;
    const chips=(items,sel,key)=>`<div style="display:flex;gap:8px">${items.map(([v,l])=>`<button class="pill ${v===sel?'on':''}" data-set="${key}" data-v="${v}">${l}</button>`).join('')}</div>`;
    const edit=(vals,pre,suf,key)=>`<div style="display:flex;gap:8px;flex-wrap:wrap">${vals.map(v=>`<button class="pill" data-rm="${key}" data-v="${v}">${pre}${v}${suf} ${vals.length>1?I.x.replace('width="16"','width="12"').replace('height="16"','height="12"'):''}</button>`).join('')}${vals.length<4?`<button class="pill" data-add="${key}">+</button>`:''}</div>`;
    const tog=(t,on,key)=>`<button class="kv" data-tog="${key}" style="width:100%"><span>${t}</span><span class="switch ${on?'on':''}"></span></button>`;
    const paint=()=>{ body.innerHTML=sec('Slippage',chips([[10,'0.1%'],[50,'0.5%'],[100,'1%'],[300,'3%']],st.slippageBps,'slippageBps'))+sec('Quick buy amounts',edit(st.quickBuyUsd,'$','','quickBuyUsd'))+sec('Quick sell %',edit(st.quickSellPct,'','%','quickSellPct'))+sec('Priority fee',chips([['normal','Normal'],['fast','Fast'],['turbo','Turbo']],st.priority,'priority'),'ApeMe pays the gas.')+`<div class="kcard">${tog('Confirm before trade',st.confirmBeforeTrade,'confirmBeforeTrade')}${tog('Hide dust (< $0.01)',st.hideDust,'hideDust')}</div>`;
      body.querySelectorAll('[data-set]').forEach(b=>b.onclick=()=>{ st[b.dataset.set]=isNaN(b.dataset.v)?b.dataset.v:Number(b.dataset.v); paint(); toast('Saved'); });
      body.querySelectorAll('[data-rm]').forEach(b=>b.onclick=()=>{ const k=b.dataset.rm; if(st[k].length>1){ st[k]=st[k].filter(v=>v!==Number(b.dataset.v)); paint(); toast('Saved'); } });
      body.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{ const k=b.dataset.add; const v=Number(prompt(k==='quickBuyUsd'?'Amount in $':'Percent')); if(v>0&&!st[k].includes(v)){ st[k]=[...st[k],v].sort((a,b)=>a-b); paint(); toast('Saved'); } });
      body.querySelectorAll('[data-tog]').forEach(b=>b.onclick=()=>{ st[b.dataset.tog]=!st[b.dataset.tog]; paint(); toast('Saved'); }); };
    paint(); }
};

/* ---- invite & earn ---- */
SCREENS.referrals={
  html(){ const r=MOCK.referrals; return `<div class="topbar"><button class="back" data-back aria-label="Back">${I.back}</button><div class="h2">Invite & earn</div></div><div class="scroll"><div class="pad" style="display:flex;flex-direction:column;gap:22px;padding-top:8px">
    <div class="feature"><div class="hero" style="letter-spacing:.1em">${r.code}</div><div class="sub">${r.invitesLeft} invites left</div><div style="font-size:15px">You earn 20% of ApeMe's fee on every trade they make, forever.</div><div style="display:flex;gap:8px"><button class="pill" id="share">↗ Share link</button><button class="pill" id="cc">Copy code</button></div></div>
    <div style="display:flex;flex-direction:column;gap:10px"><div class="sect" style="margin:0">Earnings</div><div class="kcard">${kv('Earned',fmt.usd(r.earnedUsd))}${kv('Claimable',fmt.usd(r.claimableUsd))}</div><button class="btn ${r.claimableUsd>=1?'white':'off'}" id="claim">Claim ${fmt.usd(r.claimableUsd)}</button>${r.claimableUsd<1?'<div class="sub" style="color:var(--faint)">Claim from $1.</div>':''}</div>
    <div style="display:flex;flex-direction:column;gap:10px"><div class="sect" style="margin:0">People you invited</div>${r.referred.length?`<div class="kcard">${r.referred.map(u=>kv(u.handle?'@'+esc(u.handle):fmt.short(u.userId),fmt.usd(u.volumeUsd)+' traded')).join('')}</div>`:'<div class="sub">Nobody yet. Share your code.</div>'}</div></div></div>`; },
  mount(el){ el.querySelector('#share').onclick=()=>copy(MOCK.referrals.link); el.querySelector('#cc').onclick=()=>copy(MOCK.referrals.code); el.querySelector('#claim').onclick=()=>toast(MOCK.referrals.claimableUsd>=1?'Sent to your wallet':'Claim from $1'); }
};

/* ---- you (profile) ---- */
SCREENS.you={
  html(p,skin){ const ape=skin==='ape'; const me=MOCK.me; const addr=acct.active(); return `<div class="pad" style="padding-top:16px"><div class="h1">You</div></div><div class="scroll"><div class="pad" style="padding-top:8px">
    <button class="row" id="handle" style="min-height:72px"><span class="av l" style="font-size:20px;color:var(--ink)">${(me.handle||state.user?.label||'?')[0].toUpperCase()}</span><div class="grow"><div class="t" style="font-size:17px">${me.handle?'@'+esc(me.handle):'Pick a handle'}</div><div class="s">${esc(state.user?.label||'')} · since ${new Date(me.createdAt*1000).toLocaleDateString('en-US',{month:'short',year:'numeric'})}</div></div><span class="muted">✎</span></button>
    <button class="feature" data-go="referrals" style="margin:12px 0 8px;gap:8px"><div style="display:flex;justify-content:space-between;align-items:center"><span class="h3">Invite & earn</span>${I.chev}</div><div style="display:flex;justify-content:space-between;align-items:baseline"><span class="mono" style="font-size:22px;font-weight:600;letter-spacing:.1em">${me.referral.code}</span><span class="sub mono">${me.referral.invitesLeft} left · earned ${fmt.usd(me.referral.earnedUsd)}</span></div><div class="sub">20% of ApeMe's fee on every trade they make, forever.</div></button>
    <div class="card">
      <button class="row" data-modeswitch><span class="iconbtn">${ape?'🔥':'📈'}</span><div class="grow"><div class="t">Ape mode</div><div class="s">${ape?'Floors, kings and the live tape':'Off · stocks and fair values'}</div></div><span class="switch ${ape?'on':''}"></span></button>
      <button class="row" data-go="settings"><span class="iconbtn">⚙</span><div class="grow"><div class="t">Trading settings</div><div class="s">Slippage, quick amounts, priority, confirmations</div></div>${I.chev}</button>
      <button class="row" id="addr"><span class="iconbtn">${I.copy}</span><div class="grow"><div class="t">Wallet address</div><div class="s mono">${fmt.short(addr)}</div></div>${I.chev}</button>
      <button class="row" id="reset"><span class="iconbtn">↺</span><div class="grow"><div class="t">Show onboarding again</div><div class="s">Three slides and the mode question</div></div>${I.chev}</button>
      <button class="row" id="out"><span class="iconbtn">⇥</span><div class="grow"><div class="t">Sign out</div><div class="s">${esc(state.user?.label||'Signed in')}</div></div>${I.chev}</button></div></div></div>`; },
  mount(el){ bindMode(el);
    el.querySelectorAll('[data-go]').forEach(b=>b.onclick=()=>push(b.dataset.go));
    el.querySelector('#handle').onclick=()=>{ const h=(prompt('Your handle (a–z, 0–9, _)',MOCK.me.handle||'')||'').toLowerCase().trim(); if(!h) return; if(!/^[a-z0-9_]{3,20}$/.test(h)){ toast('3–20 characters: letters, numbers, underscore'); return; } if(h==='joey'){ toast('That handle is taken'); return; } MOCK.me.handle=h; render(false); toast('@'+h+' is yours'); };
    el.querySelector('#addr').onclick=()=>copy(acct.active());
    el.querySelector('#reset').onclick=()=>dialog('Show onboarding again?','You\'ll pick a mode again. Nothing else changes.',[{label:'Cancel'},{label:'Show it',cls:'white',onClick(){ state.onboarded=false; LSW('apeme.onboarded','0'); boot(); }}]);
    el.querySelector('#out').onclick=()=>dialog('Sign out?','Your wallet stays with your account. Sign back in any time.',[{label:'Cancel'},{label:'Sign out',cls:'danger',onClick(){ auth.signOut(); }}]);
  }
};
