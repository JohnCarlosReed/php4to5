Fix PHP SESSION 
===============

* After upgrading to PHP5 from PHP4, your SESSION variable will break.
This script searches the current directory and subdirectories(or file/directory
inputed as a cmd line parameters) for *.php and *.inc files.  

````
It then takes every instance of:
   "session_register("name")" and replaces it with $_SESSION['name']
It also replaces every variable of $name with $_SESSION['name']
````
