#!/usr/bin/env php
<?php
/**
 * EtcRide — Schema Manager
 * CLI tool for database schema inspection, creation, seeding, and diffing.
 *
 * Usage:  php scripts/schema.php <command> [argument]
 *
 * Commands:
 *   status              Show all tables with row counts and engine
 *   inspect [table]     Describe columns & indexes (all tables if omitted)
 *   run                 Execute database/schema.sql  (CREATE IF NOT EXISTS)
 *   seed                Execute database/seeds.sql   (INSERT IGNORE — idempotent)
 *   fresh               DROP all tables, re-run schema + seed (asks confirmation)
 *   diff                Compare schema.sql expected tables vs actual DB
 *   exec <file.sql>     Execute any custom SQL file
 *   help                Show this help
 */

define('ROOT',   dirname(__DIR__) . DIRECTORY_SEPARATOR);
define('DB_DIR', ROOT . 'database' . DIRECTORY_SEPARATOR);

// ── ANSI helpers ──────────────────────────────────────────────────────────────
function clr(string $t, string $c): string { return $c . $t . "\033[0m"; }
function info(string $m): void { echo clr("  ℹ  $m", "\033[36m") . "\n"; }
function ok(string $m): void   { echo clr("  ✔  $m", "\033[32m") . "\n"; }
function warn(string $m): void { echo clr("  ⚠  $m", "\033[33m") . "\n"; }
function fail(string $m): void { echo clr("  ✖  $m", "\033[31m") . "\n"; }
function head(string $m): void
{
    $line = str_repeat('─', max(60, mb_strlen($m) + 4));
    echo "\n" . clr($m, "\033[1m\033[36m") . "\n" . $line . "\n";
}

// ── .env loader ───────────────────────────────────────────────────────────────
function loadEnv(string $path): void
{
    if (!file_exists($path)) {
        warn(".env not found at $path");
        return;
    }
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) continue;
        if (!str_contains($line, '=')) continue;
        [$key, $val] = array_map('trim', explode('=', $line, 2));
        $val = trim($val, "\"' \t");
        $_ENV[$key] = $val;
    }
}

