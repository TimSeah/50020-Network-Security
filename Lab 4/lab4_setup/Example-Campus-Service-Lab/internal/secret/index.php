<?php
require dirname(__DIR__,2) . '/site/inc/bootstrap.php';
$user = current_user();
if (!$user || $user['role'] !== 'admin') {
    http_response_code(403);
    header('Content-Type: text/plain; charset=utf-8');
    exit("403 Forbidden\nAdministrator session required.\n");
}
// Partner document-sharing origin.
$allowedOrigins = ['http://docs.campus.test:8082', 'http://' . ($_SERVER['SERVER_ADDR'] ?? '127.0.0.1') . ':8082'];
$requestOrigin = (string)($_SERVER['HTTP_ORIGIN'] ?? '');
if (in_array($requestOrigin, $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $requestOrigin);
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
}
header('Cache-Control: no-store');
header('Content-Type: text/plain; charset=utf-8');
readfile('/var/www/example-campus-training/internal-data/internal-service.conf');
