const assert = require('node:assert/strict');
const {parseCard} = require('./moment.js');
const card = {v:1,name:'Имя',lyric:'Строка',theme:'rose',tracks:[1,2,3].map(n=>({v:1,title:'Трек '+n,artists:['Артист'],seconds:0,note:'',lyric:''}))};
assert.equal(parseCard(card).tracks.length,3);
for(const change of [{tracks:card.tracks.slice(1)},{tracks:[card.tracks[0],card.tracks[0],card.tracks[2]]},{theme:'javascript:alert(1)'},{name:''},{lyric:'x'.repeat(151)}]) assert.throws(()=>parseCard({...card,...change}));
assert.equal(parseCard({...card,name:'<script>alert(1)</script>'}).name,'<script>alert(1)</script>'); // Rendered exclusively with textContent.
console.log('Music card parser checks passed');
