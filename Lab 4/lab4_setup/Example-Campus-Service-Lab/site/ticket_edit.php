<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$st = db()->prepare('SELECT * FROM tickets WHERE id = ? AND owner_id = ?');
$st->execute([$id, $user['id']]);
$t = $st->fetch();
if (!$t) { http_response_code(404); render_header('Request unavailable','tickets.php'); echo '<section class="panel"><h1>Request unavailable</h1></section>'; render_footer(); exit; }
render_header('Edit request','tickets.php');
?>
<div class="breadcrumb"><a href="/ticket.php?id=<?=(int)$t['id']?>">← CASE-<?=(int)$t['id']?></a><span>/</span> Edit</div>
<div class="page-heading"><div><span class="eyebrow">SERVICE OPERATIONS / REQUEST MAINTENANCE</span><h1>Edit service request</h1><p>Keep the details and status accurate for the service team.</p></div></div>
<section class="panel" style="max-width:800px"><form method="post" action="/ticket_action.php" class="form-grid">
<input type="hidden" name="action" value="update"><input type="hidden" name="id" value="<?=(int)$t['id']?>">
<label>Request title<input name="title" required maxlength="180" value="<?=h($t['title'])?>"></label>
<label>Details<textarea name="description" required rows="5" maxlength="2000"><?=h($t['description'])?></textarea></label>
<label>Status<select name="status"><?php foreach (['Open','In progress','Scheduled','Resolved'] as $s): ?><option value="<?=h($s)?>" <?=$t['status']===$s?'selected':''?>><?=h($s)?></option><?php endforeach; ?></select></label>
<button class="button" type="submit">Save changes</button></form>
<hr><form method="post" action="/ticket_action.php" onsubmit="return confirm('Delete this request?')"><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?=(int)$t['id']?>"><button class="button button-ghost" type="submit">Delete request</button></form></section>
<?php render_footer(); ?>
