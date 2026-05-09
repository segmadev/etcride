<?php
require_once ROOT . 'functions/BaseController.php';

class health extends BaseController
{
    public function check(): void
    {
        echo utilities::apiMessage('OK', 200, [
            'app'     => $this->setting('app_name', 'EtcRide'),
            'version' => '1.0.0',
            'time'    => date('Y-m-d H:i:s'),
        ]);
    }
}
