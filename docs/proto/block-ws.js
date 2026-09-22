function ws(room,onMsg){
 const screen=phone.querySelector('.screen');let connection,retry,heartbeat,stopped=false;
 const status=(text,live=false)=>{if(screen){screen.dataset.wsState=text;screen.dataset.wsLive=String(live)}if(screen?.isConnected)screen.querySelectorAll('[data-ws-status]').forEach(el=>el.innerHTML=`<i class="dots ${live?'live':''}"></i>${text}`)};
 const connect=()=>{if(stopped||!screen?.isConnected)return;status('Connecting');try{connection=new WebSocket(WSB+room);connection.onopen=()=>{status('Live',true);heartbeat=setInterval(()=>{if(connection.readyState===1)connection.send('ping')},25000)};connection.onmessage=e=>{if(!screen.isConnected)return;try{const frames=JSON.parse(e.data);(Array.isArray(frames)?frames:[frames]).forEach(m=>{if(m.t==='trade'||m.t==='token'||m.t==='news')onMsg(m)})}catch(e){}};connection.onerror=()=>status('Reconnecting');connection.onclose=()=>{clearInterval(heartbeat);if(!stopped&&screen.isConnected){status('Reconnecting');retry=setTimeout(connect,3000)}}}catch(e){status('Offline')}};
 const handle={close(){stopped=true;clearTimeout(retry);clearInterval(heartbeat);connection?.close()}};sockets.push(handle);connect();return handle;
}
/* ============ sheets ============ */
