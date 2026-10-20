<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
if (!$id) { http_response_code(400); exit('Invalid ticket number'); }
$st = db()->prepare("SELECT t.*,u.username owner FROM tickets t JOIN users u ON u.id=t.owner_id WHERE t.id = ? AND (t.owner_id = ? OR t.visibility = 'public') LIMIT 1");
$st->execute([$id, $user['id']]);
$ticket = $st->fetch();
if (!$ticket) { http_response_code(404); render_header('Ticket unavailable', 'tickets.php'); echo '<section class="panel"><h1>Ticket unavailable</h1><p>This item does not exist or you are not authorized to open it.</p></section>'; render_footer(); exit; }
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $comment = trim((string)($_POST['comment'] ?? ''));
    $sharedUrl = trim((string)($_POST['shared_url'] ?? ''));
    $validUrl = $sharedUrl === '' || (strlen($sharedUrl) <= 500 && filter_var($sharedUrl, FILTER_VALIDATE_URL) && in_array(strtolower((string)parse_url($sharedUrl, PHP_URL_SCHEME)), ['http','https'], true));
    if ($comment !== '' && mb_safe_length($comment) <= 2000 && $validUrl) {
        $st = db()->prepare('INSERT INTO ticket_comments (ticket_id, author_id, body, shared_url) VALUES (?, ?, ?, ?)');
        $st->execute([$id, $user['id'], $comment, $sharedUrl === '' ? null : $sharedUrl]);
        notice('Your update was posted to the ticket timeline.');
        go('/ticket.php?id=' . $id);
    }
    notice('Enter a message of 1–2000 characters and a valid optional link.');
    go('/ticket.php?id=' . $id);
}
function mb_safe_length(string $s): int { return function_exists('mb_strlen') ? mb_strlen($s, 'UTF-8') : strlen($s); }
$st = db()->prepare('SELECT c.id,c.body,c.shared_url,c.created_at,u.username FROM ticket_comments c JOIN users u ON u.id=c.author_id WHERE c.ticket_id = ? ORDER BY c.id');
$st->execute([$id]);
$comments = $st->fetchAll();
render_header('Case ' . $id,'tickets.php');
?>
<div class="breadcrumb"><a href="/tickets.php">← Service tickets</a><span>/</span> CASE-<?=(int)$ticket['id']?></div>
<div class="page-heading"><div><span class="eyebrow">SERVICE REQUEST / CASE-<?=(int)$ticket['id']?></span><h1><?=h($ticket['title'])?></h1><p>Submitted by <?=h($ticket['owner'])?> · <?=h(ucfirst($ticket['visibility']))?> request</p></div><span class="head-pill"><?=h(strtoupper($ticket['status']))?></span></div>
<div class="columns-main"><section class="panel"><div class="section-row"><h2>Request details</h2><span class="tag tag-<?=h($ticket['priority'])?>"><?=h($ticket['priority'])?> priority</span></div><p class="detail-body"><?=nl2br(h($ticket['description']))?></p><hr><div class="section-row"><div><span class="eyebrow">COLLABORATION</span><h2>Discussion timeline</h2></div><span class="muted"><?=count($comments)?> messages</span></div>
<div class="comments">
<?php foreach ($comments as $c): ?><article class="comment"><div class="avatar"><?=h(strtoupper(substr($c['username'],0,1)))?></div><div><div class="comment-meta"><b><?=h($c['username'])?></b><time><?=h($c['created_at'])?></time></div><div class="comment-body"><?php
    echo nl2br($c['body']);
?></div><?php if (!empty($c['shared_url'])): ?><p class="shared-document"><a href="<?=h($c['shared_url'])?>" rel="noreferrer">Open attached document ↗</a></p><?php endif; ?></div></article><?php endforeach; ?>
<?php if (!$comments): ?><p class="muted">There are no discussion updates yet.</p><?php endif; ?>
</div><form method="post" class="comment-form"><label for="comment">Add a discussion update</label><textarea id="comment" name="comment" rows="4" maxlength="2000" required placeholder="Provide the information needed to resolve this request..."></textarea><label for="shared_url" class="shared-url-label">Supporting document link (optional)</label><input id="shared_url" name="shared_url" type="url" maxlength="500" placeholder="https://documents.example/..." autocomplete="off"><div class="form-bottom"><span class="helper">Visible to all users authorized to view this ticket.</span><button class="button" type="submit">Post update</button></div></form></section>
<aside class="side-stack"><section class="panel side-note"><span class="eyebrow">CASE DETAILS</span><dl class="detail-list"><div><dt>Case ID</dt><dd>CASE-<?=(int)$ticket['id']?></dd></div><div><dt>Status</dt><dd><?=h($ticket['status'])?></dd></div><div><dt>Priority</dt><dd><?=h($ticket['priority'])?></dd></div><div><dt>Assigned owner</dt><dd><?=h($ticket['owner'])?></dd></div></dl><?php if ((int)$ticket['owner_id']===(int)$user['id']): ?>
<p><a class="button button-secondary" href="/ticket_edit.php?id=<?=(int)$ticket['id']?>">Edit this request</a></p>
<?php endif; ?></section><section class="panel side-note"><span class="eyebrow">SUPPORT WORKFLOW</span><h2>Shared discussion</h2><p>Service updates are preserved on the case so other staff can follow progress.</p></section></aside></div>
<?php render_footer(); ?>
