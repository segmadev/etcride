<?php
require_once ROOT . 'functions/BaseController.php';

class Kyc extends BaseController
{
    private string $uploadDir = ROOT . 'api/uploads/drivers/';

    private function saveUpload(string $field, string $prefix): ?string
    {
        if (empty($_FILES[$field]['name']) || $_FILES[$field]['error'] !== UPLOAD_ERR_OK) return null;
        $allowed = ['image/jpeg', 'image/png', 'image/webp'];
        $mime    = mime_content_type($_FILES[$field]['tmp_name']);
        if (!in_array($mime, $allowed, true) || $_FILES[$field]['size'] > 5 * 1024 * 1024) return null;
        $ext      = strtolower(pathinfo($_FILES[$field]['name'], PATHINFO_EXTENSION));
        $filename = $prefix . '_' . uniqid() . '.' . $ext;
        if (!is_dir($this->uploadDir)) mkdir($this->uploadDir, 0755, true);
        move_uploaded_file($_FILES[$field]['tmp_name'], $this->uploadDir . $filename);
        return $filename;
    }

    private function photoUrl(?string $f): ?string
    {
        if (!$f) return null;
        $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        return $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . '/uploads/drivers/' . $f;
    }

    public function submit(): void
    {
        $me = BaseController::$authDriver;
        $err = $this->requireFields(['kyc_id_type', 'kyc_id_number']);
        if ($err) { echo $err; return; }

        $front = $this->saveUpload('kyc_id_front', $me['id'] . '_kf');
        $back  = $this->saveUpload('kyc_id_back',  $me['id'] . '_kb');
        if ($front === null && $back === null) {
            echo utilities::apiMessage('Please upload at least one ID image.', 422);
            return;
        }

        $fields = [
            'kyc_id_type'   => $this->str('kyc_id_type'),
            'kyc_id_number' => $this->str('kyc_id_number'),
            'kyc_status'    => 'pending',
        ];
        if ($front) $fields['kyc_id_front'] = $front;
        if ($back)  $fields['kyc_id_back']  = $back;

        $this->update('drivers', $fields, "id = '{$me['id']}'");
        $this->logActivity('driver', $me['id'], 'kyc_submitted');

        echo utilities::apiMessage('KYC submitted.', 200, [
            'kyc_status'    => 'pending',
            'kyc_front_url' => $this->photoUrl($front),
            'kyc_back_url'  => $this->photoUrl($back),
        ]);
    }
}

