<?php
// Direct migration runner
$migrationFile = __DIR__ . '/database/sql/021_payment_gateway_settings.sql';

if (!file_exists($migrationFile)) {
    die("❌ Migration file not found: $migrationFile\n");
}

try {
    // Direct PDO connection
    $pdo = new PDO(
        'mysql:host=127.0.0.1;dbname=etcride',
        'root',
        ''
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $sql = file_get_contents($migrationFile);

    // Remove SQL comments
    $sql = preg_replace('/--.*$/m', '', $sql); // Remove -- comments
    $sql = preg_replace('/\/\*.*?\*\//s', '', $sql); // Remove /* */ comments

    // Split queries by semicolon and execute each
    $queries = explode(';', $sql);
    $executed = 0;

    foreach ($queries as $query) {
        $query = trim($query);
        if (!empty($query)) {
            $pdo->exec($query);
            $executed++;
            echo "✓ Executed query $executed\n";
        }
    }

    echo "\n✅ Migration completed successfully!\n";
    echo "✓ Total statements executed: " . $executed . "\n";

} catch (PDOException $e) {
    echo "❌ Migration failed: " . $e->getMessage() . "\n";
    exit(1);
}
?>
