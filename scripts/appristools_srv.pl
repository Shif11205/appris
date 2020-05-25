#!/usr/bin/perl -w

use 5.14.0;
use strict;
use warnings;

use Getopt::Long;
use Config::IniFiles;
use FindBin;
use JSON;
use Data::Dumper;
use APPRIS::Utils::File qw( getStringFromFile getTotalStringFromFile printStringIntoFile );
use APPRIS::Utils::Exception qw( info throw warning );

# Input parameters
my ($steps) = undef;
my ($release) = undef;
my ($relnotes_file) = undef;
my ($conf_file) = undef;
my ($dev_mode) = undef;
my ($loglevel) = undef;

&GetOptions(
	'steps|p=s'			=> \$steps,
	'release|r=s'		=> \$release,
	'notes|n=s'			=> \$relnotes_file,	
	'conf|c=s'			=> \$conf_file,
	'dev'				=> \$dev_mode,
	'loglevel|l=s'		=> \$loglevel,
);

# Check required parameters
unless ( defined $steps and defined $conf_file ) {
	print `perldoc $0`;
	print "\nBad option combination of input data\n\n";
	exit 1;
}

###################
# Global variable #
###################
use vars qw(
	$SRV_NAME
	$SRV_DB_HOST
	$SRV_DB_USER
	$SRV_DB_PWD
	$SRV_WSDIR
	$SRV_PUB_RELEASE_DIR
	$SRV_FEATURES_DIR
	
	$LOC_WSDIR
	$LOC_FEATURES_DIR
	
	$APPRIS_DATA_DIR
	$APPRIS_FEATURES_DIR
	
	$FTP_ENSEMBL_PUB
	$FTP_REFSEQ_PUB
);

$SRV_NAME				= $dev_mode ? 'appris-dev@appris' : 'appris@appris' ;
$SRV_DB_HOST			= 'localhost';
$SRV_DB_USER			= 'appris';
$SRV_DB_PWD				= 'appris.appris';
$SRV_WSDIR				= '/local2/appris';
$SRV_PUB_RELEASE_DIR	= $SRV_WSDIR.'/pub/releases';
$SRV_FEATURES_DIR		= $SRV_WSDIR.'/features';

$LOC_WSDIR				= '/tmp/appris';
$LOC_FEATURES_DIR		= $LOC_WSDIR.'/features';

$APPRIS_DATA_DIR 		= $ENV{APPRIS_DATA_DIR};
$APPRIS_FEATURES_DIR	= $ENV{APPRIS_FEATURES_DIR};
#$APPRIS_DATA_DIR		= '/home/jmrodriguez/projects/APPRIS/data';
#$APPRIS_FEATURES_DIR	= '/home/jmrodriguez/projects/APPRIS/features';

$FTP_ENSEMBL_PUB		= 'ftp://ftp.ensembl.org/pub';
$FTP_REFSEQ_PUB			= 'ftp://ftp.ncbi.nlm.nih.gov';

# Extract Server config file
my ($config_json) = JSON->new();
my ($CONFIG) = $config_json->decode( getStringFromFile($conf_file) );
my (@CFG_SPECIES) = sort { $CONFIG->{'species'}->{$a}->{'order'} <=> $CONFIG->{'species'}->{$b}->{'order'} } keys(%{$CONFIG->{'species'}});
my ($CONFIG_VERSION) = $CONFIG->{'version'};


#################
# Method bodies #
#################
sub download_genefiles();
sub _download_genefiles_ensembl($$$$);
sub copy_genefiles();
sub upload_annot_files();
sub upload_genefiles();


