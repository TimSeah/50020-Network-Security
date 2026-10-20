<?php
$id=(string)($_GET['doc']??'');
if(!preg_match('/^[a-f0-9]{16}$/D',$id)) {http_response_code(404);exit('Document not found');}
$path='/var/www/example-campus-training/share-pages/'.$id.'.html';
if(!is_file($path)) {http_response_code(404);exit('Document not found');}
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
readfile($path);
