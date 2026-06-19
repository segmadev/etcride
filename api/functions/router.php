<?php
require_once ROOT . "functions/utilities.php";

class Router
{
    private array $routes = [];
    private string $prefix = '';
    private bool $groupAuth = false;
    private string $groupAuthType = 'user';
    private ?array $groupMethods = null;
    private array $groupStack = [];

    /**
     * Register a new route or multiple routes.
     *
     * @param string|array $paths
     * @param string $handler
     * @param array|string $methods
     * @param bool $authRequired
     */
    public function register($paths, string $handler, $methods = 'GET', bool $authRequired = false): void
    {
        $methods = is_array($methods) ? $methods : [$methods];
        $paths = is_array($paths) ? $paths : [$paths];
        foreach ($paths as $path) {
            $fullPath = $this->prefix !== '' ? rtrim($this->prefix, '/') . '/' . ltrim($path, '/') : $path;
            // Normalise: strip trailing slash unless the path is root "/"
            if ($fullPath !== '/') $fullPath = rtrim($fullPath, '/');
            $routeMethods = $methods;
            if ($this->groupMethods && $methods === ['GET']) {
                $routeMethods = $this->groupMethods;
            }
            // Key by METHOD:path so different verbs on the same path don't overwrite each other
            foreach ($routeMethods as $m) {
                $this->routes[strtoupper($m) . ':' . $fullPath] = [
                    'handler'     => $handler,
                    'methods'     => [strtoupper($m)],
                    'authRequired'=> $authRequired || $this->groupAuth,
                    'authType'    => $this->groupAuthType,
                ];
            }
        }
    }

