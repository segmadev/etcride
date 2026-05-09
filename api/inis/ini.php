<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
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
