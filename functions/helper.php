<?php
require_once ROOT."/functions/utilities.php";
class helper extends database
{

    function new_activity($data)
    {
        if (isset($_SESSION['anonymous'])) {
            return null;
        }
        // $data = 'userID', "date_time", "action_name", "link", "action_for", "action_for_ID";
        if (is_array($data) && isset($data['userID'])) {
            $info = [];
            $info['userID'] = $data['userID'];
            unset($data['userID']);
            // var_dump($this->get_visitor_details());
            $visitor_info = [];
            // if(!isset($_SESSION['adminSession'])) {
            $visitor_info = utilities::get_visitor_details();
            // }
            $info = array_merge($info, $visitor_info, $data);
            if (!$this->quick_insert("activities",  $info)) {
                return false;
            }
            return true;
        } else {
            return false;
        }
    }
    function display_tmc($user)
    {
        $name = $user['title'] . ' ' . $user['first_name'] . ' ' . $user['last_name'];
        return '<div class="col-xl-3 col-lg-3 col-md-6 col-sm-">
                    <div class="single-team mb-30">
                        <a href="profile?ref=' . $user['ID'] . '">
                            <div class="team-img">
                                <img src="' . $this->get_image_url("assets/images/profile/" . $user['profile_image']) . '" alt="' . $name . ' - ' . $user['position'] . '" width="200" height="400px">
                            </div>
                        </a>

                        <div class="team-caption p-4">
                            <h3><a href="profile?ref=' . $user['ID'] . '">' . $name . '</a></h3>
                            <span>' . $user['position'] . '</span>
                            
                            <!-- <div class="team-social ">
                                <a href="#"><i class="fab fa-instagram"></i></a>
                                <a href="#"><i class="fab fa-facebook-f"></i></a>
                            </div> -->
                        </div>
                    </div>
                </div>';
    }
    function get_user($userID)
    {
        return $this->getall("users", "ID = ?", [$userID]);
    }

    function strprefix($string)
    {
        $string = str_replace(" ", "-", trim(htmlspecialchars_decode($string)));
        // die($string);
        // return $string;
        // Remove special characters and replace spaces with hyphens
        $sanitized = preg_replace('/[^a-zA-Z0-9_ -]/s', '', $string);

        // Add the prefix '-'
        return $sanitized;
    }

    function get_user_name($userID)
    {
        $user = $this->get_user($userID);
        if (!is_array($user)) return "Unknown";
        return $user['title'] . ", " . $user['first_name'] . " " . $user['last_name'];
    }

    function get_position($userID, $check = null)
    {
        $user = $this->get_user($userID);
        if (!is_array($user)) return "Unknown";
        if ($user['position'] != "" && $check == null) return $user['position'];
        $board = $this->getall("board", "user = ?", [$userID]);
        if (is_array($board) && ($check == null || $check == "board")) return $board['position'];
        $departments = $this->getall("departments", "hod = ?", [$userID]);
        if (is_array($departments) && ($check == null || $check == "hod")) return "HOD of " . $departments['name'];
        $alumni = $this->getall("alumni", "user = ?", [$userID]);
        if (is_array($alumni) && ($check == null || $check == "alumni")) return "Alumni set: " . $alumni['year_of_graduation'];
        return "";
    }

    function extracttext($html)
    {
        if (empty($html)) return $html;
        // Use DOMDocument to parse the HTML
        $doc = new DOMDocument();

        // Suppress warnings for invalid HTML
        libxml_use_internal_errors(true);
        $doc->loadHTML($html);
        libxml_clear_errors();

        // Try to find the first <p> tag
        $paragraphs = $doc->getElementsByTagName('p');
        if ($paragraphs->length > 0) {
            // Return the text content of the first <p>
            return trim($paragraphs->item(0)->textContent);
        }

        // If no <p> tags, return plain text by stripping HTML tags
        return trim(strip_tags($html));
    }

