import { createRequire as __cdwCreateRequire } from 'node:module'; const require = __cdwCreateRequire(import.meta.url);
var t=class{now(){let e=new Date;return{iso:e.toISOString(),epoch:e.getTime()}}},o=class{epoch;constructor(e){this.epoch=e}now(){return{iso:new Date(this.epoch).toISOString(),epoch:this.epoch}}advance(e){this.epoch+=e}};export{t as a,o as b};
