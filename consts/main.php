<?php
define("Regex", "");
define("ROOT", dirname(__DIR__) . DIRECTORY_SEPARATOR);
define("APP_ENV", strtolower((string) ($_ENV['APP_ENV'] ?? 'development')));
require_once ROOT . "functions" . DIRECTORY_SEPARATOR . "utilities.php";
if(isset($_ENV['APP_DEBUG']) &&  $_ENV['APP_DEBUG']){
    ini_set('display_startup_errors', 1);
    ini_set('display_errors', 1);
    error_reporting(-1);
}
