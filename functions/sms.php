<?php
/**
 * SMS helper — configurable provider (Termii or stub)
 * Config keys in settings table:
 *   sms_provider   : 'termii' | '' (blank = log only)
 *   sms_api_key    : provider API key
 *   sms_sender_id  : e.g. 'OE Alert'
 *
 * Usage from any BaseController method:
 *   require_once ROOT . 'functions/sms.php';
 *   Sms::setDb($this->db);
 *   Sms::send($phone, $message);
 *
 * Debug log: logs/sms.log
 */
class Sms
{
    private static ?PDO $pdo    = null;
    private static string $logFile = '';

    /** Inject the PDO connection from BaseController before calling send(). */
    public static function setDb(PDO $db): void
    {
        self::$pdo = $db;
    }

    public static function send(string $to, string $message): bool
    {
        self::$logFile = defined('ROOT') ? ROOT . 'logs/sms.log' : __DIR__ . '/../logs/sms.log';

        $raw      = $to;
        $to       = self::normalise($to);
        $provider = self::setting('sms_provider', '');
        $apiKey   = self::setting('sms_api_key', '');
        $sender   = self::setting('sms_sender_id', 'ETCRide');

        self::log([
            'event'         => 'SMS_SEND_ATTEMPT',
            'raw_to'        => $raw,
            'normalised_to' => $to,
            'provider'      => $provider ?: '(blank — stub mode)',
            'sender'        => $sender,
            'api_key_set'   => ($apiKey !== '') ? 'YES (length=' . strlen($apiKey) . ')' : 'NO — key is empty',
            'message'       => $message,
        ]);

        if ($provider === 'termii' && $apiKey !== '') {
            return self::sendTermii($to, $message, $apiKey, $sender);
        }

        // Stub mode — SMS not sent, only logged
        self::log([
            'event'  => 'SMS_STUB',
            'reason' => $provider === ''
                ? 'sms_provider is blank in settings table'
                : "provider='$provider' but api_key is empty",
            'to'     => $to,
        ]);
        return true;
    }

    private static function sendTermii(string $to, string $message, string $apiKey, string $sender): bool
    {
        $payload = json_encode([
            'to'      => $to,
            'from'    => $sender,
            'sms'     => $message,
            'type'    => 'plain',
            'channel' => 'dnd',
            'api_key' => $apiKey,
        ]);

        self::log([
            'event'    => 'TERMII_REQUEST',
            'endpoint' => 'https://api.ng.termii.com/api/sms/send',
            'to'       => $to,
            'from'     => $sender,
            'message'  => $message,
        ]);

        $ch = curl_init('https://api.ng.termii.com/api/sms/send');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_TIMEOUT        => 10,
        ]);
        $resp     = curl_exec($ch);
        $curlErr  = curl_errno($ch);
        $curlMsg  = curl_error($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($curlErr) {
            self::log([
                'event'      => 'TERMII_CURL_ERROR',
                'curl_errno' => $curlErr,
                'curl_error' => $curlMsg,
                'result'     => 'FAILED',
            ]);
            return false;
        }

        $data    = json_decode($resp, true);
        $success = isset($data['message_id']) || (($data['code'] ?? '') === 'ok');

        self::log([
            'event'        => 'TERMII_RESPONSE',
            'http_code'    => $httpCode,
            'raw_response' => $resp,
            'result'       => $success ? 'SUCCESS' : 'FAILED',
        ]);

        return $success;
    }

    private static function normalise(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone);

        // Already in international format 2347XXXXXXXXX
        if (str_starts_with($digits, '234') && strlen($digits) === 13) {
            return $digits;
        }
        // Local format 07XXXXXXXXX
        if (str_starts_with($digits, '0') && strlen($digits) === 11) {
            return '234' . substr($digits, 1);
        }

        return $digits;
    }

    private static function setting(string $key, string $default = ''): string
    {
        if (self::$pdo === null) {
            self::log([
                'event' => 'SMS_DB_MISSING',
                'key'   => $key,
                'note'  => 'Sms::setDb() was never called — call it before Sms::send()',
            ]);
            return $default;
        }
        try {
            $stmt = self::$pdo->prepare("SELECT config_value FROM settings WHERE config_key = ? LIMIT 1");
            $stmt->execute([$key]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            return $row ? (string) $row['config_value'] : $default;
        } catch (Exception $e) {
            self::log(['event' => 'SMS_DB_ERROR', 'key' => $key, 'error' => $e->getMessage()]);
            return $default;
        }
    }

    private static function log(array $data): void
    {
        $logFile = self::$logFile ?: (defined('ROOT') ? ROOT . 'logs/sms.log' : __DIR__ . '/../logs/sms.log');
        $dir = dirname($logFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        $line = '[' . date('Y-m-d H:i:s') . '] ' . json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL;
        file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
    }
}
