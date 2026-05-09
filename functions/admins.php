<?php 
    require_once "functions/formhandler.php";
    class admins extends roles {
        protected $formHander = new formHandler;
        protected $utilities = new utilities;
        function manage_admin($data) {
            if(isset($_POST['ID']) && $_POST['ID'] != "") {
                $action = "update";
                if(!$this->validate_action(["admins"=>"edit"], true)) return ;
                if($_POST['password'] == "") {
                    unset($data['password']);
                    unset($data['confirm_password']);
                }
                $actionName = "edit";
            }else{
                $actionName = "new";
                if(!$this->validate_action(["admins"=>"new"], true)) return ;
                $action = "insert";
                $_POST['ID'] = uniqid();
            }
            $info = $this->formHander->validate_form($data, "admins", $action);
            if (is_array($info)) {
                $actInfo = ["userID" => adminID, "date_time" => date("Y-m-d H:i:s"), 
                "action_name" => "$actionName Admin",
                "description" => "$actionName Admin", 
                "action_for"=>"admins", 
                "action_for_ID"=>htmlspecialchars($_POST['ID'])];
                $this->formHander->new_activity($actInfo);
                return $this->message("Action taken successfully", "success");
            }
        }
    }