<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
$st=db()->query('SELECT u.id,u.username,u.role,p.display_name,p.job_title,pr.department FROM users u JOIN staff_profiles p ON p.user_id=u.id JOIN user_preferences pr ON pr.user_id=u.id WHERE u.active=1 ORDER BY p.display_name');
$people=$st->fetchAll();
render_header('Staff directory','directory.php');
?>
<div class="page-heading"><div><span class="eyebrow">PEOPLE / CAMPUS OPERATIONS</span><h1>Staff directory</h1><p>Find staff colleagues and coordinate cross-department requests.</p></div><a class="button button-secondary" href="/profile_edit.php">My directory profile →</a></div>
<div class="staff-grid">
<?php foreach ($people as $person): ?>
<a href="/profile.php?u=<?=urlencode($person['username'])?>" class="staff-card"><span class="staff-avatar"><?=h(strtoupper(substr($person['display_name'],0,1)))?></span><span><strong><?=h($person['display_name'])?></strong><small>@<?=h($person['username'])?> · <?=h($person['job_title'])?></small><small><?=h($person['department'])?></small></span><span class="chevron">›</span></a>
<?php endforeach; ?>
</div>
<?php render_footer(); ?>
