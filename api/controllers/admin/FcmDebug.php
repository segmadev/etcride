<?php
require_once ROOT . 'functions/BaseController.php';

class FcmDebug extends BaseController
{
    /**
     * GET /admin/fcm/status
     * Returns a full diagnostic report — path resolution, file existence,
     * JSON validity, and whether a token can be obtained from Google.
     */
    public function status(): void
    {
        $rawPath     = $_ENV['FCM_SERVICE_ACCOUNT_PATH'] ?? '';
        $projectId   = $_ENV['FCM_PROJECT_ID'] ?? '';
        $resolvedPath = $rawPath;

        if (!empty($rawPath) && !file_exists($rawPath)) {
            $candidate = defined('ROOT') ? ROOT . ltrim($rawPath, '/\\') : $rawPath;
            if (file_exists($candidate)) $resolvedPath = $candidate;
        }

        $fileExists  = !empty($resolvedPath) && file_exists($resolvedPath);
        $jsonValid   = false;
        $hasPK       = false;
        $hasEmail    = false;

        if ($fileExists) {
            $sa = json_decode((string) file_get_contents($resolvedPath), true);
            $jsonValid = is_array($sa);
            $hasPK    = $jsonValid && !empty($sa['private_key']);
            $hasEmail = $jsonValid && !empty($sa['client_email']);
        }

        // Attempt token fetch (hits Google — real network call)
        $tokenResult = 'not attempted';
        if ($fileExists && $jsonValid && $hasPK && $hasEmail && $projectId) {
            // Temporarily force cache miss so we always get a fresh result
            $cacheFile = sys_get_temp_dir() . '/etcride_fcm_token.json';
            $backup    = null;
            if (file_exists($cacheFile)) {
                $backup = file_get_contents($cacheFile);
                unlink($cacheFile);
            }

            $token = $this->callGetFcmAccessToken();
            $tokenResult = $token ? 'success — token obtained' : 'FAILED — check error_log';

            // Restore cache
            if ($backup !== null) file_put_contents($cacheFile, $backup);
        }

        // Token registration stats
        $customerTokens = $this->db->query("SELECT COUNT(*) FROM users    WHERE fcm_token IS NOT NULL AND fcm_token <> ''")->fetchColumn();
        $driverTokens   = $this->db->query("SELECT COUNT(*) FROM drivers  WHERE fcm_token IS NOT NULL AND fcm_token <> ''")->fetchColumn();

        echo utilities::apiMessage('FCM status', 200, [
            'project_id'          => $projectId ?: '(not set)',
            'path_in_env'         => $rawPath ?: '(not set)',
            'path_resolved'       => $resolvedPath ?: '(same as env)',
            'file_exists'         => $fileExists,
            'json_valid'          => $jsonValid,
            'has_private_key'     => $hasPK,
            'has_client_email'    => $hasEmail,
            'access_token_test'   => $tokenResult,
            'fcm_enabled_setting' => $this->setting('fcm_enabled', '1'),
            'customers_with_token'=> (int) $customerTokens,
            'drivers_with_token'  => (int) $driverTokens,
        ]);
    }

    /**
     * POST /admin/fcm/test
     * Body: { "token": "<device_fcm_token>", "title": "...", "body": "..." }
     * Sends a real FCM push to the given device token.
     */
    public function test(): void
    {
        $deviceToken = $this->str('token');
        $title       = $this->str('title') ?: 'FCM Test';
        $body        = $this->str('body')  ?: 'This is a test push from EtcRide admin.';

        if (!$deviceToken) {
            echo utilities::apiMessage('token is required.', 422);
            return;
        }

        $projectId = $_ENV['FCM_PROJECT_ID'] ?? '';
        if (!$projectId) {
            echo utilities::apiMessage('FCM_PROJECT_ID not set in .env', 500);
            return;
        }

        $accessToken = $this->callGetFcmAccessToken();
        if (!$accessToken) {
            echo utilities::apiMessage('Could not obtain FCM access token — check error_log for [FCM] entries.', 500);
            return;
        }

        $payload = json_encode([
            'message' => [
                'token'        => $deviceToken,
                'notification' => ['title' => $title, 'body' => $body],
                'data'         => ['type' => 'fcm_test', 'sent_at' => (string) time()],
            ],
        ]);

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
        $ch  = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_TIMEOUT    => 15,
        ]);
        $result   = (string) curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlErr  = curl_error($ch);
        curl_close($ch);

        $decoded = json_decode($result, true);

        if ($httpCode === 200) {
            echo utilities::apiMessage('Push sent successfully.', 200, [
                'fcm_message_id' => $decoded['name'] ?? null,
                'http_code'      => $httpCode,
            ]);
        } else {
            error_log('[FCM] test push failed (' . $httpCode . '): ' . $result);
            echo utilities::apiMessage('Push failed — see error_log.', 500, [
                'http_code' => $httpCode,
                'fcm_error' => $decoded['error'] ?? $result,
                'curl_error'=> $curlErr ?: null,
            ]);
        }
    }

    /**
     * Calls the private getFcmAccessToken() via Reflection so the debug
     * controller can reuse it without duplicating the JWT logic.
     */
    private function callGetFcmAccessToken(): ?string
    {
        try {
            $ref    = new ReflectionMethod(BaseController::class, 'getFcmAccessToken');
            $ref->setAccessible(true);
            return $ref->invoke($this);
        } catch (Throwable $e) {
            error_log('[FCM] callGetFcmAccessToken reflection error: ' . $e->getMessage());
            return null;
        }
    }
}
