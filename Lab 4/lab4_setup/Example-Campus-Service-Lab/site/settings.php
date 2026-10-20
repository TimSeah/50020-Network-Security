<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $alerts = (string)($_POST['security_alerts'] ?? '') === '1' ? 1 : 0;
    $alertEmail = trim((string)($_POST['alert_email'] ?? ''));
    if (!filter_var($alertEmail,FILTER_VALIDATE_EMAIL) || strlen($alertEmail)>120) {
        notice('Enter a valid email address for notification delivery.');
        go('/settings.php');
    }
    // Account preferences are changed without verifying a CSRF token.
    $st = db()->prepare('UPDATE user_preferences SET security_alerts=?, alert_email=? WHERE user_id=?');
    $st->execute([$alerts, $alertEmail, $user['id']]);
    notice('Security notification preferences updated.');
    go('/settings.php');
}
$st = db()->prepare('SELECT email,department,security_alerts,alert_email FROM user_preferences WHERE user_id=?');
$st->execute([$user['id']]);
$prefs = $st->fetch();
render_header('Account settings','settings.php');
?>
<div class="page-heading"><div><span class="eyebrow">ACCOUNT MANAGEMENT / PREFERENCES</span><h1>My settings</h1><p>Manage your staff profile and the service notifications you receive.</p></div></div>
<div class="columns-main"><section class="panel"><div class="section-row"><div><span class="eyebrow">PROFILE</span><h2>Staff information</h2><a class="subtle-link" href="/profile_edit.php">Edit staff directory profile →</a></div><span class="tag">ACTIVE ACCOUNT</span></div>
<div class="profile-grid"><div><span>Account name</span><strong><?=h($user['username'])?></strong></div><div><span>Department</span><strong><?=h($prefs['department'])?></strong></div><div><span>Contact email</span><strong><?=h($prefs['email'])?></strong></div><div><span>Access role</span><strong><?=h($user['role'])?></strong></div></div><hr>
<span class="eyebrow">NOTIFICATION SETTINGS</span><h2>Account security notifications</h2><p class="muted">Set where account activity and access notifications should be delivered. This does not change your directory contact address.</p>
<div class="status-box"><span>Current preference</span><strong class="<?= $prefs['security_alerts'] ? 'positive' : 'negative' ?>"><?= $prefs['security_alerts'] ? 'Enabled' : 'Disabled' ?></strong></div>
<div class="status-box"><span>Notification delivery address</span><strong><?=h($prefs['alert_email'])?></strong></div>
<form method="post" class="form-grid"><fieldset class="radio-options"><legend>Security alert delivery</legend><label><input type="radio" name="security_alerts" value="1" <?=$prefs['security_alerts']?'checked':''?>> Enable security alerts</label><label><input type="radio" name="security_alerts" value="0" <?=!$prefs['security_alerts']?'checked':''?>> Disable security alerts</label></fieldset><label>Deliver security notices to<input type="email" name="alert_email" value="<?=h($prefs['alert_email'])?>" maxlength="120" required></label><button class="button" type="submit">Save preferences</button></form></section>
<aside class="side-stack"><?php if ($user['role'] === 'admin'): ?><section class="panel side-note"><span class="eyebrow">INTERNAL SYSTEMS</span><h2>Internal configuration</h2><p>Review the current internal service configuration.</p><a class="button button-secondary" href="http://<?=h((string)($_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_ADDR']))?>:8081/secret/">Open configuration →</a></section><?php endif; ?><section class="panel side-note"><span class="eyebrow">ACCOUNT STATUS</span><h2>Authenticated session</h2><p>These preferences are specific to the signed-in account. Changes are saved to your staff profile.</p></section><section class="panel side-note"><span class="eyebrow">SUPPORT</span><h2>Need assistance?</h2><p>Visit the service desk for general access and account support.</p><a class="subtle-link" href="/tickets.php">Open service requests →</a></section></aside></div>
<?php render_footer(); ?>
