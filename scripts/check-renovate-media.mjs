// Run: node scripts/check-renovate-media.mjs /path/to/renovate/lib/node_modules/renovate
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const dist = resolve(process.argv[2], 'dist');
const load = (path) => import(pathToFileURL(resolve(dist, path)));
const { extractPackageFile } = await load('modules/manager/docker-compose/extract.js');
const { applyPackageRules } = await load('util/package-rules/index.js');
const { RegExpVersioningApi } = await load('modules/versioning/regex/index.js');
const { api: docker } = await load('modules/versioning/docker/index.js');
const { filterVersions } = await load('workers/repository/process/lookup/filter.js');
const config = JSON.parse(await readFile(new URL('../renovate.json', import.meta.url)));
const file = 'hosts/alucard/media-stack/docker-compose.yml';
const { deps } = extractPackageFile(await readFile(new URL(`../${file}`, import.meta.url), 'utf8'), file, {});
const cases = [
  ['qbittorrent', '5.2.4_v2.0.15-ls479', '5.2.4_v2.0.15-ls480', '5.2.5_v2.0.15-ls481'],
  ['sonarr', '4.0.20.3014-ls326', '4.0.20.3014-ls327', '4.0.21.3015-ls328'],
  ['radarr', '6.4.4.10685-ls319', '6.4.4.10685-ls320', '6.4.5.10686-ls321'],
  ['prowlarr', '2.6.5.5623-ls162', '2.6.5.5623-ls163', '2.6.6.5624-ls164'],
  ['bazarr', 'v1.6.2-ls366', 'v1.6.2-ls367', 'v1.6.3-ls368'],
  ['sabnzbd', '5.1.3-ls275', '5.1.3-ls276', '5.1.4-ls277'],
];
for (const [name, current, nextBuild, nextRelease] of cases) {
  const dep = deps.find((dep) => dep.packageName === `lscr.io/linuxserver/${name}`);
  assert.ok(dep, name);
  assert.match(dep.currentDigest, /^sha256:[a-f0-9]{64}$/);
  const ruled = await applyPackageRules({ ...dep, packageRules: config.packageRules });
  assert.ok(ruled.versioning?.startsWith('regex:'), name);
  const api = new RegExpVersioningApi(ruled.versioning.slice(6));
  assert.ok(api.isVersion(dep.currentValue) && api.isStable(dep.currentValue), dep.currentValue);
  assert.ok(api.isVersion(current) && api.isStable(current), current);
  // Demonstrate the default Docker versioning failure, not just our replacement.
  assert.ok(!docker.isVersion(current) || !docker.isCompatible(nextBuild, current));
  const candidates = [nextBuild, nextRelease];
  if (name === 'qbittorrent') candidates.push('5.2.4_v2.1.0-ls480');
  else if (['sonarr', 'radarr', 'prowlarr'].includes(name)) {
    candidates.push(current.replace(/\.(\d+)-ls/, (_, n) => `.${Number(n) + 1}-ls`));
  }
  const invalid = ['latest', 'develop', `develop-${nextBuild}`, `${nextRelease}-develop`];
  for (const version of invalid) assert.equal(api.isVersion(version), false, version);
  const incompatible = name === 'qbittorrent' ? ['5.3.0_v1.2.20-ls999', '5.3.0_v3.0.0-ls999'] : [];
  for (const version of incompatible) assert.equal(api.isCompatible(version, current), false, version);
  const releases = [current, ...candidates, ...invalid, ...incompatible]
    .filter((version) => api.isCompatible(version, current)).map((version) => ({ version }));
  const upgrades = filterVersions({ ...ruled, ignoreUnstable: true }, current, undefined, releases, api);
  assert.deepEqual(upgrades.map(({ version }) => version), candidates);
  for (const version of candidates) assert.equal(api.getNewValue({ currentValue: current, currentVersion: current, newVersion: version }), version);
  console.log(`${name}: recognized ${current}; accepted ${candidates.join(', ')}`);
}
const unrelated = await applyPackageRules({ datasource: 'docker', packageName: 'lscr.io/linuxserver/other', packageRules: config.packageRules });
assert.equal(unrelated.versioning, undefined);
