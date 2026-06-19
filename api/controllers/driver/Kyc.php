<?php
require_once ROOT . 'functions/BaseController.php';

class Kyc extends BaseController
{
    private string $uploadDir = ROOT . 'api/uploads/drivers/';
    private int $maxUploadSize = 5242880; // 5MB

    private function preferredUploadField(array $fields): ?string
    {
        foreach ($fields as $field) {
            if (!isset($_FILES[$field])) {
                continue;
            }
            if (!empty($_FILES[$field]['name']) && (int) ($_FILES[$field]['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE) {
                return $field;
            }
            if (!empty($_FILES[$field]['name'])) {
                return $field;
            }
        }

        return null;
    }

    private function validateUpload(string $field, string $label): ?string
    {
        $file = $_FILES[$field] ?? null;
        if (!is_array($file) || empty($file['name'])) {
            return "$label is required.";
        }

        $error = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error !== UPLOAD_ERR_OK) {
            return "Could not upload $label. Please try again.";
        }

        if ((int) ($file['size'] ?? 0) > $this->maxUploadSize) {
            return 'File too large. Max size is 5MB.';
        }

        $allowed = ['image/jpeg', 'image/png', 'image/webp'];
        $mime = mime_content_type($file['tmp_name']);
        if (!in_array($mime, $allowed, true)) {
            return 'Unsupported file format. Use JPG, PNG, or WEBP.';
        }

        return null;
    }

    private function saveUpload(string $field, string $prefix): ?string
    {
        $file = $_FILES[$field] ?? null;
        if (!is_array($file) || empty($file['name']) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            return null;
        }

        $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $filename = $prefix . '_' . uniqid() . '.' . $ext;
        if (!is_dir($this->uploadDir)) {
            mkdir($this->uploadDir, 0755, true);
        }
        move_uploaded_file($file['tmp_name'], $this->uploadDir . $filename);
        return $filename;
    }

    private function removeUpload(?string $file): void
    {
        if (!$file) {
            return;
        }

        $path = $this->uploadDir . $file;
        if (file_exists($path)) {
            unlink($path);
        }
    }

    private function photoUrl(?string $f): ?string
    {
        return $this->uploadUrl('drivers', $f);
    }

    public function submit(): void
    {
        $me = BaseController::$authDriver;
        $err = $this->requireFields(['driving_experience']);
        if ($err) {
            echo $err;
            return;
        }

        $frontField = $this->preferredUploadField(['kyc_id_front', 'front', 'license_front']);
        $backField = $this->preferredUploadField(['kyc_id_back', 'back', 'license_back']);
        $profileField = $this->preferredUploadField(['profile_photo', 'photo']);

        if ($frontField === null || $backField === null || $profileField === null) {
            echo utilities::apiMessage(
                'Please upload your driver license front, driver license back, and profile photo.',
                422
            );
            return;
        }

        foreach ([
            [$frontField, 'Driver license front'],
            [$backField, 'Driver license back'],
            [$profileField, 'Profile photo'],
        ] as [$field, $label]) {
            $uploadError = $this->validateUpload($field, $label);
            if ($uploadError !== null) {
                echo utilities::apiMessage($uploadError, 422);
                return;
            }
        }

        $front = $this->saveUpload($frontField, $me['id'] . '_kf');
        $back = $this->saveUpload($backField, $me['id'] . '_kb');
        $profilePhoto = $this->saveUpload($profileField, $me['id'] . '_kp');

        if ($front === null || $back === null || $profilePhoto === null) {
            echo utilities::apiMessage('Upload failed. Please try again.', 500);
            return;
        }

        $driver = $this->getall('drivers', 'id = ?', [$me['id']]);
        $oldFront = is_array($driver) ? ($driver['kyc_id_front'] ?? null) : null;
        $oldBack = is_array($driver) ? ($driver['kyc_id_back'] ?? null) : null;
        $oldPhoto = is_array($driver) ? ($driver['photo'] ?? null) : null;

        $idType = $this->str('kyc_id_type', "Driver's License");
        $idNumber = $this->str('kyc_id_number');
        $fields = [
            'kyc_id_type' => $idType !== '' ? $idType : "Driver's License",
            'kyc_id_number' => $idNumber !== '' ? $idNumber : null,
            'driving_experience' => $this->str('driving_experience'),
            'kyc_status' => 'pending',
            'kyc_id_front' => $front,
            'kyc_id_back' => $back,
            'photo' => $profilePhoto,
        ];

        $this->update('drivers', $fields, "id = '{$me['id']}'");
        $this->logActivity('driver', $me['id'], 'kyc_submitted');

        if ($oldFront && $oldFront !== $front) {
            $this->removeUpload($oldFront);
        }
        if ($oldBack && $oldBack !== $back) {
            $this->removeUpload($oldBack);
        }
        if ($oldPhoto && $oldPhoto !== $profilePhoto) {
            $this->removeUpload($oldPhoto);
        }

        echo utilities::apiMessage('KYC submitted.', 200, [
            'kyc_status' => 'pending',
            'driving_experience' => $fields['driving_experience'],
            'kyc_front_url' => $this->photoUrl($front),
            'kyc_back_url' => $this->photoUrl($back),
            'photo_url' => $this->photoUrl($profilePhoto),
        ]);
    }
}
