#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const dist = path.join(root, 'dist');
const indexPath = path.join(dist, 'index.html');

function fail(message) {
	console.error(`[inject-initial-chunks] ${message}`);
	process.exit(1);
}

function read(file) {
	return fs.readFileSync(file, 'utf8');
}

function publicPathFor(fileName) {
	return `/${fileName}`;
}

if (!fs.existsSync(indexPath)) {
	fail('missing dist/index.html');
}

let html = read(indexPath);
const entryMatch = html.match(/<script\s+src=["']\/([^"']*umi\.[^"']+\.js)["']><\/script>/);
if (!entryMatch) {
	fail('could not find Umi entry script in index.html');
}

const entryFileName = entryMatch[1];
const entryPath = path.join(dist, entryFileName);
if (!fs.existsSync(entryPath)) {
	fail(`entry script ${entryFileName} does not exist`);
}

const entrySource = read(entryPath);
const bootstrapMatch = entrySource.match(/\.push\(\[([^\]]+)\]\),a\(\)/);
if (!bootstrapMatch) {
	console.log('[inject-initial-chunks] no explicit initial chunk dependency list found');
	process.exit(0);
}

const bootstrapNumbers = bootstrapMatch[1]
	.split(',')
	.map((part) => part.trim())
	.filter((part) => /^\d+$/.test(part))
	.map((part) => Number(part));

// Webpack's first value is the entry module id. The remaining values are
// initial chunk ids that must be available before the entry can execute.
const requiredChunkIds = [];
bootstrapNumbers.slice(1).forEach((id) => {
	if (!requiredChunkIds.includes(id)) {
		requiredChunkIds.push(id);
	}
});

if (requiredChunkIds.length === 0) {
	console.log('[inject-initial-chunks] entry has no initial chunk dependencies');
	process.exit(0);
}

const chunkFiles = new Map();
fs.readdirSync(dist)
	.filter((fileName) => fileName.endsWith('.js') && fileName !== entryFileName)
	.forEach((fileName) => {
		const source = read(path.join(dist, fileName));
		const match = source.match(/\.push\(\[\[([^\]]+)\]/);
		if (!match) {
			return;
		}
		match[1]
			.split(',')
			.map((part) => part.trim())
			.filter((part) => /^\d+$/.test(part))
			.forEach((id) => chunkFiles.set(Number(id), fileName));
	});

const missingIds = requiredChunkIds.filter((id) => !chunkFiles.has(id));
if (missingIds.length) {
	fail(`missing JavaScript files for initial chunk id(s): ${missingIds.join(', ')}`);
}

const requiredScripts = requiredChunkIds.map((id) => chunkFiles.get(id));
const scriptTags = requiredScripts
	.filter((fileName) => !html.includes(`src="${publicPathFor(fileName)}"`))
	.map((fileName) => `    <script src="${publicPathFor(fileName)}"></script>`)
	.join('\n');

if (scriptTags) {
	html = html.replace(
		`    <script src="${publicPathFor(entryFileName)}"></script>`,
		`${scriptTags}\n    <script src="${publicPathFor(entryFileName)}"></script>`
	);
}

const cssFiles = fs.readdirSync(dist)
	.filter((fileName) => fileName.endsWith('.chunk.css'))
	.sort();
const cssTags = cssFiles
	.filter((fileName) => !html.includes(`href="${publicPathFor(fileName)}"`))
	.map((fileName) => `    <link rel="stylesheet" href="${publicPathFor(fileName)}" />`)
	.join('\n');

if (cssTags) {
	html = html.replace(
		/    <link rel="stylesheet" href="\/([^"]*umi\.[^"]+\.css)" \/>/,
		`${cssTags}\n$&`
	);
}

fs.writeFileSync(indexPath, html);
console.log(
	`[inject-initial-chunks] injected ${requiredScripts.length} initial script(s) and ${cssFiles.length} chunk stylesheet(s)`
);
