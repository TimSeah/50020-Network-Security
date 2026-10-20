<?php
require __DIR__ . '/inc/bootstrap.php';
$user = current_user();
if (!$user) { go('/login.php'); }
$stmt = db()->prepare("SELECT COUNT(*) FROM tickets WHERE owner_id=? OR visibility='public'");
$stmt->execute([$user['id']]);
$count = (int)$stmt->fetchColumn();
$stmt = db()->prepare("SELECT t.id,t.title,t.status,t.priority,t.visibility,u.username owner FROM tickets t JOIN users u ON u.id=t.owner_id WHERE (t.owner_id=? OR t.visibility='public') ORDER BY t.id DESC LIMIT 4");
$stmt->execute([$user['id']]);
$recent = $stmt->fetchAll();
render_header('Dashboard','index.php');
?>
<div class="page-heading"><div><span class="eyebrow">SERVICE OPERATIONS / OVERVIEW</span><h1>Welcome back, <?=h(ucfirst($user['username']))?>.</h1><p>Here is the current snapshot of your campus services workspace.</p></div><a class="button" href="/tickets.php">Browse service tickets →</a></div>
<div class="stats"><div class="stat"><span>Accessible tickets</span><strong><?=$count?></strong><small>Current service requests</small></div><div class="stat"><span>Staff account</span><strong><?=h(ucfirst($user['role']))?></strong><small>Role-based workspace</small></div><div class="stat"><span>Available services</span><strong>4</strong><small>Departments supporting campus staff</small></div></div>
<div class="columns-main">
<section class="panel"><div class="section-row"><div><span class="eyebrow">SERVICE DESK</span><h2>Recent tickets</h2></div><a class="subtle-link" href="/tickets.php">View all →</a></div>
<div class="ticket-list">
<?php foreach ($recent as $t): ?><a class="ticket-row" href="/ticket.php?id=<?=(int)$t['id']?>"><span class="ticket-icon">#</span><span class="ticket-primary"><strong><?=h($t['title'])?></strong><small>CASE-<?= (int)$t['id']?> · Owner <?=h($t['owner'])?></small></span><span class="tag"><?=h($t['status'])?></span><span class="chevron">›</span></a><?php endforeach; ?>
</div></section>
<aside class="side-stack"><section class="panel side-note"><span class="eyebrow">HELP CENTER</span><h2>Need a procedure?</h2><p>Find campus service and security guidance in the knowledge base.</p><a href="/knowledge.php" class="button button-secondary">Search knowledge →</a></section><section class="panel side-note"><span class="eyebrow">STAFF DIRECTORY</span><h2>Find a colleague</h2><p>Find colleagues across departments and review their staff profiles.</p><a href="/directory.php" class="subtle-link">View staff directory →</a></section></aside>
</div>
<?php render_footer(); ?>
