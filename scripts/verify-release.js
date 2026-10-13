// Static release verification only: does not connect to services or import workflows.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '..');
const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
const walk = dir => fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.isDirectory() ? walk(path.join(dir,e.name)) : [path.join(dir,e.name)]);
const files = walk(path.join(root,'workflows')).filter(f => f.endsWith('.json') && !f.endsWith('manifest.json'));
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
let codeCount=0, expressionCount=0;
for (const file of files) {
  const w = JSON.parse(fs.readFileSync(file,'utf8'));
  check(typeof w.name === 'string' && Array.isArray(w.nodes) && typeof w.connections === 'object', `${file}: import shape`);
  check(w.active === false && Object.keys(w.pinData || {}).length === 0, `${file}: inactive and no pinned data`);
  check(!w.id && !w.versionId && !w.settings.errorWorkflow, `${file}: local workflow binding`);
  const names = new Set(w.nodes.map(n=>n.name));
  check(names.size === w.nodes.length, `${file}: duplicate node name`);
  check(new Set(w.nodes.map(n=>n.id)).size === w.nodes.length, `${file}: duplicate node ID`);
  for (const [source,outputs] of Object.entries(w.connections)) {
    check(names.has(source), `${file}: missing connection source ${source}`);
    for(const branches of Object.values(outputs)) for(const branch of branches) for(const edge of branch) check(names.has(edge.node), `${file}: missing target ${edge.node}`);
  }
  for (const n of w.nodes) {
    check(!n.credentials && !n.webhookId, `${file}: private binding in ${n.name}`);
    check(typeof n.typeVersion === 'number' && n.position.length === 2, `${file}: node metadata ${n.name}`);
    if (n.parameters.jsCode) {
      try { new AsyncFunction(n.parameters.jsCode); codeCount++; } catch(e) {failures.push(`${file}: Code syntax ${n.name}: ${e.message}`);}
    }
    const inspect = (value, parameterPath = "") => {
      if (typeof value === 'string') {
        const postgresReplacement = n.type === 'n8n-nodes-base.postgres' && n.typeVersion >= 2.5 && parameterPath === 'options.queryReplacement';
        // Installed Postgres v2.7 uses rawReplacements.replace(/^=+/, '') before resolving arrays.
        check(!value.startsWith('=={{') || postgresReplacement, `${file}: malformed expression prefix ${n.name}`);
        if (postgresReplacement && value.startsWith('=={{')) value = '=' + value.replace(/^=+/, '');
        for (const match of value.matchAll(/\$\(['"]([^'"]+)['"]\)/g)) check(names.has(match[1]), `${file}: absent expression node ${match[1]}`);
        if(value.startsWith('={{') && value.trim().endsWith('}}')) {
          try { new Function('return ('+value.trim().slice(3,-2)+');'); expressionCount++; } catch(e) {failures.push(`${file}: expression syntax ${n.name}: ${e.message}`);}
        }
      } else if (value && typeof value==='object') Object.entries(value).forEach(([key,child])=>inspect(child, parameterPath ? parameterPath+'.'+key : key));
    };
    inspect(n.parameters);
  }
  const raw=fs.readFileSync(file,'utf8');
  check(!/graph\.facebook\.com\/v[\d.]+\/\d+\/messages/.test(raw),`${file}: Meta account identifier`);
  check(!/"credentials"\s*:|"access_token"\s*:|Bearer\s+[A-Za-z0-9._-]{20,}/i.test(raw),`${file}: credential/token content`);
}
const manifest=JSON.parse(fs.readFileSync(path.join(root,'workflows/manifest.json'),'utf8'));
for(const item of [...manifest.workflows, ...(manifest.optional_workflows || [])]) {
  const content=fs.readFileSync(path.join(root,'workflows',item.file));
  check(crypto.createHash('sha256').update(content).digest('hex')===item.sha256,`Manifest hash: ${item.file}`);
}
let links=0;
for(const file of [path.join(root,'README.md'),...walk(path.join(root,'docs')).filter(f=>f.endsWith('.md'))]) {
  const content=fs.readFileSync(file,'utf8').replace(/```[\s\S]*?```/g,'');
  for(const match of content.matchAll(/!?\[[^\]]*\]\(([^)]+)\)/g)) {
    let target=match[1].trim().replace(/^<|>$/g,'').split('#')[0];
    if(!target || /^(https?:|mailto:)/.test(target)) continue;
    target=target.replace(/\s+".*"$/,'');
    check(fs.existsSync(path.resolve(path.dirname(file),decodeURIComponent(target))),`${file}: broken link ${target}`);
    links++;
  }
}
console.log(JSON.stringify({result:failures.length?'FAIL':'PASS',workflow_files:files.length,code_nodes_compiled:codeCount,expressions_compiled:expressionCount,local_links_checked:links,failures},null,2));
process.exitCode=failures.length?1:0;
