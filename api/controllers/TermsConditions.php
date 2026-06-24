<?php
require_once ROOT . 'functions/BaseController.php';

class TermsConditions extends BaseController
{
    // ── GET /content/terms-conditions ──────────────────────────────────────────
    public function getTermsAndConditions(): void
    {
        $tcSetting = $this->getall('settings', 'config_key = ?', ['terms_and_conditions']);
        $ppSetting = $this->getall('settings', 'config_key = ?', ['privacy_policy']);

        $tcValue = is_array($tcSetting) ? $tcSetting['config_value'] : '';
        $ppValue = is_array($ppSetting) ? $ppSetting['config_value'] : '';
        $tcUpdatedAt = is_array($tcSetting) ? $tcSetting['updated_at'] : null;

        echo utilities::apiMessage('Terms & Conditions and Privacy Policy retrieved', 200, [
            'terms_and_conditions' => $tcValue,
            'privacy_policy'       => $ppValue,
            'terms_version'        => $tcUpdatedAt ?? date('Y-m-d H:i:s'),
        ]);
    }

    // ── POST /auth/accept-terms (customer) ──────────────────────────────────────
    public function acceptTerms(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $session = $this->getall('user_sessions', 'token = ?', [$token]);
        if (!is_array($session)) {
            echo utilities::apiMessage('Invalid or expired session.', 401);
            return;
        }

        $user = $this->getall('users', 'id = ? AND status = 1', [$session['user_id']]);
        if (!is_array($user)) {
            echo utilities::apiMessage('User not found or inactive.', 401);
            return;
        }

        $tcSetting = $this->getall('settings', '`key` = ?', ['terms_and_conditions']);
        if (!is_array($tcSetting)) {
            echo utilities::apiMessage('Terms & Conditions not configured.', 500);
            return;
        }

        $termsVersion = $tcSetting['updated_at'] ?? date('Y-m-d H:i:s');

        try {
            // Check if already accepted this version
            $existing = $this->getall(
                'terms_conditions_acceptances',
                'user_type = ? AND user_id = ? AND terms_version_at = ?',
                ['customer', $user['id'], $termsVersion]
            );

            if (is_array($existing)) {
                echo utilities::apiMessage('Terms & Conditions already accepted for this version.', 200);
                return;
            }

            // Delete old acceptance record and create new one
            $this->db->prepare('DELETE FROM terms_conditions_acceptances WHERE user_type = ? AND user_id = ?')
                ->execute(['customer', $user['id']]);

            $acceptanceId = $this->generateId();
            $ipAddr = $_SERVER['REMOTE_ADDR'] ?? '';
            $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';

            $stmt = $this->db->prepare(
                'INSERT INTO terms_conditions_acceptances (id, user_type, user_id, accepted_at, terms_version_at, ip_address, user_agent)
                 VALUES (?, ?, ?, NOW(), ?, ?, ?)'
            );
            $stmt->execute([$acceptanceId, 'customer', $user['id'], $termsVersion, $ipAddr, $userAgent]);

            $this->logActivity('customer', $user['id'], 'terms_accepted', ['version' => $termsVersion]);

            echo utilities::apiMessage('Terms & Conditions accepted.', 200);
        } catch (Exception $e) {
            error_log("ERROR: TermsConditions::acceptTerms - " . $e->getMessage());
            echo utilities::apiMessage('Error accepting terms: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /profile/terms-status (customer) ────────────────────────────────────
    public function getTermsStatus(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $session = $this->getall('user_sessions', 'token = ?', [$token]);
        if (!is_array($session)) {
            echo utilities::apiMessage('Invalid or expired session.', 401);
            return;
        }

        $user = $this->getall('users', 'id = ? AND status = 1', [$session['user_id']]);
        if (!is_array($user)) {
            echo utilities::apiMessage('User not found or inactive.', 401);
            return;
        }

        $tcSetting = $this->getall('settings', '`key` = ?', ['terms_and_conditions']);
        if (!is_array($tcSetting)) {
            echo utilities::apiMessage('Terms & Conditions not configured.', 500);
            return;
        }

        $termsVersion = $tcSetting['updated_at'] ?? date('Y-m-d H:i:s');

        $acceptance = $this->getall(
            'terms_conditions_acceptances',
            'user_type = ? AND user_id = ?',
            ['customer', $user['id']]
        );

        $hasAccepted = is_array($acceptance) && $acceptance['terms_version_at'] === $termsVersion;

        echo utilities::apiMessage('Terms status retrieved', 200, [
            'has_accepted_latest' => $hasAccepted,
            'current_version'     => $termsVersion,
            'accepted_version'    => is_array($acceptance) ? $acceptance['terms_version_at'] : null,
            'accepted_at'         => is_array($acceptance) ? $acceptance['accepted_at'] : null,
        ]);
    }

    // ── POST /driver/accept-terms ──────────────────────────────────────────────
    public function driverAcceptTerms(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $session = $this->getall('driver_sessions', 'token = ?', [$token]);
        if (!is_array($session)) {
            echo utilities::apiMessage('Invalid or expired session.', 401);
            return;
        }

        $driver = $this->getall('drivers', 'id = ? AND status = 1', [$session['driver_id']]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 401);
            return;
        }

        $tcSetting = $this->getall('settings', '`key` = ?', ['terms_and_conditions']);
        if (!is_array($tcSetting)) {
            echo utilities::apiMessage('Terms & Conditions not configured.', 500);
            return;
        }

        $termsVersion = $tcSetting['updated_at'] ?? date('Y-m-d H:i:s');

        try {
            // Check if already accepted this version
            $existing = $this->getall(
                'terms_conditions_acceptances',
                'user_type = ? AND user_id = ? AND terms_version_at = ?',
                ['driver', $driver['id'], $termsVersion]
            );

            if (is_array($existing)) {
                echo utilities::apiMessage('Terms & Conditions already accepted for this version.', 200);
                return;
            }

            // Delete old acceptance record and create new one
            $this->db->prepare('DELETE FROM terms_conditions_acceptances WHERE user_type = ? AND user_id = ?')
                ->execute(['driver', $driver['id']]);

            $acceptanceId = $this->generateId();
            $ipAddr = $_SERVER['REMOTE_ADDR'] ?? '';
            $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';

            $stmt = $this->db->prepare(
                'INSERT INTO terms_conditions_acceptances (id, user_type, user_id, accepted_at, terms_version_at, ip_address, user_agent)
                 VALUES (?, ?, ?, NOW(), ?, ?, ?)'
            );
            $stmt->execute([$acceptanceId, 'driver', $driver['id'], $termsVersion, $ipAddr, $userAgent]);

            $this->logActivity('driver', $driver['id'], 'terms_accepted', ['version' => $termsVersion]);

            echo utilities::apiMessage('Terms & Conditions accepted.', 200);
        } catch (Exception $e) {
            error_log("ERROR: TermsConditions::driverAcceptTerms - " . $e->getMessage());
            echo utilities::apiMessage('Error accepting terms: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /driver/terms-status ───────────────────────────────────────────────
    public function driverGetTermsStatus(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $session = $this->getall('driver_sessions', 'token = ?', [$token]);
        if (!is_array($session)) {
            echo utilities::apiMessage('Invalid or expired session.', 401);
            return;
        }

        $driver = $this->getall('drivers', 'id = ? AND status = 1', [$session['driver_id']]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 401);
            return;
        }

        $tcSetting = $this->getall('settings', '`key` = ?', ['terms_and_conditions']);
        if (!is_array($tcSetting)) {
            echo utilities::apiMessage('Terms & Conditions not configured.', 500);
            return;
        }

        $termsVersion = $tcSetting['updated_at'] ?? date('Y-m-d H:i:s');

        $acceptance = $this->getall(
            'terms_conditions_acceptances',
            'user_type = ? AND user_id = ?',
            ['driver', $driver['id']]
        );

        $hasAccepted = is_array($acceptance) && $acceptance['terms_version_at'] === $termsVersion;

        echo utilities::apiMessage('Terms status retrieved', 200, [
            'has_accepted_latest' => $hasAccepted,
            'current_version'     => $termsVersion,
            'accepted_version'    => is_array($acceptance) ? $acceptance['terms_version_at'] : null,
            'accepted_at'         => is_array($acceptance) ? $acceptance['accepted_at'] : null,
        ]);
    }
}