    public function get($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, 'GET', $authRequired);
        return $this;
    }

    public function post($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, 'POST', $authRequired);
        return $this;
    }

    public function put($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, 'PUT', $authRequired);
        return $this;
    }

    public function delete($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, 'DELETE', $authRequired);
        return $this;
    }

    public function options($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, 'OPTIONS', $authRequired);
        return $this;
    }

    public function any($paths, string $handler, bool $authRequired = false): self
    {
        $this->register($paths, $handler, ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], $authRequired);
        return $this;
    }

    public function map(array $methods, $paths, string $handler, bool $authRequired = false): void
    {
        $this->register($paths, $handler, $methods, $authRequired);
    }

    public function getpost($paths, string $handler, bool $authRequired = false): self
    {
        $this->map(['GET','POST'], $paths, $handler, $authRequired);
        return $this;
    }

    public function group(string $prefix, callable $callback, $options = false): void
    {
        $prevPrefix = $this->prefix;
        $prevAuth = $this->groupAuth;
        $prevMethods = $this->groupMethods;
        $prevAuthType = $this->groupAuthType;
        $this->prefix = $prefix;
        $authRequired = false;
        $methods = null;
        if (is_bool($options)) {
            $authRequired = $options;
        } elseif (is_array($options)) {
            $authRequired = $options['auth'] ?? false;
            $methods = $options['methods'] ?? null;
            $this->groupAuthType = isset($options['authType']) && is_string($options['authType']) ? $options['authType'] : 'user';
        }
        $this->groupAuth = $authRequired;
        $this->groupMethods = is_array($methods) ? $methods : null;
        $callback($this);
        $this->prefix = $prevPrefix;
        $this->groupAuth = $prevAuth;
        $this->groupMethods = $prevMethods;
        $this->groupAuthType = $prevAuthType;
    }

    public function with(string $prefix, $options = false): self
    {
        $this->groupStack[] = [$this->prefix, $this->groupAuth, $this->groupMethods, $this->groupAuthType];
        $this->prefix = $prefix;
        $authRequired = false;
        $methods = null;
        if (is_bool($options)) {
            $authRequired = $options;
        } elseif (is_array($options)) {
            $authRequired = $options['auth'] ?? false;
            $methods = $options['methods'] ?? null;
            $this->groupAuthType = isset($options['authType']) && is_string($options['authType']) ? $options['authType'] : 'user';
        }
        $this->groupAuth = $authRequired;
        $this->groupMethods = is_array($methods) ? $methods : null;
        return $this;
    }

    public function end(): self
    {
        if (!empty($this->groupStack)) {
            [$this->prefix, $this->groupAuth, $this->groupMethods, $this->groupAuthType] = array_pop($this->groupStack);
        }
        return $this;
    }

    /**
     * Dispatch the request to the appropriate controller and action.
     *
     * @param string|null $path
     */
    public function dispatch(string $path = null): void
    {
        $path = $path ?? PATH ?? "/";
        $contentType = $_SERVER['CONTENT_TYPE'] ?? ($_SERVER['HTTP_CONTENT_TYPE'] ?? '');
        $isJsonContent = stripos($contentType, 'application/json') !== false;
        // Also try JSON parse when $_POST is empty and body looks like JSON (handles
        // cases where Content-Type header is missing or stripped by a proxy).
        $shouldTryJson = $isJsonContent || empty($_POST);
        if ($shouldTryJson) {
            $rawBody = file_get_contents('php://input');
            if (is_string($rawBody) && $rawBody !== '') {
                $json = json_decode($rawBody, true);
                if (is_array($json)) {
                    foreach ($json as $key => $value) {
                        if (!array_key_exists($key, $_POST)) {
                            $_POST[$key] = $value;
                        }
                    }
                }
            }
        }
        // Handle CORS preflight before route matching
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            $this->handleOptions($this->getAllowedMethodsForPath($path));
            return;
        }

        $matchedRoute = $this->matchRoute($path);

        if (!$matchedRoute) {
            // Check if the path exists but with a different method (405 vs 404)
            if ($this->pathHasAnyMethod($path)) {
                utilities::apiMessage("Method not allowed", 405);
            } else {
                utilities::apiMessage("Not Found", 404);
            }
            exit;
        }

        [$route, $parameters, $paramsAssoc] = $matchedRoute;
        $handler = $route['handler'];
        $authRequired = $route['authRequired'];
        $authType = $route['authType'] ?? 'user';

        // Check if authentication is required
        if ($authRequired) {
            $this->checkAuth($authType);
        }

        [$controllerName, $actionDefinition] = explode("@", $handler);

        // Extract action and additional parameters
        $actionParts = explode('|', $actionDefinition);
        $action = array_shift($actionParts);

        if ($authType === 'admin') {
            $isAdminPath = strpos($controllerName, 'admin/') === 0;
            if (!$isAdminPath) {
                utilities::apiMessage("Invalid admin handler", 403);
                exit;
            }
        }

        $controllerFile = "controllers/$controllerName.php";
        if (!file_exists($controllerFile)) {
            utilities::apiMessage("Controller not found", 404);
            exit;
        }
        require_once $controllerFile;

        $className = $controllerName;
        if (str_contains($className, '/')) {
            $parts = explode('/', $className);
            $className = end($parts);
        }
        if (!class_exists($className)) {
            $alt = ucfirst($controllerName);
            if (str_contains($alt, '/')) {
                $parts = explode('/', $alt);
                $alt = end($parts);
            }
            if (class_exists($alt)) {
                $className = $alt;
            } else {
                utilities::apiMessage("Controller class not found", 500);
                exit;
            }
        }
        $controller = new $className();

        try {
            $response = count($parameters) > 0
                ? $controller->$action(...$parameters)
                : $controller->$action();

            echo $response;
        } catch (Throwable $e) {
            error_log($e);
            utilities::apiMessage("Int An error occurred", 500);
        }
    }

    /**
     * Match the given path to a registered route.
     *
     * @param string $path
     * @return array|null
     */
    private function getRoutePath(string $key): string
    {
        $pos = strpos($key, ':');
        return $pos !== false ? substr($key, $pos + 1) : $key;
    }

    private function pathMatchesPattern(string $path, string $routePath): bool
    {
        $pattern = preg_replace_callback('/:([A-Za-z_][A-Za-z0-9_]*)/', fn($m) => '(?P<' . $m[1] . '>[^/]+)', $routePath);
        return (bool) preg_match('#^' . $pattern . '$#', $path);
    }

    private function pathHasAnyMethod(string $path): bool
    {
        foreach ($this->routes as $key => $_) {
            if ($this->pathMatchesPattern($path, $this->getRoutePath($key))) {
                return true;
            }
        }
        return false;
    }

    private function getAllowedMethodsForPath(string $path): array
    {
        $methods = [];
        foreach ($this->routes as $key => $_) {
            $routePath = $this->getRoutePath($key);
            if ($this->pathMatchesPattern($path, $routePath)) {
                $pos = strpos($key, ':');
                if ($pos !== false) {
                    $methods[] = substr($key, 0, $pos);
                }
            }
        }
        return array_unique($methods) ?: ['GET', 'POST', 'PUT', 'DELETE'];
    }

    private function matchRoute(string $path): ?array
    {
        $requestMethod = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        // Collect all routes whose method prefix matches (or '*' wildcard)
        $candidates = [];
        foreach ($this->routes as $key => $details) {
            $colonPos = strpos($key, ':');
            if ($colonPos !== false) {
                $routeMethod = substr($key, 0, $colonPos);
                $routePath   = substr($key, $colonPos + 1);
            } else {
                // Legacy path-only keys: check methods array
                $routeMethod = null;
                $routePath   = $key;
            }
            if ($routeMethod !== null && $routeMethod !== $requestMethod) {
                continue; // skip wrong-method entries quickly
            }
            $candidates[] = [$routePath, $details];
        }

        foreach ($candidates as [$routePath, $details]) {
            $routePattern = preg_replace_callback('/:([A-Za-z_][A-Za-z0-9_]*)/', function ($m) {
                return '(?P<' . $m[1] . '>[^/]+)';
            }, $routePath);
            $routePattern = '#^' . $routePattern . '$#';
            if (preg_match($routePattern, $path, $matches)) {
                $paramsAssoc = [];
                foreach ($matches as $k => $v) {
                    if (!is_int($k)) {
                        $paramsAssoc[$k] = $v;
                    }
                }
                foreach ($paramsAssoc as $k => $v) {
                    $_GET[$k] = $v;
                }
                return [$details, array_values($paramsAssoc), $paramsAssoc];
            }
        }

        return null;
    }


    /**
     * Resolve additional parameters for the action.
     *
     * @param array $actionParts
     * @return array
     */
    private function resolveParameters(array $actionParts): array
    {
        $parameters = [];
        foreach ($actionParts as $part) {
            if (preg_match("/^'(.*)'$/", $part, $matches)) {
                $parameters[] = $matches[1]; // Extract string values without quotes
            } elseif (isset($GLOBALS[$part])) {
                $parameters[] = $GLOBALS[$part]; // Use global variable values if defined
            }
        }
        return $parameters;
    }

    /**
     * Check if the user is authenticated.
     */
    private function checkAuth(string $type = 'user'): void
    {
        $className = null;

        if ($type === 'admin') {
            if (!class_exists('admin') && file_exists('controllers/admin/admin.php')) {
                require_once 'controllers/admin/admin.php';
            }
            $className = class_exists('admin') ? 'admin' : (class_exists('Admin') ? 'Admin' : null);
        } elseif ($type === 'driver') {
            if (!class_exists('driver') && file_exists('controllers/driver.php')) {
                require_once 'controllers/driver.php';
            }
            $className = class_exists('driver') ? 'driver' : null;
        } else {
            if (!class_exists('user') && file_exists('controllers/user.php')) {
                require_once 'controllers/user.php';
            }
            $className = class_exists('user') ? 'user' : (class_exists('User') ? 'User' : null);
        }

        if ($className === null) {
            utilities::apiMessage("Auth controller not found", 500);
            exit;
        }

        $guard = new $className();

        if ($type === 'admin' && method_exists($guard, 'set_admin')) {
            $guard->set_admin();
        } elseif ($type === 'driver' && method_exists($guard, 'set_driver')) {
            $guard->set_driver();
        } elseif (method_exists($guard, 'set_user')) {
            $guard->set_user();
        } else {
            utilities::apiMessage("Auth method not found", 500);
            exit;
        }
    }

    private function handleOptions(array $methods): void
    {
        header('Access-Control-Allow-Methods: ' . implode(',', $methods));
        header('Access-Control-Allow-Headers: Authorization, Content-Type');
        utilities::apiMessage('OK', 204);
        exit;
    }
}
