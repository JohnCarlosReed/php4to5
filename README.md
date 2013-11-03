Fix SESSIONs When Upgrading from PHP4 to PHP5
=============================================

````
This script searches the current directory and subdirectories(or file/directory
inputed as a cmd line parameters) for *.php and *.inc files.  
It then takes every instance of:
   "session_register("name")" and replaces it with $_SESSION['name']
It also replaces every variable of $name with $_SESSION['name']
````