// ── PDO singleton ─────────────────────────────────────────────────────────────
function db(): PDO
{
    static $pdo = null;
    if ($pdo) return $pdo;

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $_ENV['DB_HOST'] ?? 'localhost',
        $_ENV['DB_PORT'] ?? '3306',
        $_ENV['DB_DATABASE'] ?? 'etcride'
    );
    try {
        $pdo = new PDO($dsn, $_ENV['DB_USERNAME'] ?? 'root', $_ENV['DB_PASSWORD'] ?? '', [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    } catch (PDOException $e) {
        fail('DB Connection failed: ' . $e->getMessage());
        exit(1);
    }
    return $pdo;
}

// ── SQL file runner ───────────────────────────────────────────────────────────
function runSqlFile(string $file): array
{
    if (!file_exists($file)) {
        fail("File not found: $file");
        return ['ok' => 0, 'fail' => 1, 'errors' => ["File not found: $file"]];
    }

    $sql    = file_get_contents($file);
    $stmts  = array_filter(array_map('trim', explode(';', $sql)));
    $ok = $fail = 0;
    $errors = [];

    foreach ($stmts as $stmt) {
        // Skip blank lines and pure comment blocks
        if ($stmt === '' || preg_match('/^(--.*)$/m', $stmt) && trim(preg_replace('/--[^\n]*/m', '', $stmt)) === '') {
            continue;
        }
        try {
            db()->exec($stmt);
            $ok++;
        } catch (PDOException $e) {
            $fail++;
            $errors[] = $e->getMessage() . "\n    → " . substr(preg_replace('/\s+/', ' ', $stmt), 0, 120);
        }
    }
    return compact('ok', 'fail', 'errors');
}

// ── Commands ──────────────────────────────────────────────────────────────────

function cmd_status(): void
{
    head('DATABASE STATUS');
    info('Host: ' . ($_ENV['DB_HOST'] ?? 'localhost') . '   DB: ' . ($_ENV['DB_DATABASE'] ?? '?'));

    $tables = db()->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
    if (!$tables) { warn('No tables found.'); return; }

    echo "\n";
    printf("  %-35s %8s  %12s  %s\n",
        clr('Table', "\033[1m"), clr('Rows', "\033[1m"),
        clr('Engine', "\033[1m"), clr('Collation', "\033[1m"));
    echo '  ' . str_repeat('─', 75) . "\n";

    foreach ($tables as $t) {
        try {
            $rows  = db()->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
            $info  = db()->query("SHOW TABLE STATUS LIKE '$t'")->fetch();
            printf("  %-35s %8s  %12s  %s\n",
                clr($t, "\033[36m"),
                number_format((int)$rows),
                $info['Engine'] ?? '?',
                $info['Collation'] ?? '?'
            );
        } catch (PDOException) {
            printf("  %-35s %8s\n", clr($t, "\033[31m"), 'error');
        }
    }
    echo "\n  " . clr(count($tables) . ' tables total', "\033[2m") . "\n";
}

function cmd_inspect(string $table = ''): void
{
    $tables = $table
        ? [$table]
        : db()->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);

    foreach ($tables as $t) {
        head("TABLE: $t");
        try {
            $cols = db()->query("DESCRIBE `$t`")->fetchAll();
            printf("  %-28s %-26s %-6s %-6s %-18s %s\n",
                clr('Column', "\033[1m"), clr('Type', "\033[1m"),
                clr('Null', "\033[1m"),   clr('Key', "\033[1m"),
                clr('Default', "\033[1m"), clr('Extra', "\033[1m"));
            echo '  ' . str_repeat('─', 100) . "\n";

            foreach ($cols as $col) {
                $kc = match ($col['Key']) {
                    'PRI' => "\033[33m", 'UNI' => "\033[36m", 'MUL' => "\033[32m", default => ''
                };
                printf("  %-28s %-26s %-6s %-6s %-18s %s\n",
                    clr($col['Field'], "\033[36m"),
                    $col['Type'],
                    $col['Null'],
                    clr($col['Key'], $kc),
                    $col['Default'] ?? 'NULL',
                    clr($col['Extra'], "\033[2m")
                );
            }

            // Indexes
            $indexes = db()->query("SHOW INDEX FROM `$t`")->fetchAll();
            if ($indexes) {
                $grouped = [];
                foreach ($indexes as $i) {
                    $grouped[$i['Key_name']][] = $i['Column_name'];
                }
                echo "\n  " . clr('Indexes:', "\033[1m") . "\n";
                foreach ($grouped as $name => $cols) {
                    printf("    %-32s %s\n", clr($name, "\033[33m"), implode(', ', $cols));
                }
            }

            // Foreign keys
            $fks = db()->query("
                SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = '$t'
                  AND REFERENCED_TABLE_NAME IS NOT NULL
            ")->fetchAll();
            if ($fks) {
                echo "\n  " . clr('Foreign Keys:', "\033[1m") . "\n";
                foreach ($fks as $fk) {
                    printf("    %-20s → %s.%s\n",
                        clr($fk['COLUMN_NAME'], "\033[36m"),
                        $fk['REFERENCED_TABLE_NAME'],
                        $fk['REFERENCED_COLUMN_NAME']
                    );
                }
            }
            echo "\n";

        } catch (PDOException $e) {
            fail("Table '$t' error: " . $e->getMessage());
        }
    }
}

function cmd_run(): void
{
    head('RUNNING SCHEMA');
    $file = DB_DIR . 'schema.sql';
    info("File: $file");
    $r = runSqlFile($file);
    ok("Statements executed: {$r['ok']}");
    if ($r['fail']) {
        warn("Failures: {$r['fail']}");
        foreach ($r['errors'] as $e) fail($e);
    } else {
        ok('Schema applied successfully.');
    }
}

function cmd_seed(): void
{
    head('SEEDING DATABASE');
    $file = DB_DIR . 'seeds.sql';
    info("File: $file");
    $r = runSqlFile($file);
    ok("Statements executed: {$r['ok']}");
    if ($r['fail']) {
        warn("Failures: {$r['fail']}");
        foreach ($r['errors'] as $e) fail($e);
    } else {
        ok('Seed data inserted.');
    }
}

function cmd_fresh(): void
{
    head('FRESH — DROP & RECREATE ALL TABLES');
    warn('This will DROP every table in the database and recreate from schema.sql + seeds.sql');
    echo '  Type ' . clr('yes', "\033[31m") . ' to confirm: ';
    $confirm = trim(fgets(STDIN));
    if ($confirm !== 'yes') { info('Aborted.'); return; }

    $pdo = db();
    $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
    $tables = $pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
    foreach ($tables as $t) {
        $pdo->exec("DROP TABLE IF EXISTS `$t`");
        ok("Dropped: $t");
    }
    $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

    cmd_run();
    cmd_seed();
}

function cmd_diff(): void
{
    head('SCHEMA DIFF');
    $schemaFile = DB_DIR . 'schema.sql';
    if (!file_exists($schemaFile)) { fail('database/schema.sql not found.'); return; }

    preg_match_all('/CREATE TABLE(?:\s+IF NOT EXISTS)?\s+`?(\w+)`?/i', file_get_contents($schemaFile), $m);
    $expected = $m[1];
    $actual   = db()->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);

    $missing  = array_diff($expected, $actual);
    $extra    = array_diff($actual, $expected);
    $present  = array_intersect($expected, $actual);

    echo "\n";
    foreach ($present as $t) echo '  ' . clr("✔  $t", "\033[32m") . "\n";
    foreach ($missing as $t) echo '  ' . clr("✖  $t  ← MISSING", "\033[31m") . "\n";
    foreach ($extra as $t)   echo '  ' . clr("?  $t  (not in schema.sql)", "\033[33m") . "\n";

    echo "\n";
    ok(count($present) . ' present   ' . count($missing) . ' missing   ' . count($extra) . ' extra');
}

