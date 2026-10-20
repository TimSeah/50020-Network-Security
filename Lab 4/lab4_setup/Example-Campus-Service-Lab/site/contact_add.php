<?php
require __DIR__.'/inc/bootstrap.php';
$user=require_login();
$username=trim((string)($_GET['u']??''));
$st=db()->prepare('SELECT id FROM users WHERE username=? AND active=1');
$st->execute([$username]); $colleague=$st->fetchColumn();
if(!$colleague || (int)$colleague===(int)$user['id']){http_response_code(400);exit('Invalid colleague');}
$st=db()->prepare('INSERT IGNORE INTO staff_contacts (user_id,colleague_id) VALUES (?,?)');
$st->execute([$user['id'],$colleague]);
notice('Colleague added to your contacts.');
go('/profile.php?u='.urlencode($username));
