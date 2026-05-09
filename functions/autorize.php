<?php
require_once "functions/utilities.php";
require_once "functions/helper.php";
require_once "functions/mailer.php";
class autorize extends helper
{

    protected $mail;
    protected $utilities;
    function __construct()
    {
        parent::__construct();
        $this->mail = new Mymailer;
        $this->utilities = new utilities;
    }
    public function signin()
    {
        $d = new database;
        $email = htmlspecialchars($_POST['email']);
        $password = htmlspecialchars($_POST['password']);
        if (empty($email) || empty($password)) {
            return $d->message("Make sure you enter your email and password", "error");
        }
        $value = $d->getall("users", "email = ?", [$email]);
        if (!is_array($value)) {
            return $d->message("Email doesn't exist.", "error");
        }
        if (!password_verify($password, $value['password'])) {
            return $d->message("Password Incorrect", "error");
        }
        if (htmlspecialchars($value['status']) == 0) {
            $reason = "";
            if ($value['reason'] != "") {
                $reason = htmlspecialchars($value['reason']);
            }
            return $d->message("We're sorry, your account has been blocked. <br> <b>Reason: </b> " . $reason, "error");
        }
        $urlgoto = "index";
        if (isset($_SESSION['urlgoto'])) {
            $urlgoto = htmlspecialchars($_SESSION['urlgoto']);
            unset($_SESSION['urlgoto']);
        }
        $urlgoto = "index";
        // reson here
        if (!$this->set_token($value)) {
            $this->message("Unable to set token", "error");
            return;
        }
        $actInfo = ["userID" => $value['ID'], "date_time" => date("Y-m-d H:i:s"), "action_name" => "Login", "description" => "Admin Login"];
        $this->new_activity($actInfo);
        // $_SESSION['adminSession'] = ;
        // $d->message("Account logged in Sucessfully <a href='index.php'>Click here to proceed.</a>", "error");
        $return = [
            "message" => ["Success", "Account Logged in", "success"],
            "function" => ["loadpage", "data" => ["$urlgoto", "null"]],
        ];
        return json_encode($return);
    }


    private function set_token(array $user)
    {
        $userID = $user['ID'];
        $token = $this->utilities->randcar(rand(20, 40));
        if (!$this->create_table("users", ["token" => []], isCreate: false))
            return false;
        $where = "ID ='$userID'";
        if (!$this->update("users", ["token" => $token], $where))
            return false;
        $_SESSION['adminSession'] = $token;

        // set log token
        $token = $this->utilities->randcar(rand(20, 80));
        $otpCode = "";
        if (isset($_ENV['$otpCode']) && $_ENV['$otpCode'] == "yes") {
            $otpCode = ($user['is_2fa'] == 1) ? $this->utilities->randcar(rand(5, 10)) : "";
        }
        $userDetails = $this->utilities->get_visitor_details();
        $log = [
            "userID" => $userID,
            "token" => $token,
            "ip" => $userDetails['ip_address'],
            "device" => $userDetails['device'],
            "date_time" => time(),
            "expiry_date" => time() + (60 * 60 * 24),
            "otp" => $otpCode,
        ];
        $this->delete("user_logs", "userID = ? and ip = ?", [$log['userID'], $log['ip']]);
        $this->quick_insert("user_logs", $log);
        if ($otpCode != "") {
            $smessage = $this->get_email_template("otp")['template'];
            $smessage = $this->replace_word([
                '${first_name}' => $user['first_name'],
                '${otp}' => $otpCode,
                '${ip_address}' => $log['ip'],
                '${device}' => $log['device'],
                '${location}' => $userDetails['state'] . " " . $userDetails['country'],
            ], $smessage);
            $this->mail->smtpmailer($user['email'], "OTP Verification for Login Attempt on Your EKSUTH Account", $smessage);
        }
        $_SESSION['logTk'] = $token;
        // die(var_dump($_SESSION));
        return true;
    }

    function sendverifyemail($userID)
    {
        $user = $this->getall("users", "ID = ?", [$userID]);
        if (!is_array($user)) {
            $this->message("User not found please login and try again", "error");
            return false;
        }

        if ($user['email_verify'] == 1) {
            $this->message("Seems user account is verified please login into your account", "error");
            return false;
        }
        $token = $user['token'];
        if ($user['token'] == "0") {
            $token = $this->utilities->randcar(40);
            $this->update("users", "", "ID = '$userID'", ["token" => $token]);
        }
        $email = $user['email'];
        $sendemail = $this->mail->smtpmailer(1, $user['email'], "Account Email Verification", "Please verify your account with the link provided below <br> <a href='verify.php?token=$token&e=$email'>verify Account</a>");
        if ($sendemail) {
            $this->message("Email Sent Successfully", "success");
        } else {
            $this->message("Error sending email please try again later", "error");
        }
    }
}