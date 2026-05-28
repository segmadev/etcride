<?php
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
