package GraphViz2::DBI;

use strict;
use warnings;
use warnings  qw(FATAL utf8); # Fatalize encoding glitches.

use DBIx::Admin::TableInfo;

use GraphViz2;

use Lingua::EN::PluralToSingular 'to_singular';

use Moo;

has catalog =>
(
	default  => sub{return undef},
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has dbh =>
(
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 1,
);

has graph =>
(
	default  => sub{return {} },
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has schema =>
(
	default  => sub{return undef},
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has table =>
(
	default  => sub{return '%'},
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has table_info =>
(
	default  => sub{return {} },
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has type =>
(
	default  => sub{return 'TABLE'},
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

our $VERSION = '2.29';

# -----------------------------------------------

sub BUILD
{
	my($self) = @_;

	$self -> graph
	(
		$self -> graph ||
		GraphViz2 -> new
		(
			edge   => {color => 'grey'},
			global => {directed => 1},
			graph  => {rankdir => 'TB'},
			logger => '',
			node   => {color => 'blue', shape => 'oval'},
		)
	);

} # End of BUILD.

# -----------------------------------------------

sub create
{
	my($self, %arg) = @_;
	my($name)       = $arg{name}    || '';
	my($exclude)    = $arg{exclude} || [];
	my($include)    = $arg{include} || [];
	my($info)       = DBIx::Admin::TableInfo -> new(dbh => $self -> dbh) -> info;

	my(%include);

	@include{@$include} = (1) x @$include;

	delete $$info{$_} for @$exclude;

	# This 'if' stops us excluding all tables :-).

	if ($#$include >= 0)
	{
		delete $$info{$_} for grep{! $include{$_} } keys %$info;
	}

	$self -> table_info($info);

	my($port, %port);

	for my $table_name (sort keys %$info)
	{
		# Port 1 is the table name.

		$port              = 1;
		$port{$table_name} = {};

		for my $column_name (map{s/^"(.+)"$/$1/; $_} sort keys %{$$info{$table_name}{columns} })
		{
			$port++;

			$port{$table_name}{$column_name} = "<port$port>";

		}
	}

	for my $table_name (sort keys %$info)
	{
		# Step 1: Make the table name + 'N columns-in-one' be a horizontal record.

		my($label) =
		[
			{text => $table_name},
		];

		for my $column (sort keys %{$port{$table_name} })
		{
			push @$label,
			{
				port => $port{$table_name}{$column},
				text => $column,
			};
		}

		# Step 2: Make the N columns be a vertical record.

		$$label[1]{port}        = "{$$label[1]{port}";
		$$label[$#$label]{text} .= '}';

		$self -> graph -> add_node(name => $table_name, label => [@$label]);
	}

	my($destination_port);
	my($fkcolumn_name);
	my($pktable_name, $primary_key_name);
	my($singular_name, $source_port);

	for my $table_name (sort keys %$info)
	{
		for my $other_table (sort keys %{$$info{$table_name}{foreign_keys} })
		{
			$fkcolumn_name    = $$info{$table_name}{foreign_keys}{$other_table}{FKCOLUMN_NAME};
			$source_port      = $port{$other_table}{$fkcolumn_name} || 2;
			$pktable_name     = $$info{$table_name}{foreign_keys}{$other_table}{PKTABLE_NAME};
			$singular_name    = to_singular($pktable_name);
			$primary_key_name = $fkcolumn_name;
			$primary_key_name =~ s/${singular_name}_//;
			$destination_port = $port{$table_name}{$primary_key_name} || 2;

			$self -> graph -> add_edge(from => "$other_table:$source_port", to => "$table_name:$destination_port");
		}
	}

	if ($name)
	{
		$self -> graph -> add_node(name => $name, shape => 'doubleoctagon');

		for my $table_name (sort keys %$info)
		{
			$self -> graph -> add_edge(from => $name, to => $table_name);
		}
	}

	return $self;

} # End of create.

# -----------------------------------------------

1;

=pod

=head1 NAME

L<GraphViz2::DBI> - Visualize a database schema as a graph

=head1 Synopsis

	#!/usr/bin/env perl

	use strict;
	use warnings;

	use DBI;

	use GraphViz2;
	use GraphViz2::DBI;

	use Log::Handler;

	# ---------------

	exit 0 if (! $ENV{DBI_DSN});

	my($logger) = Log::Handler -> new;

	$logger -> add
		(
		 screen =>
		 {
			 maxlevel       => 'debug',
			 message_layout => '%m',
			 minlevel       => 'error',
		 }
		);

	my($graph) = GraphViz2 -> new
		(
		 edge   => {color => 'grey'},
		 global => {directed => 1},
		 graph  => {rankdir => 'TB'},
		 logger => $logger,
		 node   => {color => 'blue', shape => 'oval'},
		);
	my($attr)              = {};
	$$attr{sqlite_unicode} = 1 if ($ENV{DBI_DSN} =~ /SQLite/i);
	my($dbh)               = DBI -> connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS}, $attr);

	$dbh -> do('PRAGMA foreign_keys = ON') if ($ENV{DBI_DSN} =~ /SQLite/i);

	my($g) = GraphViz2::DBI -> new(dbh => $dbh, graph => $graph);

	$g -> create(name => '');

	my($format)      = shift || 'svg';
	my($output_file) = shift || File::Spec -> catfile('html', "dbi.schema.$format");

	$graph -> run(format => $format, output_file => $output_file);

See scripts/dbi.schema.pl (L<GraphViz2/Scripts Shipped with this Module>).

=head1 Description

Takes a database handle, and graphs the schema.

You can write the result in any format supported by L<Graphviz|http://www.graphviz.org/>.

Here is the list of L<output formats|http://www.graphviz.org/content/output-formats>.

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See L<http://savage.net.au/Perl-modules/html/installing-a-module.html>
for help on unpacking and installing distros.

=head1 Installation

Install L<GraphViz2> as you would for any C<Perl> module:

Run:

	cpanm GraphViz2

or run:

	sudo cpan GraphViz2

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = GraphViz2::DBI -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<GraphViz2::DBI>.

Key-value pairs accepted in the parameter list:

=over 4

=item o dbh => $dbh

This options specifies the database handle to use.

This key is mandatory.

=item o graph => $graphviz_object

This option specifies the GraphViz2 object to use. This allows you to configure it as desired.

The default is GraphViz2 -> new. The default attributes are the same as in the synopsis, above,
except for the graph label of course.

This key is optional.

=back

=head1 Methods

=head2 create(exclude => [], include => [], name => $name)

Creates the graph, which is accessible via the graph() method, or via the graph object you passed to new().

Returns $self to allow method chaining.

Parameters:

=over 4

=item o exclude

An optional arrayref of table names to exclude.

If none are listed for exclusion, I<all> tables are included.

=item o include

An optional arrayref of table names to include.

If none are listed for inclusion, I<all> tables are included.

=item o name

$name is the string which will be placed in the root node of the tree.
It may be omitted, in which case the root node is omitted.

=back

=head2 graph()

Returns the graph object, either the one supplied to new() or the one created during the call to new().

=head1 FAQ

=head2 Does GraphViz2::DBI work with MySQL/MariaDB databases?

Yes. But see these L<warnings|https://metacpan.org/pod/DBIx::Admin::TableInfo#Description> when using MySQL/MariaDB.

I'm currently using MariaDB V 5.5.38.

=head2 Does GraphViz2::DBI work with SQLite databases?

Yes. As of V 2.07, this module uses SQLite's "pragma foreign_key_list($table_name)" to emulate L<DBI>'s
$dbh -> foreign_key_info(...).

=head2 What is returned by SQLite's "pragma foreign_key_list($table_name)"?

	Fields returned are:
	0: COUNT   (0, 1, ...)
	1: KEY_SEQ (0, or column # (1, 2, ...) within multi-column key)
	2: FKTABLE_NAME
	3: PKCOLUMN_NAME
	4: FKCOLUMN_NAME
	5: UPDATE_RULE
	6: DELETE_RULE
	7: 'NONE' (Constant string)

=head2 Are any sample scripts shipped with this module?

Yes. See L<GraphViz2/FAQ> and L<GraphViz2/Scripts Shipped with this Module>.

=head1 Thanks

Many thanks are due to the people who chose to make L<Graphviz|http://www.graphviz.org/> Open Source.

And thanks to L<Leon Brocard|http://search.cpan.org/~lbrocard/>, who wrote L<GraphViz>, and kindly gave me co-maint of the module.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Machine-Readable Change Log

The file CHANGES was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=GraphViz2>.

=head1 Author

L<GraphViz2> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2011.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2011, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
