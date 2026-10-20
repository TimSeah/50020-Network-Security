<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
$isAdmin = $user['role'] === 'admin';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !$isAdmin) {
    $resource = trim((string)($_POST['resource_name'] ?? ''));
    $reason = trim((string)($_POST['justification'] ?? ''));
    if ($resource === '' || mb_strlen_safe($resource) > 160 || $reason === '' || mb_strlen_safe($reason) > 1000) {
        notice('Enter a valid access request and justification.');
    } else {
        $add = db()->prepare("INSERT INTO access_requests (requester_id,resource_name,justification,status) VALUES (?,?,?,'Pending')");
        $add->execute([$user['id'],$resource,$reason]);
        notice('Access application submitted for administrator review.');
    }
    go('/requests.php');
}
function mb_strlen_safe(string $v): int { return function_exists('mb_strlen') ? mb_strlen($v, 'UTF-8') : strlen($v); }
if ($isAdmin) {
    $st = db()->query('SELECT r.*,u.username requester FROM access_requests r JOIN users u ON u.id=r.requester_id ORDER BY r.id ASC');
} else {
    $st = db()->prepare('SELECT r.*,u.username requester FROM access_requests r JOIN users u ON u.id=r.requester_id WHERE r.requester_id=? ORDER BY r.id ASC');
    $st->execute([$user['id']]);
}
$requests = $st->fetchAll();
render_header('Access requests', 'requests.php');
?>
<div class="page-heading"><div><span class="eyebrow">CAMPUS ACCESS / SERVICE REQUESTS</span><h1>Access requests</h1><p><?= $isAdmin ? 'Review access authorizations requested by campus staff.' : 'Track your submitted access applications and their approval status.' ?></p></div></div>
<section class="panel"><div class="section-row"><h2><?= $isAdmin ? 'Pending and completed approvals' : 'My applications' ?></h2><span class="tag"><?=count($requests)?> requests</span></div>
<?php if (!$requests): ?><p class="empty">There are no access applications.</p><?php else: ?>
<table class="inventory request-table"><thead><tr><th>Request</th><th>Requested by</th><th>Status</th><?php if ($isAdmin): ?><th>Action</th><?php endif; ?></tr></thead><tbody>
<?php foreach($requests as $r): ?><tr><td><strong>AR-<?=(int)$r['id']?> · <?=h($r['resource_name'])?></strong><div class="muted request-description"><?=h($r['justification'])?></div></td><td><?=h($r['requester'])?></td><td><span class="tag <?= $r['status']==='Approved'?'tag-approved':($r['status']==='Rejected'?'tag-high':'tag-medium') ?>"><?=h($r['status'])?></span></td>
<?php if($isAdmin): ?><td><?php if($r['status']==='Pending'): ?><a class="button request-action" href="/request_action.php?id=<?=(int)$r['id']?>&decision=approve">Approve</a> <a class="subtle-link" href="/request_action.php?id=<?=(int)$r['id']?>&decision=reject">Reject</a><?php else: ?><span class="muted">Decision recorded</span><?php endif; ?></td><?php endif; ?></tr><?php endforeach; ?>
</tbody></table><?php endif; ?></section>
<?php if(!$isAdmin): ?><section class="panel request-create-panel"><span class="eyebrow">NEW APPLICATION</span><h2>Request campus access</h2><p class="muted">Applications are sent to the access administration team for review.</p><form class="form-grid" method="post"><label>Requested area or system<input type="text" name="resource_name" maxlength="160" required placeholder="e.g. research computing room"></label><label>Reason for access<textarea name="justification" maxlength="1000" rows="4" required placeholder="Describe the business purpose and time period"></textarea></label><button class="button" type="submit">Submit access request</button></form></section><?php endif; ?>
<?php render_footer(); ?>
