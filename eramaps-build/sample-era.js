const fs=require('fs'), path=require('path');
const topojson=require('topojson-client'), d3geo=require('d3-geo');
const eraId=process.argv[2]||'ww1', year=parseInt(process.argv[3]||'1914',10);
const MAPS=process.argv[4];
const NORM={
 'United Kingdom of Great Britain and Ireland':'British Empire','United Kingdom':'British Empire','Great Britain':'British Empire',
 'Austro-Hungarian Empire':'Austria-Hungary','Kingfom of Italy':'Kingdom of Italy','Kingdom of Italy':'Kingdom of Italy'};
function canonName(name,sub){let k=(sub&&sub!==name)?sub:name;return NORM[k]||k;}
function slug(s){return String(s).toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'');}
const provTopo=JSON.parse(fs.readFileSync(path.join(MAPS,'provinces.topojson')));
const eraTopo=JSON.parse(fs.readFileSync(path.join(MAPS,eraId+'.topojson')));
const provFC=topojson.feature(provTopo,provTopo.objects.countries);
const eraFC=topojson.feature(eraTopo,eraTopo.objects.countries);
const eraFeats=eraFC.features.map(f=>{const disp=NORM[(f.properties.subjecto&&f.properties.subjecto!==f.properties.name)?f.properties.subjecto:f.properties.name]||((f.properties.subjecto&&f.properties.subjecto!==f.properties.name)?f.properties.subjecto:f.properties.name);return{feat:f,key:canonName(f.properties.name,f.properties.subjecto),disp};});
const prov={},nationDisp={},counts={},loc={};let assigned=0,total=0;
for(const pf of provFC.features){total++;const lon=pf.properties.lon,lat=pf.properties.lat;loc[pf.id]=[lon,lat];if(lon==null||lat==null)continue;
 for(const ef of eraFeats){if(d3geo.geoContains(ef.feat,[lon,lat])){const sl=slug(ef.key);prov[pf.id]=sl;nationDisp[sl]=ef.disp;counts[sl]=(counts[sl]||0)+1;assigned++;break;}}}
// neighbor-majority fill (land adjacency)
const nbOf={};for(const pf of provFC.features)nbOf[pf.id]=Array.isArray(pf.properties.nb)?pf.properties.nb:[];
for(let pass=0;pass<5;pass++){const add={};for(const pf of provFC.features){const id=pf.id;if(prov[id])continue;const t={};for(const nb of nbOf[id]){const v=prov[nb];if(v)t[v]=(t[v]||0)+1;}let b=null,bc=0;for(const k in t)if(t[k]>bc){bc=t[k];b=k;}if(b)add[id]=b;}let n=0;for(const id in add){prov[id]=add[id];counts[add[id]]=(counts[add[id]]||0)+1;assigned++;n++;}if(!n)break;}
// island fix: nearest assigned province within ~15deg great-circle
function gc(a,b){const R=Math.PI/180;const dl=(b[0]-a[0])*R,la1=a[1]*R,la2=b[1]*R;const x=Math.sin((la2-la1)/2)**2+Math.cos(la1)*Math.cos(la2)*Math.sin(dl/2)**2;return 2*Math.asin(Math.min(1,Math.sqrt(x)))/R;}
const assignedIds=Object.keys(prov);
for(const pf of provFC.features){const id=pf.id;if(prov[id])continue;const p=loc[id];if(!p||p[0]==null)continue;let best=null,bd=15;for(const aid of assignedIds){const d=gc(p,loc[aid]);if(d<bd){bd=d;best=prov[aid];}}if(best){prov[id]=best;counts[best]=(counts[best]||0)+1;assigned++;}}
const OV=require('/tmp/overrides.js');const nations={};for(const sl in nationDisp){nations[sl]={name:nationDisp[sl]};if(OV[sl]){if(OV[sl].color)nations[sl].color=OV[sl].color;if(OV[sl].cap)nations[sl].cap=OV[sl].cap;}}
fs.writeFileSync('/tmp/era_'+eraId+'.json',JSON.stringify({id:eraId,year,prov,nations}));
console.log(`coverage: ${assigned}/${total} (${(100*assigned/total).toFixed(1)}%)`);
console.log(`distinct nations: ${Object.keys(nations).length}`);
const ranked=Object.entries(counts).sort((a,b)=>b[1]-a[1]);
for(const [sl,c] of ranked.slice(0,18))console.log(`  ${String(c).padStart(4)}  ${nationDisp[sl]}`);
console.log('singletons:',ranked.filter(([,c])=>c===1).length);
