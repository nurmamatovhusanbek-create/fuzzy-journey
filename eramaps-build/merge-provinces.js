const fs=require('fs'), topojson=require('topojson-client'), topoServer=require('topojson-server'), d3geo=require('d3-geo'), pc=require('polygon-clipping');
function rewind(geom){if(!geom)return geom;const polys=geom.type==='Polygon'?[geom.coordinates]:geom.coordinates;for(const poly of polys){if(d3geo.geoArea({type:'Polygon',coordinates:poly})>2*Math.PI){for(const ring of poly)ring.reverse();}}return geom;}
const M=process.argv[2], THRESH=parseFloat(process.argv[3]||'1e-4'), MAXDIST=15*Math.PI/180;
const topo=JSON.parse(fs.readFileSync(M+'/provinces.topojson'));
const fc=topojson.feature(topo,topo.objects.countries);
const F={}, area={}, nb={}, nat={}, prop={};
for(const f of fc.features){const p=f.properties; F[f.id]=f; area[f.id]=d3geo.geoArea(f); nb[f.id]=(p.nb||[]).slice(); nat[f.id]=p.nation; prop[f.id]={name:p.name,nation:p.nation,nationName:p.nationName,lat:p.lat,lon:p.lon};}
const ids=Object.keys(F);
const natCount={}; ids.forEach(i=>natCount[nat[i]]=(natCount[nat[i]]||0)+1);
function gc(a,b){if(a==null||b==null||a[0]==null||b[0]==null)return Infinity;const R=Math.PI/180,dl=(b[0]-a[0])*R,la1=a[1]*R,la2=b[1]*R;const x=Math.sin((la2-la1)/2)**2+Math.cos(la1)*Math.cos(la2)*Math.sin(dl/2)**2;return 2*Math.asin(Math.min(1,Math.sqrt(x)));}
const parent={}; ids.forEach(i=>parent[i]=i);
function find(x){while(parent[x]!==x){parent[x]=parent[parent[x]];x=parent[x];}return x;}
let merged=0,droppedN=0; const dropped=new Set();
const small=ids.filter(i=>area[i]<THRESH).sort((a,b)=>area[a]-area[b]);
for(const p of small){
  if(find(p)!==p)continue;
  if(natCount[nat[p]]<=1)continue;
  const cands=nb[p].filter(q=>F[q]&&!dropped.has(find(q))&&nat[find(q)]===nat[p]&&find(q)!==find(p));
  let target=null;
  if(cands.length){cands.sort((a,b)=>area[find(b)]-area[find(a)]);target=find(cands[0]);}
  else{let bd=MAXDIST,bt=null;for(const q of ids){if(q===p||dropped.has(find(q))||nat[q]!==nat[p]||find(q)===find(p))continue;if(Math.abs(prop[p].lon-prop[q].lon)>40||Math.abs(prop[p].lat-prop[q].lat)>40)continue;const d=gc([prop[p].lon,prop[p].lat],[prop[q].lon,prop[q].lat]);if(d<bd){bd=d;bt=find(q);}}if(bt)target=bt;}
  if(target){parent[p]=target;merged++;natCount[nat[p]]--;}
  else if(area[p]===0){dropped.add(p);droppedN++;natCount[nat[p]]--;}
}
// group members by root
const groups={}; for(const id of ids){if(dropped.has(id))continue;const r=find(id);if(dropped.has(r))continue;(groups[r]=groups[r]||[]).push(id);}
function toMP(geom){if(!geom)return null;return geom.type==='Polygon'?[geom.coordinates]:geom.coordinates;}
const outFeats=[];
for(const r in groups){
  const members=groups[r];
  let geom;
  if(members.length===1){geom=F[r].geometry;}      // untouched → keep ORIGINAL geometry (no null/degenerate corruption)
  else{
    let acc=toMP(F[r].geometry)||[];
    for(const m of members){if(m===r)continue;const mp=toMP(F[m].geometry);if(!mp||!mp.length)continue;try{acc=pc.union(acc.length?acc:mp, mp);}catch(e){/*keep acc*/}}
    geom = acc&&acc.length?rewind({type:'MultiPolygon',coordinates:acc}):F[r].geometry;
  }
  outFeats.push({type:'Feature',id:r,properties:Object.assign({},prop[r]),geometry:geom});
}
// encode to topojson (preserve degenerate geometry; quantize)
const out=topoServer.topology({countries:{type:'FeatureCollection',features:outFeats}},1e5);
// recompute nb (land adjacency) from new topology
const geoms=out.objects.countries.geometries;
const nbIdx=topojson.neighbors(geoms);
geoms.forEach((g,i)=>{g.properties=g.properties||{};g.properties.nb=nbIdx[i].map(j=>geoms[j].id).filter(Boolean);});
fs.writeFileSync('/tmp/provinces.topojson', JSON.stringify(out));
console.log(`before=${ids.length} merged=${merged} dropped=${droppedN} after=${outFeats.length}`);