    function delete_button($redirectUrl, $message = "Are you sure you want to delete this item?", $class = "btn btn-sm btn-danger bg-danger boder-none", $atb = "")
    {
        return '<a href="javascript:void(0)" 
                 onclick="if(confirm(\'' . htmlspecialchars($message) . '\')) { 
                     window.location.href=\'' . htmlspecialchars($redirectUrl) . '\'; 
                 }" 
                 ' . $atb . '
                 class="' . $class . '">Delete</a>';
    }


    function display_user($user, $from = null, $class = "col-xl-3 col-lg-3 col-md-6 col-sm-")
    {
        if (!is_array($user)) $user = $this->getall("users", "ID = ?", [$user]);
        if (!is_array($user)) return "";
        $position = $this->get_position($user['ID'], $from);
        $name = $this->get_user_name($user['ID']);
        $links = "";
        if ($user['website'] != "") $links .= '<a href="' . $user['website'] . '"><i class="fas fa-globe"></i></a>';
        if ($user['linkedin'] != "") $links .= '<a href="' . $user['linkedin'] . '"><i class="fab fa-linkedin"></i></a>';
        if ($user['instagram'] != "") $links .= '<a href="' . $user['instagram'] . '"><i class="fab fa-instagram"></i></a>';
        if ($user['facebook'] != "") $links .= '<a href="' . $user['facebook'] . '"><i class="fab fa-facebook-f"></i></a>';
        if ($user['twitter'] != "") $links .= '<a href="' . $user['twitter'] . '"><i class="fab fa-twitter"></i></a>';
        if ($user['tiktok'] != "") $links .= '<a href="' . $user['tiktok'] . '"><i class="fab fa-tiktok"></i></a>';

        return '<div class="' . $class . '">
                    <div class="single-team mb-30">
                        <div class="team-img">
                            <img src="' . $this->get_image_url("assets/images/profile/" . $user['profile_image']) . '" alt="' . $name . ' ' . $position . '" width="200" height="350px">
                        </div>
                        <div class="team-caption p-4 pt-5 pb-5">
                            <h3><a href="profile/' . $this->strprefix($name) . '?ref=' . $user['ID'] . '">' . $name . '</a></h3>
                            <span>' . $position . '</span>
                            <div class="team-social">
                               ' . $links . '
                            </div>
                        </div>
                    </div>
                </div>';
    }

    function rand_passwd($length = 8, $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    {
        return substr(str_shuffle($chars), 0, $length);
    }

    function options_list($table, $key = "ID", $value = "name")
    {

        if (is_string($table)) $table = $this->getall("$table", fetch: "moredetails");
        if ($table->rowCount() > 0) {
            foreach ($table as $row) {
                $data[$row[$key]] = $this->pass_value($value, $row);
            }
        }
        return $data ?? [];
    }

    function pass_value($value, $row)
    {
        if (is_array($value)) {
            $no = 0;
            $count = count($value);
            $data = "";
            foreach ($value as $key => $val) {
                $no++;
                if ($no == $count) {
                    $data .= $row[$val];
                } else {
                    $data .= $row[$val] . " - ";
                }
            }
        } else {
            $data = $row[$value];
        }
        return $data;
    }

    function imageupload($name)
    {
        if ((!empty($_FILES["uploaded_file"])) && ($_FILES['uploaded_file']['error'] == 0)) {
            $filename = basename($_FILES['uploaded_file']['name']);
            $ext = substr($filename, strrpos($filename, '.') + 1);
            $size = $_FILES["uploaded_file"]["size"];
            if (($ext == "jpg") && ($_FILES["uploaded_file"]["type"] == "image/jpeg") &&
                ($size > 0 && $size < 350000)
            ) {
                $tmp = $_FILES["uploaded_file"]["tmp_name"];
                $mime = null;
                if (function_exists("finfo_open")) {
                    $f = @finfo_open(FILEINFO_MIME_TYPE);
                    if ($f) {
                        $mime = @finfo_file($f, $tmp);
                        finfo_close($f);
                    }
                }
                if ($mime !== null && strpos($mime, "image/") !== 0) {
                    database::message("Error: Invalid image file type", "error");
                    return false;
                }
                if (!@getimagesize($tmp)) {
                    database::message("Error: Corrupt or invalid image file", "error");
                    return false;
                }
                $name = $name . '.' . $ext;
                $newname = 'upload/' . $name;
                if ((move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $newname))) {
                    return $name;
                } else {
                    database::message("Error: A problem occurred during Passport upload!", "error");
                    return false;
                }
            } else {
                database::message("Error: Only .jpg images under 350Kb are accepted for upload", "error");
                return false;
            }
        } else {
            database::message("Error: No image uploaded", "error");
            return false;
        }
    }

    protected function proccess_single_image($key, $value, $datas)
    {
        if (!$this->check_if_required($value)) {
            if ($_FILES[$key]['name'] == "" && isset($datas['input_data'][$key]) && $datas['input_data'][$key] != "") {
                return $datas['input_data'][$key];
            }
            if ($_FILES[$key]['name'] == "") {
                return  "no--value";
            }
            return "upload--this--file";
        }
        if (!isset($_FILES[$key]['name']) || $_FILES[$key]['name'] == "") {
            $key = str_replace("_", " ", $key);
            database::message("You need to upload $key", "error");
            return false;
        }
        if (!isset($value['path']) || $value['path'] == "") {
            $key = str_replace("_", " ", $key);
            $this->message("Intr: No path set for $key. <br> Note: this error is an internal error, you are not the reason for the error. <br> Please report to us on <a href='mailto:" . $this->get_settings("support_email") . "' target='_BLANK'>" . $this->get_settings("support_email") . "</a>", "error");
            return false;
        }
        return "upload--this--file";
    }

    protected function check_multiple_files($names)
    {
        $error = false;
        foreach ($names as $key => $value) {
            if ($this->check_if_required($value)) {
                if ($_FILES["$key"]['name'] == "" || !isset($_FILES["$key"]['name'])) {
                    $error = true;
                    database::message("You need to upload your $key", "error");
                } else {
                    $set["$key"] = ${$key} = htmlspecialchars($_FILES["$key"]['name']);
                }
            } else {
                $set["$key"] = ${$key} = htmlspecialchars($_FILES["$key"]['name']);
            }
        }
        if (!$error) {
            return $set;
        } else {
            return $this->err;
        }
    }

    function verbose($ok = 1, $info = "", $file_name = "")
    {
        if ($ok == 0) {
            http_response_code(400);
        }
        return json_encode(["ok" => $ok, "info" => $info, "filename" => $file_name]);
    }

    function chunk_upload($mainfilePath, $valid_formats1 = ["mp4", "mov"])
    {
        $filePath = $mainfilePath;
        if (empty($_FILES) || $_FILES["file"]["error"]) {
            return $this->verbose(0, "<small class='text-danger'>Failed to move uploaded file. Reload page and try again</small>");
        }
        if ((int)$_FILES["file"]["size"] * ((int)$_REQUEST["chunks"] - 1) > 209715200) {
            return $this->verbose(0, "<small class='text-danger'>File too large. MAX OF: 200MB, compress the file and try again</small>");
        }
        if (!file_exists($filePath)) {
            if (!mkdir($filePath, 0777, true)) {
                return $this->verbose(0, "Failed to create $filePath");
            }
        }
        $fileName = isset($_REQUEST["name"]) ? $_REQUEST["name"] : $_FILES["file"]["name"];
        $fileInfo = pathinfo($fileName);
        $ext = strtolower($fileInfo['extension']);
        if (!in_array($ext, $valid_formats1)) {
            return $this->verbose(0, "<small class='text-danger'>Video file Not Support. We support: " . implode(" ", $valid_formats1) . "</small>");
        }
        $filePath = $filePath . DIRECTORY_SEPARATOR . $fileName;
        $chunk = isset($_REQUEST["chunk"]) ? intval($_REQUEST["chunk"]) : 0;
        $chunks = isset($_REQUEST["chunks"]) ? intval($_REQUEST["chunks"]) : 0;
        $out = @fopen("{$filePath}.part", $chunk == 0 ? "wb" : "ab");
        if ($out) {
            $in = @fopen($_FILES["file"]["tmp_name"], "rb");
            if ($in) {
                while ($buff = fread($in, 4096)) {
                    fwrite($out, $buff);
                }
            } else {
                return $this->verbose(0, "Failed to open input stream");
            }
            @fclose($in);
            @fclose($out);
            @unlink($_FILES["file"]["tmp_name"]);
        } else {
            return $this->verbose(0, "Failed to open output stream");
        }
        if (!$chunks || $chunk == $chunks - 1) {
            $fileName = uniqid("video-") . "." . $ext;
            $thefilePath = $mainfilePath . DIRECTORY_SEPARATOR . $fileName;
            rename("{$filePath}.part", $thefilePath);
            return $this->verbose(1, "Upload OK", $fileName);
        }
        return $this->verbose(1, "Upload OK");
    }

    function process_image($title, $path, $name = "uploaded_file", $i = 0, array $valid_formats1 = null, $compress = true)
    {
        if ($valid_formats1 == null) {
            $valid_formats1 = ["JPG", "jpg", "png", "jpeg",  "svg", "gif"];
        }
        $maxTotalSize = 5 * 1024 * 1024;
        if (!isset($_FILES["$name"])) {
            return null;
        }
        $isMultiple = is_array($_FILES["$name"]["name"]);
        $image = $isMultiple ? $_FILES["$name"]["name"][$i] : $_FILES["$name"]["name"];
        $size = $isMultiple ? $_FILES["$name"]["size"][$i] : $_FILES["$name"]["size"];
        $tmp = $isMultiple ? $_FILES["$name"]["tmp_name"][$i] : $_FILES["$name"]["tmp_name"];
        if (empty($image)) {
            database::message("No file selected", "error");
            return false;
        }
        if (isset($_POST) and $_SERVER['REQUEST_METHOD'] == "POST") {
            if ($size <= 0) {
                database::message("Upload failed. Empty file received.", "error");
                return false;
            }
            if ($size > $maxTotalSize) {
                database::message("File too large. Max size is 5MB", "error");
                return false;
            }
            $fileInfo = pathinfo($image);
            $ext = strtolower($fileInfo['extension']);
            if (!in_array($ext, $valid_formats1)) {
                database::message('<b>' . $image . ':</b> Image file Not Support. We support: ' . implode(" ", $valid_formats1), 'error');
                return false;
            }
            $tmpMime = null;
            if (function_exists("finfo_open")) {
                $f = @finfo_open(FILEINFO_MIME_TYPE);
                if ($f) {
                    $tmpMime = @finfo_file($f, $tmp);
                    finfo_close($f);
                }
            }
            $imageExts = ["jpg", "jpeg", "png", "gif", "webp"];
            if (in_array($ext, $imageExts)) {
                if ($tmpMime !== null && strpos($tmpMime, "image/") !== 0) {
                    database::message('<b>' . $image . ':</b> Invalid image file type', 'error');
                    return false;
                }
                if (!@getimagesize($tmp)) {
                    database::message('<b>' . $image . ':</b> Corrupt or invalid image file', 'error');
                    return false;
                }
            }
            if ($path == "check") {
                return true;
            }
            $titlename = str_replace(" ", "_", $title);
            $actual_image_name =  $titlename . "." . $ext;
            $target = $path . $actual_image_name;
            if (!move_uploaded_file($tmp, $target)) {
                database::message('<b>' . $image . ': Image Not Uploaded Try again', 'error');
                return false;
            }
            $shouldCompress = false;
            $maxSize = 1048576;
            if ($compress === false) {
                $shouldCompress = false;
            } elseif (is_int($compress)) {
                $shouldCompress = true;
                $maxSize = $compress;
            } elseif ($compress === true) {
                $shouldCompress = true;
                $maxSize = 1048576;
            }
            if ($shouldCompress && $size > $maxSize && in_array($ext, ['jpg', 'jpeg', 'png'])) {
                if ($ext == 'jpg' || $ext == 'jpeg') {
                    $img = @imagecreatefromjpeg($target);
                    if ($img) {
                        $quality = 85;
                        do {
                            ob_start();
                            imagejpeg($img, null, $quality);
                            $imgData = ob_get_clean();
                            if (strlen($imgData) <= $maxSize || $quality < 40) break;
                            $quality -= 10;
                        } while ($quality >= 40);
                        file_put_contents($target, $imgData);
                        imagedestroy($img);
                    }
                } elseif ($ext == 'png') {
                    $img = @imagecreatefrompng($target);
                    if ($img) {
                        $compression = 6;
                        do {
                            ob_start();
                            imagepng($img, null, $compression);
                            $imgData = ob_get_clean();
                            if (strlen($imgData) <= $maxSize || $compression == 9) break;
                            $compression++;
                        } while ($compression <= 9);
                        file_put_contents($target, $imgData);
                        imagedestroy($img);
                    }
                }
            }
            return $actual_image_name;
        }
    }

    function handleLinkInText($s)
    {
        $s = htmlspecialchars_decode($s, ENT_QUOTES);
        return preg_replace('@(https?://([-\w\.]+[-\w])+(?:\:\d+)?(?:/([\w/_\.#-]*(?:\?\S+)?[^\s<>])?)?)@', '<a href="$1" target="_blank">$1</a><br>', $s);
    }
}