# Main subroutine
sub main()
{		
	# Step 1: download gene data files
	if ( $steps =~ /1/ )
	{		
		info("-- download gene data files...");
		download_genefiles();
	}
	
	# Step 2: copy gene data to workspace space
	if ( $steps =~ /2/ )
	{		
		info("-- copy gene data to workspace space...");
		copy_genefiles();
	}

	# Step 3: upload annotation files to server
	if ( $steps =~ /3/ )
	{
		if ( defined $release and defined $relnotes_file and defined $conf_file ) {
			info("-- upload annotation files to server...");
			upload_annotfiles();		
		}
		else { throw("you need to add all parameters") }
	}
	
	# Step 4: upload gene data files to server
	if ( $steps =~ /4/ )
	{		
		info("-- upload gene data-files to server...");
		upload_genefiles();
	}

#	#�Delete local workspace
#	info("-- delete local workspace...");
#	eval {
#		my ($cmd) = "rm -rf $LOC_WSDIR";
#		info($cmd);
#		system($cmd);
#	};
#	throw("deleting local workspace") if($@);
	
}

####################
# SubMethod bodies #
####################

sub upload_annotfiles()
{
	# declare local variables
	my ($srv_reldir) = $SRV_PUB_RELEASE_DIR.'/'.$release;
	my ($loc_reldir) = $LOC_WSDIR.'/'.$release;
		
	# Create local workspace
	info("-- create local workspace...");
	eval {
		my ($cmd) = "rm -rf $loc_reldir && mkdir -p $loc_reldir";
		info($cmd);
		system($cmd);
	};
	throw("creating local workspace") if($@);
	
	# add into local workspace with datafiles, for each species
	info("-- add into local workspace with datafiles, for each species...");
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};		

		foreach my $cfg_assembly (@{$cfg_species->{'assemblies'}}) {
			for ( my $i = 0; $i < scalar(@{$cfg_assembly->{'datasets'}}); $i++ ) {
				my ($cfg_dataset) = $cfg_assembly->{'datasets'}->[$i];
				next if ( exists $cfg_dataset->{'type'} and $cfg_dataset->{'type'} ne 'current' );
				if ( exists $cfg_dataset->{'database'} ) {
					my ($as_name) = $cfg_assembly->{'name'};
					my ($ds_id) = $cfg_dataset->{'id'};
					my ($ds_dir) = $APPRIS_DATA_DIR.'/'.$CONFIG_VERSION.'/'.$species_id.'/'.$ds_id;
					my ($relspe_dir) = $loc_reldir.'/datafiles/'.$species_id;
					my ($reldat_dir) = $relspe_dir.'/'.$ds_id;
					
					eval {
						my ($cmd) = "mkdir -p $relspe_dir && cp -rp $ds_dir $relspe_dir/.";
						info($cmd);
						system($cmd);
					};
					throw("creating local workspace") if($@);
				}
			}			
		}		
	}	
		
	# create release note for given release
	info("-- create release note for given release...");
	my ($release_notes) = getTotalStringFromFile($relnotes_file);
	my ($find) = 0;
	my ($rel_notes) = "";
	foreach my $nline (@{$release_notes}) {		
		if ( $nline =~ /^## $release/ ) {
			$find = 1;
		}
		elsif ( $nline =~ /^___/ ) {
			$find = 0;
		}
		if ( $find == 1 ) {
			$rel_notes .= $nline;
		}
	}
	if ( $rel_notes ne '' ) {
		my ($relnotes_file) = $loc_reldir.'/relnotes.md';
		my ($plog) = printStringIntoFile($rel_notes, $relnotes_file);
		throw("Printing _get_ccds_stats_content\n") unless(defined $plog);		
	}

	# upload datafiles to server
	info("-- upload datafiles to server...");
	eval {
		my ($cmd) = "cd $loc_reldir && tar -cpf - . | ssh $SRV_NAME 'mkdir -p $srv_reldir; cd $srv_reldir/; tar -xf -'";
		info($cmd);
		system($cmd);
	};
	throw("updating datafiles to server") if($@);

	my @cached_species;
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};
		my @cfg_species_datasets = map { @{$_->{'datasets'}} } @{$cfg_species->{'assemblies'}};
		my $num_current_datasets = grep {
			! exists $_->{'type'} or $_->{'type'} eq 'current'
		} @cfg_species_datasets;
		my $num_cached_datasets = grep {
			exists $_->{'type'} and $_->{'type'} =~ /^(?:archive|current):(.*)$/
		} @cfg_species_datasets;
		if ( $num_cached_datasets > 0 && $num_current_datasets == 0 ) {
			push(@cached_species, $species_id);
		}
	}
	if (@cached_species) {
		info("-- make directories on server for species with only cached datasets...");
		my $species_dirnames = join(' ', @cached_species);
		my $srv_data_dir = $srv_reldir.'/datafiles';
		eval {
			my ($cmd) = "ssh $SRV_NAME 'mkdir -p $srv_data_dir; cd $srv_data_dir; mkdir -p $species_dirnames'";
			info($cmd);
			system($cmd);
		};
		throw("creating species directories") if($@);
	}
	
	# import databases into server
	info("-- import databases into server...");
	my ($cmd_imp) = "";
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};
		
		foreach my $cfg_assembly (@{$cfg_species->{'assemblies'}}) {
			foreach my $cfg_dataset (@{$cfg_assembly->{'datasets'}}) {				
				next if ( exists $cfg_dataset->{'type'} and $cfg_dataset->{'type'} ne 'current' );
				next if ( exists $cfg_dataset->{'queryable'} && ! $cfg_dataset->{'queryable'} );
				if ( exists $cfg_dataset->{'database'} and exists $cfg_dataset->{'database'}->{'name'} ) {
					my ($ds_id) = $cfg_dataset->{'id'};
					my ($ds_db) = $cfg_dataset->{'database'}->{'name'}.'_'.$ds_id;					
					my ($srv_relspe_dir) = $srv_reldir.'/datafiles/'.$species_id;
					my ($srv_reldat_dir) = $srv_relspe_dir.'/'.$ds_id;
					my ($srv_db_file) = $srv_reldat_dir.'/appris_db.dump.gz';
					$cmd_imp .= "appris_db_import -d $ds_db -h $SRV_DB_HOST -u root -i $srv_db_file && ";
				}
			}			
		}		
	}
	if ( $cmd_imp ne '' ) {
		eval {
			$cmd_imp =~ s/\s*\&\&\s*$//g;
			my ($cmd) = "ssh $SRV_NAME '$cmd_imp'";
			info($cmd);
			system($cmd);
		};
		throw("importing databases in the server") if($@);		
	}

	# link to archives
	info("-- link to archives and unchanged current data...");
	my ($cmd_link) = "";
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};
		my ($srv_relspe_dir) = $srv_reldir.'/datafiles/'.$species_id;		
		foreach my $cfg_assembly (@{$cfg_species->{'assemblies'}}) {
			my ($as_name) = $cfg_assembly->{'name'};
			my ($as_ds_id) = '';
			foreach my $cfg_dataset (@{$cfg_assembly->{'datasets'}}) {
				my ($ds_id) = $cfg_dataset->{'id'};
				if ( exists $cfg_dataset->{'type'} ) {
					my ($ds_type) = $cfg_dataset->{'type'};

					# link to archived and unchanged current datasets
					if ( $ds_type =~ /^(?:archive|current):(.*)$/ ) {
						my ($srv_arhdir) = $SRV_PUB_RELEASE_DIR.'/'.$1;
						my ($srv_arhspe_dir) = $srv_arhdir.'/datafiles/'.$species_id;
						$cmd_link .= "cd $srv_relspe_dir && ln -s $srv_arhspe_dir/$ds_id $srv_relspe_dir/$ds_id && ";
					}

					# get the FIRST dataset id from the current assembly
					if ( $as_ds_id eq '' and ( $ds_type eq 'current'
							or $ds_type =~ /^(?:archive|current):(.*)$/ ) ) {
						$as_ds_id = $ds_id;
					}
				}
			}
			# create assembly link to first current dataset
			if ( $as_ds_id ne '' ) {
				$cmd_link .= "cd $srv_relspe_dir && ln -s $as_ds_id $as_name && ";
			}
		}		
	}
	if ( $cmd_link ne '' ) {
		eval {
			$cmd_link =~ s/\s*\&\&\s*$//g;
			my ($cmd) = "ssh $SRV_NAME '$cmd_link'";
			info($cmd);
			system($cmd);
		};
		throw("linking to archives") if($@);		
	}		

} #�end upload_annotfiles

