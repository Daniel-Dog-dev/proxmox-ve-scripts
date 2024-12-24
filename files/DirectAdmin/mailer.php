<?php
	
	if(!file_exists(__DIR__ . "/login.json")){ exit(1); }
	
	$login_data = json_decode(file_get_contents(__DIR__ . "/login.json"), true);

	$message = "DirectAdmin has been installed via Cloud-Init.\nHostname: " . $login_data["hostname"] . "\nOne-Time login URL: " . $login_data["login_url"] . "\n\nThe password for the DirectAdmin user can be found in the install.log file located in the admin user home directory.\nAfter finding the password please make sure you change it to something else!";
	$headers = array(
		'From' => $login_data["admin_username"] . "@" . $login_data["hostname"],
		'Reply-To' => $login_data["admin_username"] . "@" . $login_data["hostname"],
	);

	mail($login_data["headless_email"], "Cloud-Init DirectAdmin deployment was successful!", $message, $headers);
	
	exit(0);
?>
