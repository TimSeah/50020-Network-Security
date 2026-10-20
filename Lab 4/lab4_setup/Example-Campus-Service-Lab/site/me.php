<?php
// Small same-origin profile endpoint for the staff portal frontend.
require __DIR__.'/inc/bootstrap.php';
$user=require_login();
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
echo json_encode(['username'=>$user['username'],'role'=>$user['role'],'current_origin'=>'staff-portal'],JSON_UNESCAPED_SLASHES);