sub upload_genefiles()
{
	# upload genefiles to server
	eval {
		my ($cmd) = "cd $LOC_FEATURES_DIR && tar -cpf - . | ssh $SRV_NAME 'cd $SRV_FEATURES_DIR/; tar -xf -'";
		info($cmd);
		system($cmd);
	};
	throw("updating genefiles to server") if($@);
} #�end upload_genefiles

sub copy_genefiles()
{
	# add into local workspace with datafiles, for each species
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};
		
		foreach my $cfg_assembly (@{$cfg_species->{'assemblies'}}) {
			foreach my $cfg_dataset (@{$cfg_assembly->{'datasets'}}) {
				if ( exists $cfg_dataset->{'source'} and exists $cfg_dataset->{'source'}->{'name'} and exists $cfg_dataset->{'source'}->{'version'} ) {
					my ($as_name) = $cfg_assembly->{'name'};
					my ($ds_id) = $cfg_dataset->{'id'};
					my ($ds_v)  = $cfg_dataset->{'source'}->{'version'};
					my ($relspe_dir) = $LOC_WSDIR.'/features/'.$species_id;
					my ($a_featdir) = $APPRIS_FEATURES_DIR.'/'.$species_id;
										
					# copy genefiles from data source
					if ( $cfg_dataset->{'source'}->{'name'} eq 'ensembl' ) {						
						eval {
							my ($datadir) = "e$ds_v";
							unless ( -e "$a_featdir/$datadir" ) {
								my ($cmd) = "mkdir $a_featdir & cd $relspe_dir && tar -cf - $datadir | (cd $a_featdir; tar -xf -) ";
								info($cmd);
								system($cmd);
							}
						};
						throw("creating data workspace") if($@);
					}					
					elsif ( $cfg_dataset->{'source'}->{'name'} eq 'refseq' ) {						
						eval {
							my ($datadir) = "rs$ds_v";
							unless ( -e "$a_featdir/$datadir" ) {
								my ($cmd) = "mkdir $a_featdir & cd $relspe_dir && tar -cf - $datadir | (cd $a_featdir; tar -xf -) ";
								info($cmd);
								system($cmd);
							}
						};
						throw("creating data workspace") if($@);
					}					
				}
			}			
		}		
	}
} #�end copy_genefiles

