<?php
require __DIR__ . '/inc/bootstrap.php';
$user = require_login();
$q = trim((string)($_GET['q'] ?? ''));
$st = db()->prepare('SELECT id,title,category,summary FROM articles WHERE title LIKE ? OR summary LIKE ? ORDER BY id');
$st->execute(['%' . $q . '%','%' . $q . '%']);
$articles = $st->fetchAll();
$st = db()->prepare('SELECT article_id FROM article_bookmarks WHERE user_id=?');
$st->execute([$user['id']]);
$saved = array_fill_keys($st->fetchAll(PDO::FETCH_COLUMN), true);
render_header('Knowledge base','knowledge.php');
?>
<div class="page-heading"><div><span class="eyebrow">STAFF RESOURCES / HELP CENTER</span><h1>Knowledge base</h1><p>Browse procedures, reference notes and quick guides for campus service requests.</p></div><span class="head-pill">SELF-SERVICE</span></div>
<section class="hero-search"><span class="eyebrow">HOW CAN WE HELP?</span><h2>Find an answer quickly.</h2><form method="get" class="search-inner"><input name="q" aria-label="Search knowledge base" value="<?=h($q)?>" placeholder="Search policies, Wi-Fi, facilities..."><button class="button" type="submit">Find articles</button></form></section>
<section class="panel"><div class="section-row"><div><span class="eyebrow">ARTICLE DIRECTORY</span><h2><?php if ($q !== ''): ?>Results for “<?php
    echo $q;
?>”<?php else: ?>Popular help articles<?php endif; ?></h2></div><span class="muted"><?=count($articles)?> resources</span></div>
<div class="article-grid"><?php foreach ($articles as $a): ?><article class="article"><span class="eyebrow"><?=h(strtoupper($a['category']))?></span><h3><?=h($a['title'])?></h3><p><?=h($a['summary'])?></p><span class="article-footer">RESOURCE #<?=(int)$a['id']?> · <?php if(isset($saved[$a['id']])): ?><b>Saved to my list</b><?php else: ?><a href="/article_save.php?id=<?=(int)$a['id']?>">Save for later →</a><?php endif; ?></span></article><?php endforeach; ?><?php if (!$articles): ?><p class="muted">No articles matched your search.</p><?php endif; ?></div></section>
<?php render_footer(); ?>
