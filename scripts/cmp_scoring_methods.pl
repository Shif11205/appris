#/usr/bin/env perl -w

use strict;

use Cwd;
use File::Find;
use Getopt::Long;
use Set::Scalar;

my ($a_file) = undef;
my ($b_file) = undef;
my ($out_file) = undef;

&GetOptions(
	'a-file|a=s' => \$a_file,
	'b-file|b=s' => \$b_file,
	'out-file|o=s' => \$out_file
);

my %file_map = (
	'a' => $a_file,
	'b' => $b_file
);

my %cmp_info;
my @known_opt_col_names = ('ccds_id', 'mane_select');
my %opt_col_map = map { $_ => Set::Scalar->new() } @known_opt_col_names;
while (my ($trial_key, $trial_file) = each(%file_map) ) {

	open my $fh, $trial_file
	  or die("failed to open file: '$trial_file'");

	my $first_line = <$fh>;
	chomp $first_line;
	my @field_names = split("\t", $first_line);
	my %name_to_idx = map { $field_names[$_],  $_ } 0 .. $#field_names;

	my @file_opt_col_names = grep { exists($name_to_idx{$_}) } @known_opt_col_names;
	foreach my $col_name (@file_opt_col_names) {
		$opt_col_map{$col_name}->insert($trial_key);
	}

	while (<$fh>) {
		my $line = $_;
		chomp $line;

		my @fields = split("\t", $line);
		my $gene_id = $fields[ $name_to_idx{'gene_id'} ];
		my $transc_id = $fields[ $name_to_idx{'transc_id'} ];
		$cmp_info{$gene_id}{$trial_key}{$transc_id} = {
			'pi_label' => $fields[ $name_to_idx{'pi_label'} ]
		};

		foreach my $col_name (@file_opt_col_names) {
			$cmp_info{$gene_id}{$trial_key}{$transc_id}{$col_name} = $fields[ $name_to_idx{$col_name} ];
		}
	}
	close $fh;
}

my %diff_info;
my @obs_opt_col_names = grep { $opt_col_map{$_}->size > 0 } @known_opt_col_names;
while (my($gene_id, $gene_info) = each %cmp_info) {

	next unless ( exists $cmp_info{$gene_id}{'a'} && exists $cmp_info{$gene_id}{'b'} );
	my $transc_set_a = Set::Scalar->new(keys %{$cmp_info{$gene_id}{'a'}});
	my $transc_set_b = Set::Scalar->new(keys %{$cmp_info{$gene_id}{'b'}});
	next unless ( $transc_set_a->is_equal($transc_set_b) );

	my @transc_ids = keys %{$cmp_info{$gene_id}{'a'}};
	my %p1_set_info = (
		'a' => Set::Scalar->new(),
		'b' => Set::Scalar->new()
	);

	foreach my $transc_id (@transc_ids) {
		foreach my $trial_key (('a', 'b')) {
			my $pi_label = $cmp_info{$gene_id}{$trial_key}{$transc_id}{'pi_label'};
			if ($pi_label eq 'PRINCIPAL:1') {
				$p1_set_info{$trial_key}->insert($transc_id);
			}
		}
	}

	if ( ! $p1_set_info{'a'}->is_equal($p1_set_info{'b'}) ) {
		foreach my $transc_id (@transc_ids) {
			my $pi_label_a = $cmp_info{$gene_id}{'a'}{$transc_id}{'pi_label'};
			my $pi_label_b = $cmp_info{$gene_id}{'b'}{$transc_id}{'pi_label'};
			if ( grep(/^PRINCIPAL:1$/, ($pi_label_a, $pi_label_b)) ) {
				my %transc_info = (
					'gene_id' => $gene_id,
					'transc_id' => $transc_id,
					'pi_label_a' => $pi_label_a,
					'pi_label_b' => $pi_label_b
				);

				# TODO: check if optional column values are identical for 'a' and 'b'
				foreach my $col_name (@obs_opt_col_names) {
				  my $trial_key = $opt_col_map{$col_name}->[0];
					$transc_info{$col_name} = $cmp_info{$gene_id}{$trial_key}{$transc_id}{$col_name};
				}

				$diff_info{$gene_id}{$transc_id} = \%transc_info;
			}
		}
	}
}

if ( scalar(keys %diff_info) > 0 ) {

	open(my $fh, '>', $out_file)
		or die("failed to open file '${out_file}'");
	my @field_names = ('gene_id', 'transc_id', 'pi_label_a', 'pi_label_b');
	push(@field_names, @obs_opt_col_names);
	print $fh join("\t", @field_names)."\n";
	foreach my $gene_info (values %diff_info) {
		foreach my $transc_info (values %{$gene_info}) {

			my @row = (
				$transc_info->{'gene_id'},
				$transc_info->{'transc_id'},
				$transc_info->{'pi_label_a'},
				$transc_info->{'pi_label_b'}
			);

			my @opt_col_values = map { $transc_info->{$_} } @obs_opt_col_names;
			push(@row, @opt_col_values);

			print $fh join("\t", @row)."\n";
		}
	}
	close $fh;
}
