#!/usr/bin/perl -w 

# This script searches the current directory and subdirectories(or file/directory
# inputed as a cmd line parameters) for *.php and *.inc files.  
# It then takes every instance of:
#    "session_register("name")" and replaces it with $_SESSION['name']
# It also replaces every variable of $name with $_SESSION['name']
#
# usage:  ./fix_php4_sessions.pl
#         or
#         ./fix_php4_sessions.pl <dir>
#         or
#         ./fix_php4_sessions.pl <file1> <file2> <file3>...

use strict;
use Data::Dumper;
use File::Find;

print "This will modify all *.php and *.inc files recursively " .
      "in the directory.  Continue y/n?";
$| = 1;        # force a flush after our print
$_ = <STDIN>;  # get input from STDIN
chomp;
exit if $_ eq 'n';


# use current directory unless you pass a command line arg
@ARGV = qw(.) unless @ARGV;

open ( LOG, ">php4_sessions_fixed.log" )
  or die "Cant create file: $!";

open( CVS, "> files_to_checkin.txt" )  # create a file we can use a shell script
  or die "Can't open file: $!";        # to check in all changes
print CVS "cvs commit -m \"fixed session_register for PHP5\" \\\n";

my $total_changes        = 0;
my $total_files          = 0;
my $total_files_modified = 0;

# ----------------------------------------------------------------------------
# This subroutine comes from File::Find and does all the recursive directory
# searches and passes each file found to sub process_files
# 
find( \&process_file, @ARGV );


# ----------------------------------------------------------------------------
# The File::Find module calls this routine once for every file, passing
# in the file name and changing directory to that file
# $_ is the file basename
# $File::Find::name is the relative path name
#
sub process_file {
 
  return unless $File::Find::name =~ /\.php$|\.inc$/;  #skip non-php files
  
  $total_files++;                  # total files looked at
  
  my $sessions_to_register;        # Hash ref storing all session_register("names")
  my $session;                     # Name found in each $sessions_to_register
  my $file_changed = 0;            # A flag tracking if current file is changed
  my $line_number  = 0;            # Keeps track of current line number
  my $old_file     = $_;           # $_ set by the File::Find module
  my $new_file     = $_ . ".tmp";  # Append ".tmp" as a swap file
  
  open( OLD, "< $old_file" ) or die "Can't open file: $!";
  
  # We put the entire file into an array because we will need to scan
  # it many times and this is more convenient than using seek OLD,0,0
  # Caution needs to be taken that the file does not consume all memory
  #
  my @old_file = <OLD>;
  
  close OLD;
  
  open( NEW, "> $new_file" ) or die "Can't open file: $!";

  foreach ( @old_file ){     
    
    my $line = $_;
    
    # scan all lines for "session_register("*") or ('*')
    if ( $line =~ /session_register\([\'\"](.+?)[\'\"]\);/ ){      
      $sessions_to_register->{$1}  =  1;    # store the matched session variable
    }
  }
      
      
  # ========================================================================
  # Now that we have all instances of "session_register" stored in the hash,
  # for every session variable that was found, we will scan all lines(stored
  # as an array) looking for instances of that variable.  When we find it,
  # we will replace it with $_SESSION.  We also print any changes to the log
  # file along with the original code
  #
  foreach $session( keys %$sessions_to_register ){

    $line_number = 0;
    
    foreach( @old_file ){
    	
    	my $line = $_;
    	
    	$line_number++;
        	
    	# replace all lines that have "session_resgister("*") or ('*')
    	# with $_SESSION['matched_variable']
    	#
      if ( s/session_register\([\'\"](.+?)[\'\"]\);/\$_SESSION['$1'];/ ){
      	
      	print LOG "OLD " . $line;  #print the line before it is modified
      	
      	# print the replacement along with the filename and line number to the log
      	# $_ is the value in @old_file which contains the new SESSION
      	#
        print LOG "$File::Find::name/$line_number $_"; 
        print LOG "\n";                                  
        
        $file_changed = 1;      # flag that current file has been modified
        $total_changes++;
      }
        
      # if it matches the name with a $ in front, such as $variable or $variable[0]
      if( /\$$session\b/ ){

        print LOG "OLD: " . $line;
        
        # replace the $variable with $_SESSSION['variable']
        # this is done on $_, which is the current $_ from foreach(@old_file)
        # it does the switch/replace in-place
        s/\$$session\b/\$_SESSION['$session']/g;
        
        # find $_SESSION within quotes, PHP does not interpolate it but sometimes
        # it is valid, so only print a warning message
        if( /".*?\$_SESSION.*?"/ ){    
          print LOG "WARNING: \$_SESSION POSSIBLY INSIDE DOUBLE QUOTES\n";
        }
        
        # print a message if the match does not end in a ; which could
        # potentially mean it is wrapped in double-quotes from lines above and below
        if( $_ !~ /\$_SESSION.*?;$/ ){
          print LOG "WARNING: \$_SESSION NOT TERMINATED WITH SEMICOLON\n";
        }
        
        # print the replacement along with the filename and line
        # number to the log file
        print LOG "$File::Find::name/$line_number " . $_; 
        print LOG "\n";
                
        $total_changes++;
        
      } # end if /$session/
            
    }  # end foreach (@old_file)
    
  } # end foreach %session

  # If the file we are on has changed, we need to save the changes  
  if( $file_changed ){
  	$total_files_modified++;
  	
    print CVS $File::Find::name . " \\\n";  # add file name for CVS commiting
    
    print NEW @old_file;  # @old_file now has all the edits in-place
    close NEW;            # print it to the new file then rename it back
    rename($new_file, $old_file);
    
    print LOG "=" x 80 . "\n";  # delimit log with row of equals for each file
 }
  else{
  	#if file is unchanged, delete the temp file
  	close NEW;
  	unlink $new_file;
  }

} # end sub process_file


#STDOUT
print "TOTAL FILES LOOKED AT: " . $total_files . "\n\n";
print "TOTAL FILES MODIFIED: " . $total_files_modified . "\n\n";
print "TOTAL EDITS MADE: " . $total_changes . "\n\n";

#LOG FILE
print LOG "TOTAL FILES LOOKED AT: " . $total_files . "\n\n";
print LOG "TOTAL FILES MODIFIED: " . $total_files_modified . "\n\n";
print LOG "TOTAL EDITS MADE: " . $total_changes . "\n\n";

close LOG;
close CVS;
