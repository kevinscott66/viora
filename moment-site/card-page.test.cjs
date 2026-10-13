const assert=require('node:assert/strict'), vm=require('node:vm'), fs=require('node:fs');
async function page(fail=false){
 const nodes={}; const node=()=>({hidden:true,textContent:'',href:'',children:[],classList:{add(value){this.value=value}},appendChild(child){this.children.push(child)}});
 const payload={v:1,name:'<img src=x onerror=alert(1)>',lyric:'Строка',theme:'ocean',tracks:[1,2,3].map(i=>({v:1,title:'Трек '+i,artists:['Артист'],seconds:0,note:'',lyric:''}))};
 const context={URL,console,location:{pathname:'/p/abcdefghijklmnop',hash:''},window:{addEventListener(){}},document:{getElementById(id){return nodes[id]??=node()},querySelector(id){return nodes[id]??=node()},createElement(){return node()}},fetch:async()=>({ok:!fail,json:async()=>payload})};
 vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/moment.js','utf8'),context); await new Promise(r=>setImmediate(r));return nodes;
}
(async()=>{const p=await page();assert.equal(p.title.textContent,'<img src=x onerror=alert(1)>');assert.equal(p['card-tracks'].children.length,3);assert.match(p['card-tracks'].children[0].href,/^viora:\/\/moment#/);assert.equal(p.app.href,'viora://card?id=abcdefghijklmnop');assert.equal(p['.card'].classList.value,'theme-ocean');assert.equal(p.error.hidden,true);const revoked=await page(true);assert.equal(revoked.error.hidden,false);assert.equal(revoked.app,undefined);console.log('Music card page and revoked link checks PASS')})();
