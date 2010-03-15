#!/usr/bin/perl

use strict;
use warnings;

Test::Portability::Files->import();

options(
    test_ansi_chars   => 0,
    test_dos_length   => 0,
    test_mac_length   => 0,
    test_amiga_length => 0,

);
run_tests();

# The following code is copied from Test::Portability::Files
# with the patch by RT #21631
# See http://rt.cpan.org/Public/Bug/Display.html?id=21631
BEGIN{
package Test::Portability::Files;
use strict;
use ExtUtils::Manifest qw(maniread);
use File::Basename;
#use File::Find;
use File::Spec;
use Test::Builder;

{ no strict;
  $VERSION = '0.05_01';
  @EXPORT = qw(&options &run_tests);
  @EXPORT_OK = @EXPORT;
}

my $Test = Test::Builder->new;

sub import {
    my $self = shift;
    my $caller = caller;
    
    { no strict 'refs';
      *{$caller.'::options'}   = \&options;
      *{$caller.'::run_tests'} = \&run_tests;
    }
    
    $Test->exported_to($caller);
    $Test->plan(tests => 1) unless $Test->has_plan;
}

my %options = (
    use_file_find => 0, 
);

my %tests = (
    ansi_chars    => 1,  
    one_dot       => 1, 
    dir_noext     => 1, 
    special_chars => 1, 
    space         => 1, 
    mac_length    => 1, 
    amiga_length  => 1, 
    vms_length    => 1, 
    dos_length    => 0, 
    case          => 1, 
   'symlink'      => 1, 
);

my %errors_text = (  # wrap the text at this column --------------------------------> |
    ansi_chars    => "These files does not respect the portable filename characters\n"
                    ."as defined by ANSI C and perlport:\n", 

    one_dot       => "These files contain more than one dot in their name:\n", 

    dir_noext     => "These directories have an extension in their name:\n", 

    special_chars => "These files contain special characters that may break on\n".
                     "several systems, please correct:\n", 

    space         => "These files contain space in their name, which is not well\n"
                    ."handled on several systems:\n", 

    mac_length    => "These files have a name more than 31 characters long, which\n"
                    ."will be truncated on Mac OS Classic and old AmigaOS:\n", 

    amiga_length  => "These files have a name more than 107 characters long, which\n"
                    ."will be truncated on recent AmigaOS:\n", 

    vms_length    => "These files have a name or extension too long for VMS (both\n"
                    ."are limited to 39 characters):\n", 

    dos_length    => "These files have a name too long for MS-DOS and compatible\n"
                    ."systems:\n", 

    case          => "The name of these files differ only by the case, which can\n"
                    ."cause real problems on case-insensitive filesystems:", 

   'symlink'      => "The following files are symbolic links, which are not\n"
                    ."supported on several operating systems:", 
);

my %bad_names = ();
my %lc_names = ();

sub options {
    my %opts = @_;
    for my $test (keys %tests) {
        $tests{$test} = $opts{"test_$test"} if exists $opts{"test_$test"}
    }
    for my $opt (keys %options) {
        $options{$opt} = $opts{$opt} if exists $opts{$opt}
    }
    @tests{keys %tests} = (1)x(keys %tests) if $opts{all_tests};
}

sub test_name_portability {
    my($file,$file_name,$file_path,$file_ext);
    
    # extract path, base name and extension
    if($options{use_file_find}) {  # using Find::File
        # skip generated files
        return if $_ eq File::Spec->curdir or $_ eq 'pm_to_blib';
        my $firstdir = (File::Spec->splitdir(File::Spec->canonpath($File::Find::name)))[0];
        return if $firstdir eq 'blib' or $firstdir eq '_build';
        
        $file = $File::Find::name;
        ($file_name,$file_path,$file_ext) = fileparse($file, '\\.[^.]+?');
    
    } else {  # only check against MANIFEST
        $file = shift;
        ($file_name,$file_path,$file_ext) = fileparse($file, '\\.[^.]+?');
        
        #for my $dir (File::Spec->splitdir(File::Spec->canonpath($file_path))) {
        #    test_name_portability($dir)
        #}
        
        $_ = $file_name.$file_ext;
    }
    #print STDERR "file $file\t=> path='$file_path', name='$file_name', ext='$file_ext'\n";
    
    # After this point, the following variables are expected to hold these semantics
    #   $file must contain the path to the file (t/00load.t)
    #   $_ must contain the full name of the file (00load.t)
    #   $file_name must contain the base name of the file (00load)
    #   $file_path must contain the path to the directory containing the file (t/)
    #   $file_ext must contain the extension (if any) of the file (.t)
    
    # check if the name only uses portable filename characters, as defined by ANSI C
    if($tests{ansi_chars}) {
        /^[A-Za-z0-9][A-Za-z0-9._-]*$/ or $bad_names{$file} .= 'ansi_chars,'
    }
    
    # check if the name contains more than one dot
    if($tests{one_dot}) {
        tr/.// > 1 and $bad_names{$file} .= 'one_dot,'
    }
    
    # check if the name contains special chars
    if($tests{special_chars}) {
        m-[!"#\$%&'\(\)\*\+/:;<>\?@\[\\\]^`\{\|\}~]- # " for poor editors
          and $bad_names{$file} .= 'special_chars,'
    }
    
    # check if the name contains a space char
    if($tests{space}) {
        m/ / and $bad_names{$file} .= 'space,'
    }
    
    # check the length of the name, compared to Mac OS Classic max length
    if($tests{mac_length}) {
        length > 31 and $bad_names{$file} .= 'mac_length,'
    }
    
    # check the length of the name, compared to AmigaOS max length
    if($tests{amiga_length}) {
        length > 107 and $bad_names{$file} .= 'amiga_length,'
    }
    
    # check the length of the name, compared to VMS max length
    if($tests{vms_length}) {
        ( length($file_name) <= 39 and length($file_ext) <= 40 ) 
          or $bad_names{$file} .= 'vms_length,'
    }
    
    # check the length of the name, compared to DOS max length
    if($tests{dos_length}) {
        ( length($file_name) <= 8 and length($file_ext) <= 4 ) 
          or $bad_names{$file} .= 'dos_length,'
    }
    
    # check if the name is unique on case-insensitive filesystems
    if($tests{case}) {
        if(not $lc_names{$file} and $lc_names{lc $file}) {
            $bad_names{$file} .= 'case,';
            $bad_names{$lc_names{lc $file}} .= 'case,';
        } else {
            $lc_names{lc $file} = $file
        }
    }
    
    # check if the file is a symbolic link
    if($tests{'symlink'}) {
        -l $file and $bad_names{$file} .= 'symlink,'
    }
    
    # if it's a directory, check that it has no extension
    if($tests{'dir_noext'}) {
        -d $file and tr/.// > 0 and $bad_names{$file} .= 'dir_noext,'
    }
}

sub run_tests {
    fileparse_set_fstype('Unix');
    
    if($options{use_file_find}) {
        # check all files found using File::Find
        find(\&test_name_portability, File::Spec->curdir);
        
    } else {
        # check only against files listed in MANIFEST
        my $manifest = maniread();
        map { test_name_portability($_) } keys %$manifest;
    }
    
    # check the results
    if(keys %bad_names) {
        $Test->ok(0, "File names portability");

        my %errors_list = ();
        for my $file (keys %bad_names)  {
            for my $error (split ',', $bad_names{$file}) {
                $errors_list{$error} = [] if not ref $errors_list{$error};
                push @{$errors_list{$error}}, $file;
            }
        }

        for my $error (sort keys %errors_list) {
            $Test->diag($errors_text{$error});

            for my $file (sort @{$errors_list{$error}}) {
                $Test->diag("   $file")
            }

            $Test->diag(' ')
        }
    } else {
        $Test->ok(1, "File names portability");
    }
}

} # end of BEGIN
