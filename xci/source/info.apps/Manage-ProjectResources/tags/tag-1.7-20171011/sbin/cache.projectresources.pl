#!/usr/bin/env perl
###########################################################################
#
#teragrid=> \d info_services.active_project_resources;
#   View "info_services.active_project_resources"
#    Column     |          Type          | Modifiers 
#---------------+------------------------+-----------
# charge_number | character varying(200) | 
# resource_name | character varying(200) | 
#View definition:
# SELECT DISTINCT projv2.charge_number, projv2.site_resource_name AS resource_name
#   FROM acct.projv2
#  WHERE projv2.proj_state::text = 'active'::text AND projv2.proj_on_resource_state = 'active'::text AND acct.resource_is_active(projv2.site_resource_id)
#  ORDER BY projv2.charge_number, projv2.site_resource_name;
#
#
###########################################################################

use strict;
use DBI;
use POSIX;
#use DBI qw(:sql_types);
use Getopt::Long;
use DBD::Pg qw(:pg_types);
use Text::CSV_XS;

my $DBHOST = 'tgcdb.teragrid.org';
my $DBNAME = 'teragrid';
my $DBPORT = 5432;
my $DBUSER = 'info_services';
#my $DBPASS = '7F7neder'; 
#my $DBPASS = '5rtf2qaw';
my $DBPASS = '8wASpHTC';

my $FALSE  = 0;
my $TRUE   = 1;
my $DEBUG  = $FALSE;

# Use table field indexes to make code more readable
my $F_resource_name   = 0;
my $F_charge_number   = 1;

my ($cache_dir);
GetOptions ('cache|c=s'   => \$cache_dir);
unless ($cache_dir) {
   print "Cache directory not specified\n";
   exit 1;
}

my $dbh = dbconnect();
my @results = dbexecsql($dbh, "select resource_name,charge_number from info_services.active_project_resources order by charge_number,resource_name;");
my $timestamp = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime;
dbdisconnect($dbh);

my @sorted = sort sortitems @results;

my (@output);
foreach (@sorted) {
   push @output, {'project_number' => escape_xml($_->[$F_charge_number]), 
                  'resource_name' => escape_xml($_->[$F_resource_name])
                 };
   printf("   %-30s %-30s\n", $_->[$F_charge_number], $_->[$F_resource_name]) if ($DEBUG);
}

my $lock_file = "$cache_dir/.lock";
create_lock($lock_file);

#my $cache_file = "$cache_dir/ActiveProjectResources.xml";
#open(STDOUT, ">$cache_file.NEW") or
#   die "Failed to open output '$cache_file'";

my ($org, $res, $last);

my $cache_file = "$cache_dir/projectresources.csv";
my $csv = Text::CSV_XS->new({eol=>$/});#,always_quote=>1});
   $csv->column_names('project_number','ResourceID');
my $fh;
open($fh, ">$cache_file.NEW") or
   die "Failed to open output '$cache_file'";

print $fh 'project_number,ResourceID' . "\n";
foreach (@output) {
   my $ResourceID = resource_name_to_resourceid($_->{'resource_name'});
   $csv->print ($fh, [$_->{'project_number'},$ResourceID] );
}

delete_lock($lock_file);

my @outstat = stat("$cache_file.NEW");
if ($outstat[7] != 0) {
   system("mv $cache_file.NEW $cache_file");
}
exit(0);

sub sortitems {
   $$a[$F_charge_number] cmp $$b[$F_charge_number] ||
   $$a[$F_resource_name] cmp $$b[$F_resource_name];
}

####################################################
# Database Access Subroutines
####################################################
sub dbdisconnect {
   my $dbh = shift;
   my $retval;
   eval { $retval = $dbh->disconnect; };
   if ( $@ || !$retval ) {
      dberror( "Error disconnecting from database", $@ || $DBI::errstr );
   }
}

sub dbconnect {
   my $dbh;

   # I'm using RaiseError because bind_param is too stupid to do
   # anything else, so this allows consistency at least.
   my %args = ( PrintError => 0, RaiseError => 1 );

   debug("connecting to $DBNAME on $DBHOST:$DBPORT as $DBUSER");

#  $dbh = DBI->connect( "dbi:Pg:dbname=$DBNAME;host=$DBHOST;port=$DBPORT",
   $dbh = DBI->connect( "dbi:Pg:dbname=$DBNAME;host=$DBHOST;port=$DBPORT;sslmode=require",
      $DBUSER, $DBPASS, \%args );
   dberror( "Can't connect to database: ", $DBI::errstr ) unless ($dbh);
#  $dbh->do("SET search_path TO acct");

   if ($DEBUG) {
      $dbh->do("SET client_min_messages TO debug");
   }

   return $dbh;
}

