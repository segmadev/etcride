<?php
// ── Dev error logging → PHP built-in server terminal ─────────────────────────
ini_set('display_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

set_exception_handler(function (\Throwable $e) {
    $msg = sprintf(
        "[EXCEPTION] %s: %s in %s:%d\nStack trace:\n%s\n",
        get_class($e), $e->getMessage(),
        $e->getFile(), $e->getLine(),
        $e->getTraceAsString()
    );
    error_log($msg);
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
});

set_error_handler(function (int $errno, string $errstr, string $errfile, int $errline) {
    $msg = sprintf("[PHP ERROR %d] %s in %s:%d\n", $errno, $errstr, $errfile, $errline);
    error_log($msg);
    return false; // let normal error handling continue
});

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Authorization, Content-Type, Accept, X-Requested-With");

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
$parsedUrl = parse_url($_SERVER['REQUEST_URI']);
$cleanPath = rtrim($parsedUrl['path'] ?? '/', '/');
define("ISAPI", true);
define("PATH", str_replace("//", "/", str_replace("/api", "", $cleanPath)));
if (!empty($parsedUrl['query'])) {
    parse_str($parsedUrl['query'], $_GET);
}
require_once dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . "consts" . DIRECTORY_SEPARATOR . "main.php";
require_once ROOT . "functions" . DIRECTORY_SEPARATOR . "database.php";
require_once ROOT . "api" . DIRECTORY_SEPARATOR . "functions" . DIRECTORY_SEPARATOR . "router.php";
require_once ROOT . "functions" . DIRECTORY_SEPARATOR . "helper.php";
