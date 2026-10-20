<?php
require __DIR__ . '/inc/bootstrap.php';
$user=require_login();
$username=trim((string)($_GET['u']??''));
$st=db()->prepare('SELECT u.id,u.username,u.role,p.display_name,p.job_title,p.about_me,pr.department FROM users u JOIN staff_profiles p ON p.user_id=u.id JOIN user_preferences pr ON pr.user_id=u.id WHERE u.username=? AND u.active=1');
$st->execute([$username]);
$person=$st->fetch();
if(!$person){http_response_code(404);render_header('Staff profile','directory.php'); echo '<section class="panel"><h1>Profile not found</h1></section>'; render_footer(); exit;}
$st=db()->prepare('SELECT COUNT(*) FROM staff_contacts WHERE user_id=? AND colleague_id=?');
$st->execute([$user['id'],$person['id']]);
$isContact=(bool)$st->fetchColumn();
$st=db()->prepare('SELECT p.display_name,u.username FROM staff_contacts c JOIN users u ON u.id=c.colleague_id JOIN staff_profiles p ON p.user_id=u.id WHERE c.user_id=? ORDER BY p.display_name');
$st->execute([$person['id']]);
$contacts=$st->fetchAll();
render_header('Staff profile · '.$person['display_name'],'directory.php');
?>
<div class="breadcrumb"><a href="/directory.php">← Staff directory</a><span>/</span> <?=h($person['display_name'])?></div>
<div class="page-heading"><div><span class="eyebrow">STAFF DIRECTORY / PROFILE</span><h1><?=h($person['display_name'])?></h1><p><?=h($person['job_title'])?> · <?=h($person['department'])?></p></div><?php if((int)$person['id']===(int)$user['id']): ?><a class="button" href="/profile_edit.php">Edit my profile</a><?php elseif (!$isContact): ?><a class="button" href="/contact_add.php?u=<?=urlencode($person['username'])?>">Add to my contacts</a><?php else: ?><span class="head-pill">IN MY CONTACTS</span><?php endif; ?></div>
<div class="columns-main"><section class="panel"><span class="eyebrow">ABOUT THIS COLLEAGUE</span><h2>About me</h2><div class="profile-about"><?php
// Profile text is retained with its original formatting.
echo nl2br($person['about_me']);
?></div></section><aside class="side-stack"><section class="panel side-note"><span class="eyebrow">COLLEAGUE PROFILE</span><div class="profile-grid"><div><span>Username</span><strong><?=h($person['username'])?></strong></div><div><span>Role</span><strong><?=h($person['role'])?></strong></div></div></section><section class="panel side-note"><span class="eyebrow">MY COLLEAGUES</span><h2>Contacts</h2><?php if ($contacts): foreach($contacts as $contact): ?><p><a href="/profile.php?u=<?=urlencode($contact['username'])?>"><?=h($contact['display_name'])?></a></p><?php endforeach; else: ?><p class="muted">No colleagues saved yet.</p><?php endif; ?></section></aside></div>
<?php render_footer(); ?>
