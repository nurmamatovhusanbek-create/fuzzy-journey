const fs=require('fs'), path=require('path'), topojson=require('topojson-client'), d3geo=require('d3-geo');
const eraId=process.argv[2], year=parseInt(process.argv[3],10), MAPS=process.argv[4];
const EB=path.join(MAPS,'..','eramaps-build');
const COL_TECH={ancient:0,roman:0,medieval:0,mongol:0,timurid:0,discovery:0.4,gunpowder:0.8,napoleonic:1.0,victorian:1.3,ww1:1.6,ww2:2.0,coldwar:2.2};
const NORM={'United Kingdom of Great Britain and Ireland':'British Empire','United Kingdom':'British Empire','Great Britain':'British Empire','Austro-Hungarian Empire':'Austria-Hungary','Kingfom of Italy':'Kingdom of Italy'};
function canon(name,sub){let k=(sub&&sub!==name)?sub:name;return NORM[k]||k;}
function slug(s){return String(s).toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'');}
let OV={}; try{OV=require(path.join(EB,eraId+'-overrides.js'))||{};}catch(e){}
const provTopo=JSON.parse(fs.readFileSync(path.join(MAPS,'provinces.topojson')));
const eraTopo=JSON.parse(fs.readFileSync(path.join(MAPS,eraId+'.topojson')));
const provFC=topojson.feature(provTopo,provTopo.objects.countries);
const eraFC=topojson.feature(eraTopo,eraTopo.objects.countries);
function rewindFeat(f){if(!f.geometry)return;const polys=f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates;for(const poly of polys){if(d3geo.geoArea({type:'Polygon',coordinates:poly})>2*Math.PI){for(const r of poly)r.reverse();}}}
eraFC.features.forEach(rewindFeat);
const eraFeats=eraFC.features.map(f=>{const disp=(f.properties.subjecto&&f.properties.subjecto!==f.properties.name)?f.properties.subjecto:f.properties.name;return{feat:f,key:canon(f.properties.name,f.properties.subjecto),disp:NORM[disp]||disp};});
const P={},nb={},lat={},lon={},natName={},owner={};
for(const pf of provFC.features){P[pf.id]=pf;nb[pf.id]=pf.properties.nb||[];lat[pf.id]=pf.properties.lat;lon[pf.id]=pf.properties.lon;}
const nations={};
for(const pf of provFC.features){const lo=lon[pf.id],la=lat[pf.id];if(lo==null)continue;
  for(const ef of eraFeats){if(d3geo.geoContains(ef.feat,[lo,la])){const sl=slug(ef.key);owner[pf.id]=sl;natName[sl]=ef.disp;break;}}}
// conservative hole-fill: uncovered province enclosed by a single nation
for(let pass=0;pass<2;pass++){const add={};
  for(const id in P){ if(owner[id])continue; const cnt={}; let ownedNb=0,uncNb=0;
    for(const q of nb[id]){ if(owner[q]){cnt[owner[q]]=(cnt[owner[q]]||0)+1;ownedNb++;} else uncNb++; }
    if(!ownedNb)continue; let top=null,tc=0; for(const k in cnt)if(cnt[k]>tc){tc=cnt[k];top=k;}
    if(top && tc>=Math.ceil(0.6*ownedNb) && uncNb<=1) add[id]=top;
  }
  for(const id in add)owner[id]=add[id];
}
// classify
const prov={}, discoverable=[];
for(const id in P){ if(owner[id]){prov[id]=owner[id];continue;} if(lat[id]!=null && lat[id]<-60)continue; /*Antarctica inert*/ discoverable.push(id); }
// build nations (name + optional override color/cap)
const natsOut={};
for(const sl in natName){ natsOut[sl]={name:natName[sl]}; if(OV[sl]){if(OV[sl].color)natsOut[sl].color=OV[sl].color; if(OV[sl].cap)natsOut[sl].cap=OV[sl].cap;} }
const out={id:eraId,year,prov,nations:natsOut,discoverable,colonize:{tech:COL_TECH[eraId]||0}};
fs.writeFileSync('/tmp/era_'+eraId+'.json',JSON.stringify(out));
console.log(`${eraId.padEnd(10)} owned=${Object.keys(prov).length} discover=${discoverable.length} nations=${Object.keys(natsOut).length} tech=${out.colonize.tech}`);
