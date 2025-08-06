<?php

	/*
	MIT License

	Copyright (c) 2024 Daniel-Doggy

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
	*/

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
