<?php
require __DIR__ . '/inc/bootstrap.php';
$user=require_login();
if($_SERVER['REQUEST_METHOD']==='POST'){
  $about=trim((string)($_POST['about_me']??''));
  if(strlen($about)>5000){notice('Profile text is too long.');go('/profile_edit.php');}
  $st=db()->prepare('UPDATE staff_profiles SET about_me=? WHERE user_id=?');
  $st->execute([$about,$user['id']]);
  notice('Your directory profile has been updated.');
  go('/profile.php?u='.urlencode($user['username']));
}
$st=db()->prepare('SELECT display_name,job_title,about_me FROM staff_profiles WHERE user_id=?');
$st->execute([$user['id']]);$p=$st->fetch();
render_header('Edit directory profile','directory.php');
?>
<div class="breadcrumb"><a href="/profile.php?u=<?=urlencode($user['username'])?>">← My directory profile</a></div>
<div class="page-heading"><div><span class="eyebrow">STAFF DIRECTORY / PROFILE MANAGEMENT</span><h1>Edit my profile</h1><p>Keep your colleagues informed about your role and responsibilities.</p></div></div>
<section class="panel narrow"><form method="post" class="form-grid"><label>Display name<input disabled value="<?=h($p['display_name'])?>"></label><label>Job title<input disabled value="<?=h($p['job_title'])?>"></label><label>About me<textarea name="about_me" rows="8" maxlength="5000" placeholder="Introduce yourself to colleagues..." required><?=h($p['about_me'])?></textarea></label><button class="button">Save profile</button></form></section>
<?php render_footer(); ?>
