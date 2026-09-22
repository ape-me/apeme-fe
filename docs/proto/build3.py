import re
head=open('v3-head.html').read(); screens=open('v3-screens.html').read()
data=open('data-lines.js').read(); bd=open('block-data.js').read(); bw=open('block-ws.js').read(); bs=open('block-sheet.js').read()
screens=screens.replace('/*__BLOCK_ACCOUNT__*/',open('block-account.js').read())
out=head.replace('/*__DATA__*/',data.strip()).replace('/*__BLOCK_DATA__*/',bd.strip()).replace('/*__BLOCK_WS__*/',bw.strip()).replace('/*__BLOCK_SHEET__*/',bs.strip())+screens
open('apeme-v3.html','w').write(out); open('apeme-prototype.html','w').write(out)
js=re.search(r'<script>(.*)</script>',out,re.S).group(1); open('/tmp/v3check.js','w').write(js.replace("document.getElementById('phone')","({querySelectorAll(){return[]},querySelector(){return null}})"))
print(len(out)//1024,'KB')
import shutil; shutil.copy('apeme-v3.html','/private/tmp/claude-501/-Users-iamdsv-Library-Application-Support-Claude-scratch-workspaces-c9c6341b-c6c2-46cc-a16e-e7b992790241-66cf6808-7f2e-49b2-b072-648f1808a3d7-scratch-2026-09-19-f602c8/9e923dcb-944a-4433-8694-818e1d3df1fa/scratchpad/proto/apeme-v3.html'); shutil.copy('apeme-prototype.html','/private/tmp/claude-501/-Users-iamdsv-Library-Application-Support-Claude-scratch-workspaces-c9c6341b-c6c2-46cc-a16e-e7b992790241-66cf6808-7f2e-49b2-b072-648f1808a3d7-scratch-2026-09-19-f602c8/9e923dcb-944a-4433-8694-818e1d3df1fa/scratchpad/proto/apeme-prototype.html')
for d in ['/private/tmp/claude-501/-Users-iamdsv-apeme-fe/9e923dcb-944a-4433-8694-818e1d3df1fa/scratchpad/proto/','/Users/iamdsv/Downloads/']:
    try:
        shutil.copy('apeme-v3.html', d+'apeme-v3.html'); shutil.copy('apeme-prototype.html', d+('ApeMe-prototype.html' if 'Downloads' in d else 'apeme-prototype.html'))
    except Exception as e: print('skip', d, e)
shutil.copy('apeme-prototype.html','/Users/iamdsv/apeme-fe/docs/ApeMe-prototype.html')
