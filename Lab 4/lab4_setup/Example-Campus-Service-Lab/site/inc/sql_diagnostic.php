<?php
// Database error diagnostic view.
function show_database_error(string $statement, Throwable $error): never {
    http_response_code(500);
    header('Content-Type: text/html; charset=UTF-8');
    $esc = static fn(string $s): string => htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $message = $esc($error->getMessage());
    $query = $esc($statement);
    echo <<<HTML
<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Database error</title><style>body{background:#f4f5f7;color:#1b2734;margin:0;font:15px/1.6 Arial,sans-serif}main{max-width:1000px;margin:55px auto;background:#fff;padding:32px;border:1px solid #d8dee5;border-radius:7px}h1{font-size:25px;color:#ab2634;margin-top:0}h2{font-size:16px}pre{overflow-x:auto;white-space:pre-wrap;word-break:break-word;background:#f3f4f6;border:1px solid #dae0e6;padding:16px;border-radius:5px;font:14px/1.5 monospace}.pill{display:inline-block;border:1px solid #cfb6b8;border-radius:4px;color:#a12b37;padding:3px 9px;font-size:13px}</style></head>
<body><main><span class="pill">HTTP 500</span><h1>Database error</h1><h2>Driver message</h2><pre>{$message}</pre><h2>SQL statement</h2><pre>{$query}</pre></main></body></html>
HTML;
    exit;
}
