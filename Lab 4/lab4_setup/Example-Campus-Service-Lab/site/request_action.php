<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
if ($user['role'] !== 'admin') {
    http_response_code(403);
    render_header('Access denied','requests.php');
    echo '<section class="panel"><h1>Access denied</h1><p>Only authorized administrators can decide access applications.</p></section>';
    render_footer();
    exit;
}
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
$decision = (string)($_GET['decision'] ?? '');
if (!$id || !in_array($decision, ['approve','reject'], true)) {
    http_response_code(400); exit('Invalid request');
}
// Legacy one-click approval actions are invoked by URL for email compatibility.
// No per-request CSRF token is checked.
$status = $decision === 'approve' ? 'Approved' : 'Rejected';
$st = db()->prepare("UPDATE access_requests SET status=?, decided_by=?, decided_at=NOW() WHERE id=? AND status='Pending'");
$st->execute([$status, $user['id'], $id]);
notice($st->rowCount() ? 'Access request decision recorded.' : 'No pending request was updated.');
go('/requests.php');
