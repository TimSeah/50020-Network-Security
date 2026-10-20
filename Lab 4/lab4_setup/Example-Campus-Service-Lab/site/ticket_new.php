<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
render_header('New service request', 'tickets.php');
?>
<div class="breadcrumb"><a href="/tickets.php">← Service tickets</a><span>/</span> New request</div>
<div class="page-heading"><div><span class="eyebrow">SERVICE OPERATIONS / NEW REQUEST</span><h1>Submit a service request</h1><p>Create a ticket and share its progress with the service team.</p></div></div>
<section class="panel" style="max-width:800px"><form method="post" action="/ticket_action.php" class="form-grid">
<input type="hidden" name="action" value="create">
<label>Request title<input name="title" required maxlength="180" placeholder="Summary of the service request"></label>
<label>Details<textarea name="description" required rows="5" maxlength="2000"></textarea></label>
<label>Priority<select name="priority"><option value="low">Low</option><option value="medium" selected>Medium</option><option value="high">High</option></select></label>
<label>Visibility<select name="visibility"><option value="private">Private — only assigned owner</option><option value="public">Public — shared staff request</option></select></label>
<button class="button" type="submit">Submit request</button></form></section>
<?php render_footer(); ?>
