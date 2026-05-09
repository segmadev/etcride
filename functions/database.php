<?php
require_once ROOT.'functions/cache.php';
// $2y$10$zaHI56uHbjpe0xfZdAVVZO4gruUDPE/NZmIGc3s3iX78e5/vZtTYe
class database
{
    public $db;
    private $index;
    private $marks;
    private $data;
    public $err = "no";
    public $userID;
    // private constructor
    public function __construct()
    {
        // $this->d = new database;
        $servername = $_ENV['DB_HOST'] ?? "localhost";
        $username = $_ENV['DB_USERNAME'] ?? "root";
        $password = $_ENV['DB_PASSWORD'] ?? ""; 
        $dbname = $_ENV['DB_DATABASE'] ?? "market_closeby"; 
        try {
            $this->db = new PDO("mysql:host=$servername;dbname=" . $dbname, $username, $password);
            // set the PDO error mode to exception
            $this->db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            //echo "Connected successfully";php
            // I won't echo this message but use it to for checking if you connected to the db
            //incase you don't get an error message
        } catch (PDOException $e) {
            echo "Connection failed: " . $e->getMessage();
        }
        // $this->userID = htmlspecialchars($_SESSION['adminSession']);  
    }

    function is_ofline_buyer($userID)
    {
        $idlist = $this->get_settings("offline_buyers");
        // Split the $idlist by commas and whitespace
        $id_array = array_map('trim', explode(",", $idlist));
        // Check if the $userID is in the $id_array
        if (in_array($userID, $id_array)) {
            return true;
        } else {
            return false;
        }
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
    

    function validate_admin()
    {
        if (isset($_SESSION['adminSession'])) {
            return true;
        }
        return false;
    }

   


    // USEAGE
    // Get information from the database using where condition
    // CODE: $members = $d->getall('members', 'email = ?', ['www@gmail.com '], fetch: "moredetails");
    // get all info from database with no conditions
    // CODE: $members = $d->getall(from: 'members', fetch: "moredetails");
    // get info from database with  no conditions but with a limit
    // CODE: $members = $d->getall(from: 'members', where: "LIMTI 10" fetch: "moredetails");
    function getall($from, $where = "", array $data = [], $select = "*", $fetch = "details", $iscacheable = false, $cacheTime = 1200, $isrenew = false)
    {
        // Generate a unique cache key based on the query parameters
        $cacheKey = strtolower($from) . '/' . md5($where . json_encode($data) . $select . $fetch);
    
        // Check if caching is enabled and retrieve from cache if valid
        if ($iscacheable && !$isrenew) {
            $cachedData = cache::get($cacheKey);
            if ($cachedData) {
                return (count($cachedData) == 1 && isset($cachedData['data'][0])) ? $cachedData['data'][0] : $cachedData['data'];
            }
        }
    
        // If fetch mode is empty and select is "*", set select to count
        if ($fetch == "" && $select == "*") {
            $select = "COUNT(*) as count";
        }
    
        // Prepare the base SQL query
        $sql = "SELECT $select FROM $from";
    
        // Append WHERE clause if provided
        if (!empty($where) && substr($where, 0, 5) != "LIMIT") {
            $sql .= " WHERE $where";
        } elseif (substr($where, 0, 5) == "LIMIT" || empty($where)) {
            $sql .= " $where";
        }
    
        // Prepare the statement
        $q = $this->db->prepare($sql);
    
        // Execute the statement with parameters
        $q->execute($data);
    
        // Fetch results based on the specified fetch mode
        $result = $this->getmethod($q, $fetch);
    
        // Cache the result if caching is enabled or renewal is requested
        if ($iscacheable || $isrenew) {
            $cacheData = [
                'queryString' => $sql, // Store the query string
                'data' => $result // Store the actual data
            ];
            cache::set($cacheKey, $cacheData, $cacheTime);
        }
    
        return $result; // Return the result directly
    }

    function clearCache($folder = null)
    {
        cache::clear($folder ? strtolower($folder) : null);
    }

    // USEAGE
    // Insert single data
    // $d->quick_insert("members",
    // [
    //     "firstname" => "tolu",
    //     "lastname" => "ajayi",
    //     "email" => "tolu@gmail.com",
    //     "phonenumber" => "3444334",
    //     "address" => "bawa",
    //     "password" => "dkdkdkdkdk"
    // ],
    // );
    // insert multiple data
    // $d->quick_insert("members",
    //[ 
    // [
    //     "firstname" => "tolu",
    //     "lastname" => "ajayi",
    //     "email" => "tolu@gmail.com",
    //     "phonenumber" => "3444334",
    //     "address" => "bawa",
    //     "password" => "dkdkdkdkdk"
    // ],
    // [
    //     "firstname" => "tolu",
    //     "lastname" => "ajayi",
    //     "email" => "tolu@gmail.com",
    //     "phonenumber" => "3444334",
    //     "address" => "bawa",
    //     "password" => "dkdkdkdkdk"
    // ],
    // ]
    // );

    function quick_insert($into, array $data, $message = null)
    {
        if (isset($data[0]) && is_array($data[0])) {
            foreach ($data as $row) {
                $insert =  $this->insert_data($into, $row);
                if (isset($insert)) {
                    $this->get_message($message);
                }
            }
            // return true;
        } else {
            $insert =  $this->insert_data($into, $data);
            $this->get_message($message);
            return true;
        }
        return false;
    }

    function get_message($message =  null)
    {
        if ($message == null) {
            return null;
        }
        $this->message($message, "success");
        return true;
    }
    // $update = $d->update("members", ["firstname"=>"tunde", "email"=>"tunde@gmail.com"], "ID = '4'");
    function update($what, $data, $where, $message = null)
    {
        $this->get_index_data($data, "update");
        $query = $this->db->prepare("UPDATE $what SET $this->index WHERE $where");
        $update = $query->execute($this->data);
        if ($update) {
            $this->get_message($message);
            return true;
        }
        return false;
    }
    // $d->delete("members", "ID = ? or phonenumber = ?", [3, 3434]);
    function delete($from, $where, array $data)
    {
        $query = $this->db->prepare("DELETE FROM $from WHERE $where ");
        $delete = $query->execute($data);
        if ($delete) {
            return true;
        }
        return false;
    }

    private function get_index_data(array $data, $type = "insert")
    {
        $index = '';
        $marks = '';

        if ($type == "insert") {
            foreach ($data as $key => $k) {
                $index .= "`$key`, ";
                $marks .= "?, ";
            }
        }

        if ($type == "update") {
            foreach ($data as $key => $value) {
                $index .= "`$key` = ?, ";
                $marks .= "?, ";
            }
        }

        $this->index = rtrim($index, ", ");
        $this->marks = rtrim($marks, ", ");
        $this->data = array_values($data);
        return true;
    }

    private function getmethod($q, $fetch, $iscacheable = false) {
        if ($fetch == "") {
            $data = $q->fetch(PDO::FETCH_ASSOC);
            if (isset($data['count'])) return $data['count'];
        }

        if ($fetch == "details" || $fetch == "single" || $fetch == "s") {
            return $q->fetch(PDO::FETCH_ASSOC); // Return a single row
        }
        if ($fetch == "moredetails" || $fetch == "all" || $fetch == "a") {
            return ($iscacheable) ? $q->fetchAll(PDO::FETCH_ASSOC) : $q; // Return all rows as an associative array
        }
        return $q->rowCount(); // Return the number of rows affected
    }

    function create_table($name, array $data, $isCreate = true)
    {
        if (!is_array($data)) {
            return null;
        }
        if ($isCreate == true && $this->check_table($name)) {
            return true;
        }
        $info = $this->get_table_para($data, $isCreate);
        $action = !$isCreate  ? "ALTER" : "CREATE";
        $name = !$isCreate  ? $name . " ADD" : $name;
        $query = $this->db->prepare("$action  TABLE $name ($info)");
        try {
            $update = $query->execute();
        } catch (\Throwable $th) {
            if (str_contains($th, "Column already exists")) {
                return true;
            }
            // echo $th;
            return false;
        }
        return true;
    }
    function check_table($name)
    {
        try {
            $query = $this->db->prepare("select 1 from $name");
            $update = $query->execute();
            return true;
        } catch (\Throwable $th) {
            return false;
        }
    }
    function get_table_para(array $datas, $isCreate = true)
    {
        $info = "";
        foreach ($datas as $key => $data) {
            $key = str_replace('[]', '', $key);
            $type = "VARCHAR(250)";
            $default_value = "";
            $isNull = "NOT NULL";
            if ($key == "ID" && isset($data['input_type']) && $data['input_type'] == "number") {
                $isNull .= " AUTO_INCREMENT";
            }
            $primaryKey = "";
            if (isset($data['input_type']) && $data['input_type'] == "number") {
                match (htmlspecialchars($data['input_type'])) {
                    "number" => $type = "INT(100)",
                };
            }
            if (isset($data['is_required']) && $data['is_required'] == false) {
                $isNull = "NULL";
            }
            if (isset($datas['input_data'][$key])) {
                $default_value = "DEFAULT '" . htmlspecialchars($datas['input_data'][$key]) . "'";
            }

            $info .= "$key $type $isNull $default_value,";
        }
        if (!$isCreate) return rtrim($info, ',');
        $info .= "`date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,";
        if (isset($datas['ID'])) {
            $info  .= "PRIMARY KEY(ID),";
        }
        return rtrim($info, ',');
    }
    function insert_data($into, $data)
    {
        $this->get_index_data($data);
        $query = $this->db->prepare("INSERT INTO $into ($this->index) values ($this->marks)");
        // if($into == "message") {
        //     var_dump($this->data);
        // }
        $insert = $query->execute($this->data);
        if ($insert) {
            return true;
        } else {
            return false;
        }
    }


    public function message($message, $type, $method = "default")
    {
        // die(ISAPI);
        // $isapi =  ? true : false;
        if (defined('ISAPI') && ISAPI == true) {
            $method = "json";
        }

        if ($type == "error") {
            $type = "danger";
        } elseif ($type == "success") {
            $type = "success";
        }
        $message = str_replace("_", " ", $message);
        //     echo "<div class='bg-$type fade show mb-5' role='bg'>
        //     <!--  <div class='bg-icon'><i class='flaticon-$type'></i></div> -->
        //     <div class='bg-text'>$message</div>
        // </div>";
        if ($type == "success" && $method == "default") {
            echo "<div class='message p-2 mt-1 mb-2 rounded-2 bg-light-success $type' style='color:green!important'>
                <span class='closebtn' onclick=\"this.parentElement.style.display='none';\">&times;</span>
                $message
                </div>";
        } elseif ($type == "danger" && $method == "default") {
            echo "<div class='message mt-1 p-2 mb-2 rounded-2 bg-light-danger $type' style='color:red!important'>
                <span class='closebtn' onclick=\"this.parentElement.style.display='none';\">&times;</span>
                $message
                </div>";
        }

        if ($type == "success" && $method == "json") {
            if(defined('ISAPI') && ISAPI) {
               return utilities::apiMessage($message, 200);
            }
            $return = [
                "message" => ["Success", "$message", "success"],
            ];
            return json_encode($return);
        } elseif ($type == "danger" && $method == "json") {
            if(defined('ISAPI') && ISAPI) {
               return utilities::apiMessage($message, 400);
            }
            $return = [
                "message" => ["Error", "$message", "error"],
            ];
            return json_encode($return);
        }
    }

   





   


    // addtion functions

    function get_settings($value = "company_name", $where = "settings",  $who = "all", $type = "meta_for")
    {
        $data = $this->getall("$where", "meta_name = ? and meta_for = ?", [htmlspecialchars($value), $who]);
        if (!is_array($data)) {
            return "";
        }
        if ($this->isEncrypted($data['meta_value'])) {
            $data['meta_value'] = $this->get_enypt_data($data['meta_value']);
        }
        return ($type == "all") ? $data : $data['meta_value'];
    }

    protected function get_enypt_data($id)
    {
        $data = $this->getall("encrypted_data", "ID = ?", [$id]);
        if (!is_array($data)) return false;
        return $this->decryptData($data['meta_value']);
    }

    function isEncrypted($data)
    {
        $explode = explode("-", $data);
        if ($explode[0] == "enyptdata") return true;
        return false;
    }

    protected function enypt_unlink($id)
    {
        if ($this->delete("encrypted_data", "ID = ?", [$id])) return true;
        return false;
    }
    function enypt_and_save_data($data)
    {
        if ($data == null || $data == "") return false;
        $mainData = $data;
        $data = $this->encryptData($data);
        if ($data == false || $data == "") return false;
        $data = [
            "ID" => uniqid("enyptdata-"),
            "meta_value" => $data
        ];
        if ($this->quick_insert("encrypted_data", $data)) {
            $data['data'] = $mainData;
            return $data;
        }
        return false;
    }

    function create_settings(array $data, $what = "settings")
    {
        if (!is_array($data)) {
            return null;
        }
        foreach ($data as $key => $value) {
            if ($this->getall($what, "meta_name = ?",  [$key], fetch: "") > 0) {
                continue;
            }
            $this->quick_insert($what, ["meta_name" => $key, "meta_value" => $value]);
        }
    }

    function replace_word(array $data, $word)
    {
        // $word = $word;
        foreach ($data as $key => $value) {
            $value = htmlspecialchars($value);
            if (!strpos($word, $key)) {
                continue;
            }
            $word = str_replace($key, $value, $word);
        }
        // var_dump($word);
        return $word;
    }
    function get_email_template($name)
    {
        return $this->getall("email_template", "name = ?", [$name]);
    }

    // tempory user functions below
   


    // data encytion
    function encryptData($data, $secretKey = null)
    {
        if ($secretKey == null && isset($_ENV['DATA_ENCRYPTION_KEY'])) $secretKey = $_ENV['DATA_ENCRYPTION_KEY'];
        if ($secretKey == null) return false;
        $method = 'AES-256-CBC';
        $ivLength = openssl_cipher_iv_length($method);
        $iv = openssl_random_pseudo_bytes($ivLength);
        $encryptedData = openssl_encrypt($data, $method, $secretKey, 0, $iv);
        return base64_encode($iv . $encryptedData);
    }

    function decryptData($encryptedDataWithIv, $secretKey = null)
    {
        if ($secretKey == null && isset($_ENV['DATA_ENCRYPTION_KEY'])) $secretKey = $_ENV['DATA_ENCRYPTION_KEY'];
        if ($secretKey == null) return false;
        $method = 'AES-256-CBC';
        $ivLength = openssl_cipher_iv_length($method);

        $ivWithCiphertext = base64_decode($encryptedDataWithIv);
        $iv = substr($ivWithCiphertext, 0, $ivLength);
        $encryptedData = substr($ivWithCiphertext, $ivLength);

        return openssl_decrypt($encryptedData, $method, $secretKey, 0, $iv);
    }


}