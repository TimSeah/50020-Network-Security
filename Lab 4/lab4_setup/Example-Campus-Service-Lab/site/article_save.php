<?php
require __DIR__.'/inc/bootstrap.php';
$user=require_login();
$id=filter_input(INPUT_GET,'id',FILTER_VALIDATE_INT);
if(!$id){http_response_code(400);exit('Invalid article');}
$st=db()->prepare('SELECT id FROM articles WHERE id=?');$st->execute([$id]);
if(!$st->fetchColumn()){http_response_code(404);exit('Article not found');}
$st=db()->prepare('INSERT IGNORE INTO article_bookmarks (user_id,article_id) VALUES (?,?)');
$st->execute([$user['id'],$id]);
notice('Article saved to your reading list.');
go('/knowledge.php');
