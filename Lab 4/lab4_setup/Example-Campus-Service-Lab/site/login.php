<?php
require __DIR__ . '/inc/bootstrap.php';
require __DIR__ . '/inc/sql_diagnostic.php';
if (current_user()) { go('/index.php'); }
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = (string)($_POST['username'] ?? ''); 
    $password = (string)($_POST['password'] ?? '');
    try {
        // Compare the submitted password digest with the stored account record.
        $submitted_hash = md5($password);
        $sql = "SELECT id,username,role FROM users WHERE username = '$username' AND password_md5 = '$submitted_hash' AND active = 1 LIMIT 1";
        $row = db()->query($sql)->fetch();
        if ($row) {
            session_regenerate_id(true);
            $_SESSION['user'] = ['id'=>(int)$row['id'], 'username'=>$row['username'], 'role'=>$row['role']];
            go('/index.php');
        }
        $error = 'Account name or password not recognized.';
    } catch (PDOException $e) {
        show_database_error($sql, $e);
    }
}
render_header('Sign in');
?>
<div class="login-layout">
 <section class="login-intro">
   <span class="eyebrow">STAFF SERVICE DESK</span>
   <h1>Your campus work,<br><em>organized in one place.</em></h1>
   <p>Track facilities requests, access service knowledge, and manage account notifications.</p>
   <div class="login-metrics"><div><strong>24 / 7</strong><span>Self-service portal</span></div><div><strong>3</strong><span>Service departments</span></div></div>
 </section>
 <section class="panel login-card">
   <span class="eyebrow">STAFF ACCESS</span><h2>Sign in to the portal</h2>
   <p class="muted">Enter your staff credentials to continue.</p>
   <?php if ($error): ?><div class="error" role="alert"><?=h($error)?></div><?php endif; ?>
   <form method="post" autocomplete="off" class="form-grid">
     <label>Username<input name="username" aria-label="Username" placeholder="e.g. alice" required></label>
     <label>Password<input type="password" name="password" aria-label="Password" placeholder="Enter password" required></label>
     <button class="button" type="submit">Sign in <span>→</span></button>
   </form>
 </section>
</div>
<?php render_footer(); ?>
