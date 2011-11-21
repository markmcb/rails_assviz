#checks for graphviz
begin
  require 'rubygems'
rescue LoadError
  raise "You must have rubygems installed."
  return false
end

#checks for graphviz
begin
  require 'graphviz'
rescue LoadError
  raise "Install the GraphViz gem: gem install ruby-graphviz"
  return false
end

#Checks for active_support
begin
  require 'active_support'
rescue LoadError
  raise "Install the Ruby on Rails gem: gem install rails"
  return false
end

def list_for_help(list_type)
  list = (list_type == :formats ? GraphViz::FORMATS : GraphViz::PROGRAMS)
  f_count=0
  output=""
  spacer="                                "
  tmp_line = []
  list.each do |f| 
    if f_count > 6
      output+= spacer+tmp_line.to_sentence(:last_word_connector => ", ", :two_words_connector => ", ")+"\n"
      tmp_line=[]
      f_count=0
    end
    tmp_line<<f
    f_count+=1
  end
  output+= spacer+tmp_line.to_sentence(:last_word_connector => ", ", :two_words_connector => ", ")
end

Help = \
"USAGE: ruby /path/to/#{File.basename(__FILE__)} [options]

OPTIONS:
  --in=/rails/project/path    specify Rails project; default is current dir
  --out=/path/to/save/output  specify where to save output files
  --format=list,of,formats    specify output types, comma separated:
#{list_for_help(:formats)}
  --program=list,of,algs      specify graphviz algorithms, comma separated:
#{list_for_help(:programs)}

"

def stop_executing(options={})
  puts Help unless options[:no_help]
  exit
end

@options = {}

# Handle command line arguments
ARGV.each do |arg|
  stop_executing unless arg =~ /--[a-zA-Z]+ *= *[a-zA-Z\/~.]/
  split_arg = arg.split("=")
  case split_arg[0]
  when "--in"
    if FileTest.readable?(File.expand_path(File.join(split_arg[1],"app","models"))) 
      @options[:in]=File.expand_path(File.join(split_arg[1],"app","models"))
    else
      puts "ERROR: --in must point to a Rails application's root directory\n\n"
      stop_executing(:no_help=>true)
    end
  when "--out"
    if FileTest.writable?(File.expand_path(split_arg[1]))
      @options[:out]=File.expand_path(split_arg[1])
    else
      puts "ERROR: --out must be a writable directory\n\n"
      stop_executing(:no_help=>true)
    end
  when "--format"
    @options[:format] = []
    split_arg[1].split(",").each do |f|
      if GraphViz::FORMATS.index(f)
        @options[:format]<<f
      else
        puts "ERROR: --format must be a list of allowable GraphViz formats\n\n"
        stop_executing(:no_help=>true)
      end
    end
  when "--program"
    @options[:program] = []
    split_arg[1].split(",").each do |p|
      if GraphViz::PROGRAMS.index(p)
        @options[:program]<<p
      else
        puts "ERROR: --program must be a list of allowable GraphViz programs\n\n"
        stop_executing(:no_help=>true)
      end
    end
  else
    stop_executing
  end
end

#set defaults if not assigned from ARGV
@options[:in] = (FileTest.readable?(File.expand_path(File.join(Dir.getwd,"app","models"))) ? File.expand_path(File.join(Dir.getwd,"app","models")) : stop_executing) if @options[:in].nil?
@options[:out] = (FileTest.writable?(File.expand_path(File.join(Dir.getwd))) ? File.expand_path(File.join(Dir.getwd)) : stop_executing)  if @options[:out].nil?
@options[:format] = ['png'] if @options[:format].nil?
@options[:program] = ["dot"] if @options[:program].nil?

# dig through the model files and look for relations to other models
model_data = []
nodes = []
edges = []
Dir.foreach(@options[:in]) do |file| 
  nodes << file.gsub(".rb","").singularize unless file =~ /\A\.+/
  unless file =~ /\A\.\.?\Z/
    IO.readlines(File.join(@options[:in],file)).each do |line|
      if (line =~ /\A *?((has_many)|(has_and_belongs_to_many)|(has_one)|(embeds_one)|(embeds_many)|(belongs_to)|(embedded_in)|(referenced_in))/).is_a?(Integer)
        edges << [file.gsub(".rb",""), line]
      end
    end
  end
end
nodes.uniq!

# build the edge relationships
edges.each do |e|
  e[1].gsub!( /\A *?((has_many)|(has_and_belongs_to_many)|(has_one)|(embeds_one)|(embeds_many)|(belongs_to)|(embedded_in)) +:(\w+).*/m, '\9%\1')
  e[1].gsub!( /\A *?((referenced_in)) +:(\w+).*/m, '\3%\1') #gsub doesn't like replacement patterns that reference the 10th matched set
  f = e[1].split("%")
  e[2] = f[0].gsub(".rb","").singularize
  e[1] = f[1]
end
edges.delete_if{|e|e[1]=="belongs_to" || e[1]=="embedded_in"}

# put everything together with graphviz
g = GraphViz::new( "structs", "type" => "graph", :use => "dot" )
g[:rankdir] = "LR"
g[:sep] = "+8"
g[:overlap] = "false"
g.edge[:color] = "#999999"
g.edge[:fontname] = g.node[:fontname] = "Verdana"
g.edge[:fontsize] = g.node[:fontsize] = "8"
g.node[:style] = "filled"
g.node[:color] = "#336699"
g.node[:fontcolor] = "#ddeeff"

font_colors = {
  "has_many" => "#AB0000",
  "has_one" => "#FF0000",
  "embeds_many" => "#0600FF",
  "embeds_one" => "#00CCFF",
  "has_and_belongs_to_many" => "#880770",
  "default"  => "0D800D"
}

nodes.each{|node| g.add_node(node)}
edges.each do |edge| 
  e=g.add_edge(edge[0],edge[2])
  e.fontcolor = font_colors[edge[1]].nil? ? font_colors["default"] : font_colors[edge[1]]
  e.label=edge[1]
  (edge[1] == "has_one" || edge[1] == "embeds_one") ? e.arrowhead="none" : e.arrowhead="crow"
end

@options[:program].each do |program|
  @options[:format].each do |format|
    g.output(:png => File.join(@options[:out],"#{program}_erd."+format), :use => program )
  end
end