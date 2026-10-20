<?php
declare(strict_types=1);

// Application bootstrap and authentication session initialization.
// Use one portal hostname so users who browse to the VM IP do not create an
// IP-scoped login cookie that is absent from document-triggered requests.
// A fixed redirect target avoids trusting arbitrary Host header values.
$requestedHost = strtolower((string)(parse_url('http://' . (string)($_SERVER['HTTP_HOST'] ?? 'portal.campus.test'), PHP_URL_HOST) ?: ''));
if (PHP_SAPI !== 'cli' && $requestedHost !== 'portal.campus.test') {
    $port = (int)($_SERVER['SERVER_PORT'] ?? 80);
    $portSuffix = $port === 8081 ? ':8081' : '';
    $requestUri = (string)($_SERVER['REQUEST_URI'] ?? '/');
    // Reject protocol-relative request targets; redirect only to local paths.
    if ($requestUri === '' || $requestUri[0] !== '/' || str_starts_with($requestUri, '//')) {
        $requestUri = '/';
    }
    header('Location: http://portal.campus.test' . $portSuffix . $requestUri, true, 302);
    exit;
}

ini_set('display_errors', '0');
error_reporting(E_ALL);
session_name('CAMPUS_SESSION');
session_set_cookie_params([
    'lifetime' => 0, 'path' => '/', 'httponly' => false,
    'secure' => false, // local HTTP lab only
    'samesite' => 'Lax',
]);
if (is_dir('/var/lib/example-campus-training/sessions')) {
    session_save_path('/var/lib/example-campus-training/sessions');
}
session_start();

function db(): PDO {
    static $conn = null;
    if ($conn === null) {
        $conn = new PDO(
            'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4',
            (string)getenv('DB_USER'), (string)getenv('DB_PASSWORD'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
             PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
             PDO::ATTR_EMULATE_PREPARES => false]
        );
    }
    return $conn;
}
function h(?string $v): string { return htmlspecialchars($v ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function current_user(): ?array { return $_SESSION['user'] ?? null; }
function require_login(): array {
    $user = current_user();
    if (!$user) { header('Location: /login.php'); exit; }
    return $user;
}
function go(string $url): never { header('Location: ' . $url); exit; }
function notice(string $message): void { $_SESSION['notice'] = $message; }
function render_header(string $title, string $active = ''): void {
    $user = current_user();
    $portalOrigin = ((int)($_SERVER['SERVER_PORT'] ?? 80) === 8081) ? 'http://' . ($_SERVER['SERVER_ADDR'] ?? '127.0.0.1') : '';
    echo '<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' . h($title) . ' · Example Campus Service</title><link rel="stylesheet" href="' . $portalOrigin . '/assets/style.css"></head><body>';
    echo '<header class="top"><a class="brand" href="' . $portalOrigin . '/index.php"><span class="brand-mark">E</span><span><strong>Example Campus Service</strong><small>STAFF PORTAL</small></span></a>';
    if ($user) {
        echo '<nav aria-label="Main navigation">';
        foreach (['index.php'=>'Dashboard','tickets.php'=>'Service tickets','requests.php'=>'Access requests','knowledge.php'=>'Knowledge base','directory.php'=>'Staff directory','settings.php'=>'My settings'] as $file=>$label) {
            echo '<a ' . ($active === $file ? 'class="active" ' : '') . 'href="' . $portalOrigin . '/' . $file . '">' . $label . '</a>';
        }
        echo '</nav><div class="account"><span><b>' . h($user['username']) . '</b><small>' . h(strtoupper($user['role'])) . '</small></span><a href="' . $portalOrigin . '/logout.php" class="signout">Sign out</a></div>';
    } else { echo '<div class="header-link">Internal service workspace</div>'; }
    echo '</header><main class="container">';
    if (isset($_SESSION['notice'])) { echo '<div role="status" class="notice">' . h($_SESSION['notice']) . '</div>'; unset($_SESSION['notice']); }
}
function render_footer(): void {
    echo '</main><footer class="footer"><span>Example Campus Service</span><span>Staff service desk</span></footer></body></html>';
}
