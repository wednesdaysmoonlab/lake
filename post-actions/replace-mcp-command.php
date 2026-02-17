#!/usr/bin/env php
<?php

require_once getcwd() . '/vendor/autoload.php';

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\info;
use function Laravel\Prompts\warning;
use function Laravel\Prompts\note;

$path = getcwd() . '/.mcp.json';

// Condition: only act if .mcp.json exists and contains "command": "php"
if (!file_exists($path)) {
    exit(0);
}

$content = file_get_contents($path);

if (strpos($content, '"command": "php"') === false && strpos($content, '"command":"php"') === false) {
    exit(0);
}

// Inform + confirm via laravel/prompts
echo PHP_EOL;
warning('Detected .mcp.json with "command": "php"');
note('Lake has no system PHP — the command must point to .lake/php.');

$patch = confirm(
    label: 'Patch .mcp.json: replace "php" → ".lake/php"?',
    default: true,
    hint: 'Required for MCP tools to work in a Lake environment.'
);

if (!$patch) {
    info('Skipped .mcp.json patching.');
    exit(0);
}

// Targeted regex — preserves original formatting/whitespace
$patched = preg_replace('/"command"(\s*:\s*)"php"/', '"command"$1".lake/php"', $content);

if ($patched !== null && $patched !== $content) {
    file_put_contents($path, $patched);
    info('Patched .mcp.json: "php" → ".lake/php"');
} else {
    info('No changes needed in .mcp.json.');
}
