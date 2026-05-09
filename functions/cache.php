<?php 
class cache {
    public static function get($key) {
        $cacheFile = ROOT . '/cache/' . $key . '.cache';
        if (file_exists($cacheFile)) {
            $data = file_get_contents($cacheFile);
            return json_decode($data, true);
        }
        return null;
    }

    public static function set($key, $value, $expiration = 3600) {
        $cacheDir = dirname(ROOT . '/cache/' . $key); // Get the directory path
        if (!is_dir($cacheDir)) {
            mkdir($cacheDir, 0777, true); // Create the directory if it doesn't exist
        }
        $cacheFile = ROOT . '/cache/' . $key . '.cache';
        $data = json_encode($value);
        file_put_contents($cacheFile, $data);
        touch($cacheFile, time() + $expiration);
    }

    public static function clear($folder = null) {
        if ($folder) {
            $cacheDir = ROOT . '/cache/' . $folder;
            if (is_dir($cacheDir)) {
                array_map('unlink', glob($cacheDir . '/*.cache')); // Clear files in the specified folder
                rmdir($cacheDir); // Remove the folder if empty
            }
        } else {
            array_map('unlink', glob(ROOT . '/cache/*/*.cache')); // Clear files in subdirectories
            array_map('unlink', glob(ROOT . '/cache/*.cache')); // Clear files in the root cache directory
        }
    }
}