function cmd_exec(string $file): void
{
    head("EXEC: $file");
    if (!file_exists($file)) $file = ROOT . ltrim($file, '/\\');
    $r = runSqlFile($file);
    ok("Statements executed: {$r['ok']}");
    if ($r['fail']) foreach ($r['errors'] as $e) fail($e);
}

function cmd_help(): void
{
    head('EtcRide Schema Manager');
    $cmds = [
        'status'            => 'Show all tables with row counts',
        'inspect [table]'   => 'Show columns & indexes (all tables if omitted)',
        'run'               => 'Create tables from database/schema.sql  (IF NOT EXISTS)',
        'seed'              => 'Insert defaults from database/seeds.sql (INSERT IGNORE)',
        'fresh'             => 'DROP all tables, re-run schema + seed',
        'diff'              => 'Compare schema.sql expected tables vs actual DB',
        'exec <file.sql>'   => 'Execute any custom SQL file',
        'help'              => 'Show this help',
    ];
    foreach ($cmds as $c => $d) {
        printf("  %-25s %s\n", clr($c, "\033[36m"), $d);
    }
    echo "\n  Example: " . clr('php scripts/schema.php inspect bookings', "\033[2m") . "\n";
}

// ── Entry ─────────────────────────────────────────────────────────────────────
loadEnv(ROOT . '.env');

$cmd = $argv[1] ?? 'help';
$arg = $argv[2] ?? '';

match ($cmd) {
    'status'  => cmd_status(),
    'inspect' => cmd_inspect($arg),
    'run'     => cmd_run(),
    'seed'    => cmd_seed(),
    'fresh'   => cmd_fresh(),
    'diff'    => cmd_diff(),
    'exec'    => cmd_exec($arg),
    default   => cmd_help(),
};

echo "\n";
