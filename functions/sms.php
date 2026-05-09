<?php
/**
 * SMS helper — configurable provider (Termii or stub)
 * Config keys in settings table:
 *   sms_provider   : 'termii' | '' (blank = log only)
 *   sms_api_key    : provider API key
 *   sms_sender_id  : e.g. 'ETCRide'
 */
class Sms
{
    public static function send(string $to, string $message): bool
    {
        // Normalise Nigerian number to international format
        $to = self::normalise($to);

        $provider = self::setting('sms_provider', '');
        $apiKey   = self::setting('sms_api_key', '');
        $sender   = self::setting('sms_sender_id', 'ETCRide');

        if ($provider === 'termii' && $apiKey !== '') {
            return self::sendTermii($to, $message, $apiKey, $sender);
        }

        // Stub: log only
        error_log("[SMS STUB] To: $to | Msg: $message");
        return true;
    }

    private static function sendTermii(string $to, string $message, string $apiKey, string $sender): bool
    {
        $payload = json_encode([
            'to'           => $to,
            'from'         => $sender,
            'sms'          => $message,
            'type'         => 'plain',
            'channel'      => 'generic',
            'api_key'      => $apiKey,
        ]);

        $ch = curl_init('https://api.ng.termii.com/api/sms/send');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_TIMEOUT        => 10,
        ]);
        $resp = curl_exec($ch);
        $err  = curl_errno($ch);
        curl_close($ch);

        if ($err) {
            error_log("[SMS Termii] cURL error: $err");
            return false;
        }

        $data = json_decode($resp, true);
        return isset($data['message_id']) || (($data['code'] ?? '') === 'ok');
    }

    private static function normalise(string $phone): string
    {
        $phone = preg_replace('/\D/', '', $phone);
        if (str_starts_with($phone, '0') && strlen($phone) === 11) {
            $phone = '234' . substr($phone, 1);
        }
        return $phone;
    }

    private static function setting(string $key, string $default = ''): string
    {
        global $db;
        if (!isset($db)) return $default;
        $stmt = $db->prepare("SELECT config_value FROM settings WHERE config_key = ? LIMIT 1");
        $stmt->execute([$key]);
        $row  = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ? (string) $row['config_value'] : $default;
    }
}
