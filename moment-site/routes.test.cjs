const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
async function page(path, fail=false) {
 const nodes={}; const context={URL,console,location:{pathname:path,hash:''},window:{addEventListener(){}},document:{getElementById(id){return nodes[id]??=( {hidden:true,textContent:'',href:''});}},fetch:async url=>({ok:!fail,json:async()=>({v:1,title:'Трек',artists:['Артист'],seconds:45,note:'',lyric:'Строка'})})};
 vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/moment.js','utf8'),context);
 await new Promise(r=>setImmediate(r));return nodes;
}
(async()=>{
 const m=await page('/m/abcdefghijklmnop');assert.equal(m.title.textContent,'Трек');assert.match(m.app.href,/^viora:\/\/moment#/);assert.equal(m.error.hidden,true);
 const c=await page('/c/abcdefghijklmnopqrstuvwxyz123456');assert.match(c.app.href,/^viora:\/\/chat\?invite=/);
 const bad=await page('/m/abcdefghijklmnop',true);assert.equal(bad.error.hidden,false);
 console.log('3 short-link/invite page checks PASS');
})();
