const assert = require('node:assert/strict');
const {parseMoment} = require('./moment.js');
const encode = m => '#' + encodeURIComponent(JSON.stringify(m));
const m = {v:1,title:'Песня & #',artists:['Первый','Second'],seconds:34,note:'Для тебя 100%'};
assert.deepEqual(parseMoment(encode(m)), m);
assert.throws(() => parseMoment('#%'));
assert.throws(() => parseMoment(encode({...m, seconds:-1})));
assert.equal(parseMoment(encode({...m,source:'javascript:alert(1)'})).source,null);
assert.equal(parseMoment(''),null);
console.log('5 moment parser checks PASS');

assert.equal(parseMoment(encode({...m,replyTo:{...m,note:''}})).replyTo.title,m.title);
assert.throws(() => parseMoment(encode({...m,replyTo:{...m,replyTo:m}})));
assert.throws(() => parseMoment(encode({...m,replyTo:'invalid'})));
console.log('3 reply parser checks PASS');
