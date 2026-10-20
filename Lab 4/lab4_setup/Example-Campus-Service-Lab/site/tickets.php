<?php
require __DIR__ . '/inc/bootstrap.php';
require __DIR__ . '/inc/sql_diagnostic.php';
$user = require_login();
$q = (string)($_GET['q'] ?? '');
$records = [];
$uid = (int)$user['id'];
// Ticket search query construction.
$sql = "SELECT t.id,t.title,t.status,t.priority,t.visibility,u.username AS owner "
     . "FROM tickets t JOIN users u ON u.id=t.owner_id "
     . "WHERE (t.owner_id=$uid OR t.visibility='public') "
     . "AND t.title LIKE '%$q%' ORDER BY t.id DESC";
$conn = null;
try {
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    $conn = new mysqli((string)getenv('DB_HOST'), (string)getenv('DB_USER'),
                      (string)getenv('DB_PASSWORD'), (string)getenv('DB_NAME'));
    $conn->set_charset('utf8mb4');
    $conn->multi_query($sql);
    $first = true;
    do {
        if ($rs = $conn->store_result()) {
            if ($first) { $records = $rs->fetch_all(MYSQLI_ASSOC); }
            $rs->free();
        }
        $first = false;
        if (!$conn->more_results()) break;
    } while ($conn->next_result());
    $conn->close();
} catch (Throwable $e) {
    if ($conn instanceof mysqli) { try { $conn->close(); } catch (Throwable $ignored) {} }
    show_database_error($sql, $e);
}
render_header('Service tickets','tickets.php');
?>
<div class="page-heading"><div><span class="eyebrow">SERVICE OPERATIONS / REQUEST TRACKING</span><h1>Service tickets</h1><p>Search requests and review service updates assigned to your workspace.</p></div><a class="button" href="/ticket_new.php">New request +</a></div>
<section class="panel"><form method="get" class="search-bar"><label for="ticket-search">Search by request title</label><div class="search-inner"><input id="ticket-search" name="q" value="<?=h($q)?>" placeholder="e.g. access card, meeting room, maintenance"><button class="button" type="submit">Search requests</button><a class="button button-ghost" href="/tickets.php">Clear</a></div></form>
<div class="section-row list-header"><h2>Matching requests</h2><span class="muted"><?=count($records)?> results</span></div>
<div class="ticket-list">
<?php foreach ($records as $t): ?><a class="ticket-row" href="/ticket.php?id=<?=(int)$t['id']?>"><span class="ticket-icon">#</span><span class="ticket-primary"><strong><?=h($t['title'])?></strong><small>CASE-<?=(int)$t['id']?> · Owner <?=h($t['owner'])?> · <?=h($t['visibility'])?> visibility</small></span><span class="tag tag-<?=h($t['priority'])?>"><?=h($t['priority'])?></span><span class="chevron">›</span></a><?php endforeach; ?>
<?php if (!$records): ?><div class="empty">No matching tickets were found.</div><?php endif; ?>
</div></section>
<?php render_footer(); ?>