sub download_genefiles()
{
	# add into local workspace with datafiles, for each species
	foreach my $species_id ( @CFG_SPECIES ) {
		my ($cfg_species) = $CONFIG->{'species'}->{$species_id};
		
		foreach my $cfg_assembly (@{$cfg_species->{'assemblies'}}) {
			foreach my $cfg_dataset (@{$cfg_assembly->{'datasets'}}) {
				if ( exists $cfg_dataset->{'source'} and exists $cfg_dataset->{'source'}->{'name'} and exists $cfg_dataset->{'source'}->{'version'} ) {
					my ($as_name) = $cfg_assembly->{'name'};
					my ($ds_id) = $cfg_dataset->{'id'};
					my ($ds_type) = $cfg_dataset->{'type'};
					my ($ds_v)  = $cfg_dataset->{'source'}->{'version'};
					my ($relspe_dir) = $LOC_WSDIR.'/features/'.$species_id;
					
					# only download current datasets
					if ( $ds_type eq 'current' ) {
						#�create data workspace
						eval {
							my ($cmd) = "mkdir -p $relspe_dir";
							info($cmd);
							system($cmd);
						};
						throw("creating data workspace") if($@);
						
						# download genefiles from data source
						if ( $cfg_dataset->{'source'}->{'name'} eq 'ensembl' ) {
							_download_genefiles_ensembl($ds_v, $species_id, $as_name, $relspe_dir);
						}
						elsif ( $cfg_dataset->{'source'}->{'name'} eq 'refseq' ) {
							my ($taxid) = $cfg_species->{'taxid'};
							_download_genefiles_refseq($ds_v, $species_id, $taxid, $as_name, $relspe_dir);
						}						
					}
				}
			}			
		}		
	}
}
sub _download_genefiles_ensembl($$$$)
{
	# declare local variables
	my ($e_version, $species_id, $as_name, $outdir) = @_;
	my ($species_filename) = ucfirst($species_id).'.'.$as_name;
	my ($datadir) = $outdir.'/'."e$e_version";
	my ($outfile_data)   = $species_id.'.annot.gtf';
	my ($outfile_transc) = $species_id.'.transc.fa';
	my ($outfile_transl) = $species_id.'.transl.fa';
	
	#�create data workspace
	eval {
		my ($cmd) = "mkdir -p $datadir";
		info($cmd);
		system($cmd);
	};
	throw("creating genedata workspace") if($@);
	
	#�download files	
	eval {
		my ($i) = "$species_filename.$e_version.gtf";
		my ($cmd) = "wget $FTP_ENSEMBL_PUB/release-$e_version/gtf/$species_id/$i.gz           -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_data";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: ensembl data") if($@);
	unless ( -e "$datadir/$outfile_data" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: ensembl data has not been saved");
		return undef;
	}	

	eval {
		my ($i) = "$species_filename.cdna.all.fa";
 		my ($cmd) = "wget $FTP_ENSEMBL_PUB/release-$e_version/fasta/$species_id/cdna/$i.gz    -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_transc";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: ensembl cdna") if($@);						
	unless ( -e "$datadir/$outfile_transc" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: ensembl cdna has not been saved");
		return undef;
	}	

	eval {
		my ($i) = "$species_filename.pep.all.fa";
		my ($cmd) = "wget $FTP_ENSEMBL_PUB/release-$e_version/fasta/$species_id/pep/$i.gz      -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_transl";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: ensembl pep") if($@);	 
	unless ( -e "$datadir/$outfile_transl" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: ensembl pep has not been saved");
		return undef;
	}	

}
sub _download_genefiles_refseq($$$$$)
{
	# declare local variables
	my ($r_version, $species_id, $taxid, $as_name, $outdir) = @_;
	my ($release_url) = "$FTP_REFSEQ_PUB/genomes/all/annotation_releases/$taxid/$r_version";
	my ($species_name) = ucfirst($species_id);
	my ($datadir) = $outdir.'/'."rs$r_version";
	my ($readme_file) = "README_${species_name}_annotation_release_${r_version}";
	my ($outfile_data)   = $species_id.'.annot.gtf';
	my ($outfile_transc) = $species_id.'.transc.fa';
	my ($outfile_transl) = $species_id.'.transl.fa';
	
	#�create data workspace
	eval {
		my ($cmd) = "mkdir -p $datadir";
		info($cmd);
		system($cmd);
	};
	throw("creating genedata workspace") if($@);
	
	#�download files	
	my ($readme_file_url) = "$release_url/$readme_file";
	eval {
		my ($cmd) = "wget $readme_file_url -P $datadir";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq readme file") if($@);			

	my ($as_label) = _get_refseq_assembly_label("$datadir/$readme_file", $as_name);
	my ($as_url) = "$release_url/$as_label";
	eval {
		my ($i) = "${as_label}_genomic.gff";
		my ($cmd) = "wget $as_url/$i.gz -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_data";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq data") if($@);
	unless ( -e "$datadir/$outfile_data" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);		
		warning("downloading genefile: refseq data has not been saved");
		print STDERR "KK\n";
		return undef;
	}	

	eval {
		my ($i) = "${as_label}_rna.fna";
		my ($cmd) = "wget $as_url/$i.gz -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_transc";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq cdna") if($@);						
	unless ( -e "$datadir/$outfile_transc" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: refseq cdna has not been saved");
		return undef;
	}	

	eval {
		my ($i) = "${as_label}_protein.faa";
		my ($cmd) = "wget $as_url/$i.gz -P $datadir && cd $datadir && gzip -d $i.gz && ln -s $i $outfile_transl";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq pep") if($@);						
	unless ( -e "$datadir/$outfile_transl" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: refseq pep has not been saved");
		return undef;
	}	

	my ($genpept_file_name) = "${as_label}_protein.gpff";
	eval {
		my ($cmd) = "wget $as_url/$genpept_file_name.gz -P $datadir";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq protein report") if($@);
	unless ( -e "$datadir/$genpept_file_name.gz" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: refseq protein report has not been saved");
		return undef;
	}	

	eval {
		my ($cmd) = "wget $FTP_REFSEQ_PUB/gene/DATA/gene2ensembl.gz                                     -P $datadir";
		info($cmd);
		system($cmd);
	};
	throw("downloading genefile: refseq xref with ensembl") if($@);						
	unless ( -e "$datadir/gene2ensembl.gz" ) {
		my ($cmd) = "rm -rf $datadir";
		info($cmd);
		system($cmd);
		warning("downloading genefile: refseq protein report has not been saved");
		return undef;
	}	
	 
	# uncompress files
	eval {
		my ($cmd) = "cd $datadir && gzip -d *.gz";
		info($cmd);
		system($cmd);
	};
	throw("uncompressing genefiles") if($@);
		
}

sub _get_refseq_assembly_label($$)
{
	my ($readme_file, $cfg_as_name) = @_;

	open(my $fh, $readme_file)
		or die("failed to open README");
	chomp(my @lines = <$fh>);
	close $fh
		or die("failed to close README");

	my (@as_list_idxs) = grep {
		$lines[$_] eq 'ANNOTATED ASSEMBLIES:' } 0 .. $#lines;
	if ( scalar(@as_list_idxs) != 1 ) {
		my $qualifier = scalar(@as_list_idxs) > 1 ? "unique" : "any" ;
		die("failed to find $qualifier assembly listing in README");
	}

	my (@as_start_idxs);
	my (@as_decl_idxs) = grep {
		$lines[$_] =~ /^\*\s*(?:REFERENCE|ALTERNATE\s+\d+):/ } 0 .. $#lines;
	if (@as_decl_idxs) {
		@as_start_idxs = map { $_ + 1 } @as_decl_idxs;
	} else {
		@as_start_idxs = $as_list_idxs[0] + 1;
	}

	my (@as_labels);
	foreach my $i (@as_start_idxs) {
		continue unless $i < $#lines;

		my ($matching_as_name);
		if ( $lines[$i] =~ /^ASSEMBLY NAME:\s+(\S+)\s*$/ ) {
			my ($as_name) = $1;
			if ( $cfg_as_name eq $as_name =~ s/\.p\d+$//r ) {  # allow for patched assembly name
				$matching_as_name = $as_name;
			} else {
				next;
			}
		} else {
			die("failed to read assembly name in README");
		}

		my ($as_acc_ver);
		if ( $lines[$i+1] =~ /^ASSEMBLY ACCESSION:\s+(\S+)\s*$/ ) {
			$as_acc_ver = $1;
		} else {
			die("failed to read assembly accession in README");
		}

		if ($matching_as_name) {
			push(@as_labels, "${as_acc_ver}_${matching_as_name}");
		}
	}

	if ( scalar(@as_labels) != 1 ) {
		my $qualifier = scalar(@as_labels) > 1 ? "unique" : "any" ;
		die("failed to obtain $qualifier assembly label from README");
	}

	return $as_labels[0]
}

main();


1;

__END__

=pod

=head1 NAME

appristools_srv

=head1 DESCRIPTION

Executes all APPRIS 'steps  

=head2 Arguments (data input):

  -p, --steps {string} <Process steps>
	* 1 - Download gene data files -\n
	* 2 - Copy gene data to workspace space -\n	
	* 3 - Upload annotation files to server -\n
	* 4 - Upload gene data files to server -\n
  
  -r, --release   {string} <Release identifier>
  
  -n, --notes     {file}   <Release Notes file - TXT format - >
		
  -c, --conf      {file}   <Config file for all gene datatasets (JSON format)>
  
  --dev   <Run pipeline against development server>

=head1 EXAMPLE

	appristools_srv \
		-p 123
		-r 2016_06.v17 \
		-n changelog.md \
		-c ws/config.json

=head1 AUTHOR

Jose Manuel Rodriguez Carrasco -jmrodriguez@cnio.es- (INB-GN2,CNIO)

=cut
