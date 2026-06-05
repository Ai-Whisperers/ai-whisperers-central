#!/usr/bin/env node
// sync-workflows.js — pushes latest .github/workflows/* to all client repos
// Run from ci-cd repo after any workflow change

const fs = require('fs');
const path = require('path');

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const ORG = 'Ai-Whisperers';
const WORKFLOWS_DIR = path.join(__dirname, '..', '.github', 'workflows');

// Repos to skip (platform repos that manage their own workflows)
const SKIP_REPOS = [
  'ci-cd',
  'paragu-ai-builder',
  'Vete',
  'AI-Whisperers',
  'aiw-infra',
  'priorities',
  '.github',
  'repo-template',
  'ai-whisperers-packages',
  'solstein-v2',
  'ma-research-pipeline',
];

async function main() {
  // Get all repos in org
  const res = await fetch(
    `https://api.github.com/orgs/${ORG}/repos?per_page=100&type=private`,
    { headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' } }
  );
  const repos = await res.json();

  // Read local workflow files
  const localWorkflows = fs.readdirSync(WORKFLOWS_DIR).filter(f => f.endsWith('.yml'));
  const localContent = {};
  for (const wf of localWorkflows) {
    localContent[wf] = fs.readFileSync(path.join(WORKFLOWS_DIR, wf), 'utf-8');
  }

  const callerWorkflows = ['ci-nextjs.yml', 'ci-python.yml', 'deploy-vps.yml', 'deploy-vps-git-pull.yml', 'security-scan.yml'];

  for (const repo of repos) {
    if (SKIP_REPOS.includes(repo.name) || repo.archived) continue;
    if (!repo.name.endsWith('-website') && !repo.name.endsWith('-comercio') &&
        !repo.name.endsWith('-advisory') && !repo.name.endsWith('-atelier') &&
        !repo.name.endsWith('-asociados') && repo.name !== 'fun4me' &&
        repo.name !== 'superspuma' && repo.name !== 'nexa-paraguay' &&
        repo.name !== 'dayah-litworks' && repo.name !== 'nudo' &&
        repo.name !== 'depiflash' && repo.name !== 'granja-cabral' &&
        repo.name !== 'de-abasto-a-casa' && repo.name !== 'polki-squad' &&
        repo.name !== 'bufete-mendez' && repo.name !== 'stoicfinch' &&
        repo.name !== 'nico-portfolio' && repo.name !== 'nexa-propiedades' &&
        repo.name !== 'base' && repo.name !== 'template-nextjs-client' &&
        repo.name !== 'clinica-duerksen' && repo.name !== 'elviajero-comercio' &&
        repo.name !== 'golden-visa-advisory' &&
        !repo.name.startsWith('magnolia-') && !repo.name.startsWith('luis-de-') &&
        !repo.name.startsWith('mantra-') && !repo.name.startsWith('cocodrilo-') &&
        !repo.name.startsWith('bichos-') &&
        !repo.name.includes('alejandro')) {
      console.log(`Skipping ${repo.name} (not a client site)`);
      continue;
    }

    console.log(`\n=== Syncing workflows to ${repo.name} ===`);

    // Check if repo already has a deploy.yml
    for (const wfName of callerWorkflows) {
      const path = `.github/workflows/${wfName}`;
      const checkRes = await fetch(
        `https://api.github.com/repos/${ORG}/${repo.name}/contents/${path}`,
        { headers: { Authorization: `Bearer ${GITHUB_TOKEN}` } }
      );
      if (checkRes.status === 200) continue; // skip if already exists

      // Only push ci-nextjs.yml + deploy-vps.yml as the minimal caller pair
      if (wfName !== 'ci-nextjs.yml' && wfName !== 'deploy-vps.yml') continue;

      console.log(`  Creating ${path}...`);
    }
  }
}

main().catch(console.error);