# Execute sql statements.
#
# If called in a list context it will return all result rows.
# If called in a scalar context it will return the last result row.
#
sub dbexecsql {
   my $dbh      = shift;
   my $sql      = shift;
   my $arg_list = shift;

   my ( @values, $result );
   my $i      = 0;
   my $retval = -1;
   my $prepared_sql;

   eval {
      debug("SQL going in=$sql");
      $prepared_sql = $dbh->prepare($sql);

      #or die "$DBI::errstr\n";

      $i = 1;
      foreach my $arg (@$arg_list) {
         $arg = '' unless $arg;
         $prepared_sql->bind_param( $i, $arg );

         #or die "$DBI::errstr\n";
         debug("arg ($i) = $arg");
         $i++;
      }
      $prepared_sql->execute;

      #or die "$DBI::errstr\n";

      @values = ();
      while ( $result = $prepared_sql->fetchrow_arrayref ) {
         push( @values, [@$result] );
         foreach (@$result) { $_ = '' unless defined($_); }
         debug( "result row: ", join( ":", @$result ), "" );
      }
   };

   if ($@) { dberror($@); }

   #   debug("last result = ",$values[-1],"");
   debug( "wantarray = ", wantarray, "" );

   return wantarray ? @values : $values[-1];
}

################################################################################
# DB Functions
sub error {
   print STDERR join( '', "ERROR: ", @_, "\n" );
   exit(1);
}

sub dberror {
   my ( $errstr,  $msg );
   my ( $package, $file, $line, $junk ) = caller(1);

   if ( @_ > 1 ) { $msg = shift; }
   else { $msg = "Error accessing database"; }

   $errstr = shift;

   print STDERR "$msg (at $file $line): $errstr\n";
   exit(0);
}

sub debug {
   return unless ($DEBUG);
   my ( $package, $file, $line ) = caller();
   print join( '', "DEBUG (at $file $line): ", @_, "\n" );
}

###############################################################################
# Lock functions
sub create_lock($) {
   my $lockfile = shift;

   unless (-e $lockfile) {
     write_lock($lockfile);
     return;
   }

   unless ( open (LOCKPID, "<$lockfile") ) {
     write_lock($lockfile);
     return;
   }

   my $lockpid = <LOCKPID>;
   close(LOCKPID);
   unless ( $lockpid ) {               # No pid, full disk perhaps, continue
     print "Found lock file '$lockfile' and NULL pid, continuing\n";
     write_lock($lockfile);
     return;
   }

   if ( kill 0 => $lockpid ) {
      chomp $lockpid;
      print "Found lock file '$lockfile' and active process '$lockpid', quitting\n";
      exit 1;
   }

   chomp $lockpid;
   print "Removing lock file '$lockfile' for INACTIVE process '$lockpid'\n";
   write_lock($lockfile);
}

sub write_lock($) {
   my $lockfile = shift;
   open(LOCK, ">$lockfile") or
      die "Error opening lock file '$lockfile': $!";
   print LOCK "$$\n";
   close(LOCK) or
      die "Error closing lock file '$lockfile': $!";
}

sub delete_lock($) {
   my $lockfile = shift;
   if ((unlink $lockfile) != 1) {
      print "Failed to delete lock '$lockfile', quitting\n";
      exit 1;
   }
}

###############################################################################
# Misc functons
sub escape_xml($) {
   my $text= shift;
   $text =~ s/\r\n<\/n\/i>/ /g;
   $text =~ s/</&lt;/g;
   $text =~ s/>/&gt;/g;
   $text =~ s/&(?!(amp;|lt;|gt;))/&amp;/g;
   # Replace MS stuff.
   $text =~ s/\342\200\230/'/g;
   $text =~ s/\342\200\231/'/g;
   $text =~ s/\342\200\246/.../g;
   $text =~ s/\342\200\223/-/g;
   $text =~ s/\240/|/g;
   $text =~ s/\342\200\234/"/g;
   $text =~ s/\342\200\235/"/g;
   # Other stuff
   $text =~ s/\223/"/g;
   $text =~ s/\224/"/g;
   return($text);
}

sub resource_name_to_resourceid {
   my $resource_name = shift;
   my $resourceid;
   if ( $resource_name =~ /(.*)\.anl\.teragrid$/ ) {
      $resourceid = $1 . '.uc.teragrid.org'; 
   } elsif ( $resource_name eq 'bluegene.sdsc.teragrid' ) {
      $resourceid = 'intimidata.sdsc.teragrid.org'; 
   } else {
      $resourceid = $resource_name . '.org';
   }
   return($resourceid);
}
