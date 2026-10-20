<?php
$dir = '/var/www/example-campus-training/share-pages';
$docs = [];
foreach (glob($dir . '/*.json') ?: [] as $file) {
    $meta = json_decode((string)file_get_contents($file), true);
    if (is_array($meta) && isset($meta['id'],$meta['title'])) $docs[] = $meta;
}
usort($docs,fn($a,$b) => strcmp($b['created'] ?? '', $a['created'] ?? ''));
$base = 'http://' . ($_SERVER['HTTP_HOST'] ?? '127.0.0.1:8082');
$draft = '<!doctype html>' . "
" . '<html lang="en">' . "
" . '<head><meta charset="utf-8"><title>Campus document</title></head>' . "
" . '<body><h1>Service handover notes</h1><p>Please review the updated operational notes.</p></body>' . "
" . '</html>';
function e($s) {return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');}
?>
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Campus Document Share</title><link rel="stylesheet" href="/share.css"></head><body>
<header class="masthead"><a href="/">Campus Document Share</a><span>Team workspace</span></header>
<main class="wide"><div class="intro"><span class="eyebrow">DOCUMENTS / SHARING</span><h1>Publish a shared document</h1><p>Prepare a self-contained HTML document for colleagues, then share the generated viewing link.</p></div>
<?php if(isset($_GET['published'])): $id=(string)$_GET['published']; if(preg_match('/^[a-f0-9]{16}$/',$id) && is_file($dir . '/' . $id . '.json')): ?><div class="confirmation"><strong>Document published.</strong><p>Share this viewing link with your team:</p><input id="new-link" value="<?=e($base.'/view.php?doc='.$id)?>" readonly onclick="this.select()"><a href="/view.php?doc=<?=e($id)?>" target="_blank" rel="noopener">Open document ↗</a></div><?php endif; endif; ?>
<div class="layout"><section class="panel"><h2>New document</h2><form method="post" action="/publish.php" class="editor"><label>Document title<input name="title" maxlength="100" value="October handover notes" required></label><label>HTML document source<textarea name="html" rows="17" maxlength="18000" required spellcheck="false"><?=e($draft)?></textarea></label><p class="hint">HTML can include presentation elements and embedded media. Colleagues will see the published page when they open its viewing link.</p><button type="submit">Publish document →</button></form></section>
<aside class="panel"><h2>Recently published</h2><?php if (!$docs): ?><p class="muted">No documents have been published yet.</p><?php else: ?><ul class="documents"><?php foreach(array_slice($docs,0,20) as $item): ?><li><a href="/view.php?doc=<?=e($item['id'])?>" target="_blank" rel="noopener"><?=e($item['title'])?></a><small><?=e($item['created']??'')?></small></li><?php endforeach; ?></ul><?php endif; ?></aside></div>
</main><footer>Campus Document Share · Team knowledge workspace</footer></body></html>
