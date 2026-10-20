<?php
// Publisher for demonstration documents on this isolated, local web origin.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit('Method not allowed'); }
$dir='/var/www/example-campus-training/share-pages';
$title=trim((string)($_POST['title']??''));
$html=(string)($_POST['html']??'');
if ($title==='' || strlen($title)>100 || trim($html)==='' || strlen($html)>18000) {
    http_response_code(400); exit('Enter a title and HTML content within the permitted size.');
}
$files=glob($dir.'/*.json') ?: [];
if(count($files)>=40){http_response_code(409);exit('Document space is full. Reset the local workspace to publish more.');}
$id=bin2hex(random_bytes(8));
// Render exactly what the document author publishes; this is not the target portal.
if (file_put_contents($dir.'/'.$id.'.html',$html,LOCK_EX)===false) {http_response_code(500);exit('Unable to publish');}
$meta=['id'=>$id,'title'=>$title,'created'=>gmdate('Y-m-d H:i').' UTC'];
file_put_contents($dir.'/'.$id.'.json',json_encode($meta),LOCK_EX);
header('Location: /?published='.$id, true, 303);
