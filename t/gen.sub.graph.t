# Annotation: Demonstrates a subgraph (with a frame because the subgroup is called cluster_*).

use strict;
use warnings;
use File::Spec;
use GraphViz2;

my $graph = GraphViz2->new(
	edge   => {color => 'grey'},
	global => {directed => 1},
	graph  => {label => 'sub.graph.pl', rankdir => 'TB'},
	node   => {shape => 'oval'},
);

$graph->add_node(name => 'Carnegie', shape => 'circle');
$graph->add_node(name => 'Murrumbeena', shape => 'doublecircle', color => 'green');
$graph->add_node(name => 'Oakleigh',    color => 'blue');
$graph->add_edge(from => 'Murrumbeena', to    => 'Carnegie', arrowsize => 2);
$graph->add_edge(from => 'Murrumbeena', to    => 'Oakleigh', color => 'brown');

$graph->push_subgraph(
 name  => 'cluster_1',
 graph => {label => 'Child'},
 node  => {color => 'magenta', shape => 'diamond'},
);
$graph->add_node(name => 'Chadstone', shape => 'hexagon');
$graph->add_node(name => 'Waverley', color => 'orange');
$graph->add_edge(from => 'Chadstone', to => 'Waverley');
$graph->pop_subgraph;

$graph->default_node(color => 'cyan');

$graph->add_node(name => 'Malvern');
$graph->add_node(name => 'Prahran', shape => 'trapezium');
$graph->add_edge(from => 'Malvern', to => 'Prahran');
$graph->add_edge(from => 'Malvern', to => 'Murrumbeena');

if (@ARGV) {
  my($format)      = shift || 'svg';
  my($output_file) = shift || File::Spec -> catfile('html', "sub.graph.$format");
  $graph -> run(format => $format, output_file => $output_file);
} else {
  # run as a test
  require Test::More;
  require Test::Snapshot;
  Test::Snapshot::is_deeply_snapshot($graph->dot_input, 'dot file');
  Test::More::done_testing();
}
