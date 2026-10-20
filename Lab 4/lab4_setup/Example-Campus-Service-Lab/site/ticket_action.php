<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit('Method not allowed'); }
$action = (string)($_POST['action'] ?? '');
$id = (int)($_POST['id'] ?? 0);
$title = trim((string)($_POST['title'] ?? ''));
$description = trim((string)($_POST['description'] ?? ''));
$status = (string)($_POST['status'] ?? 'Open');
$priority = (string)($_POST['priority'] ?? 'medium');
$visibility = (string)($_POST['visibility'] ?? 'private');
if ($action === 'create') {
    if ($title === '' || $description === '') { http_response_code(400); exit('Missing request fields'); }
    $owner_id = (int)$user['id'];
    $st = db()->prepare('INSERT INTO tickets (owner_id,title,description,status,priority,visibility) VALUES (?,?,?,?,?,?)');
    $st->execute([$owner_id,substr($title,0,180),substr($description,0,2000),'Open',in_array($priority,['low','medium','high'],true)?$priority:'medium',in_array($visibility,['private','public'],true)?$visibility:'private']);
    notice('Your service request has been submitted.');
    go('/tickets.php');
}
if ($action === 'update') {
    if ($id < 1 || $title === '' || $description === '') { http_response_code(400); exit('Invalid request'); }
    $st = db()->prepare('UPDATE tickets SET title=?,description=?,status=? WHERE id=? AND owner_id=?');
    $st->execute([substr($title,0,180),substr($description,0,2000),in_array($status,['Open','In progress','Scheduled','Resolved'],true)?$status:'Open',$id,$user['id']]);
    notice('Service request updated.');
    go('/tickets.php');
}
if ($action === 'delete') {
    if ($id < 1) { http_response_code(400); exit('Invalid request'); }
    $st = db()->prepare('DELETE FROM ticket_comments WHERE ticket_id=? AND ticket_id IN (SELECT id FROM tickets WHERE owner_id=?)');
    $st->execute([$id, $user['id']]);
    $st = db()->prepare('DELETE FROM tickets WHERE id=? AND owner_id=?');
    $st->execute([$id, $user['id']]);
    notice('Service request deleted.');
    go('/tickets.php');
}
http_response_code(400); exit('Unknown request');
