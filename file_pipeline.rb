#
# Define and execute pipelines of file transformations. Features:
#
# - runtime composition of pipeline 'steps'
#
# - verification of creation of output files for each step
#
# - opt-in deletion of intermediate files generated by steps in the pipeline
#
# - opt-in deletion of original files at start of the pipeline
#
# - parallel execution (using xargs to launch processes that serially
# execute all steps of the pipeline on a file)
#
# - pure ruby, runnable simply with 'load'; no 3rd party libraries used
#
# Sample usage:
#
# ./my_processing_script.rb -s step1,step2,step3 /input_dir

require 'optparse'
require 'pathname'

unless RUBY_VERSION.split('.').first.to_i >= 2
  puts 'WARNING: ruby >= 2.0 is required, otherwise calls to Enumerable#lazy will fail.'
end

# FilePipeline namespace
module FilePipeline

  # Members pertaining to the current working file (i.e. the result of
  # the most recent transformation in the pipeline):
  # filename = basename portion
  # complete_path = complete path
  # dir = directory portion
  #
  # Other members:
  # original = full path to the original input file at the very start
  # of the pipeline
  # input_dir = input dir
  # output_dir = output dir
  class Stage
    attr_accessor :input_dir, :output_dir, :original, :complete_path
    def filename
      File.basename(complete_path)
    end

    # directory of the working file
    def dir
      File.dirname(complete_path)
    end
  end

  class Step
    attr_accessor :name, :desc, :step_type, :chdir, :run, :skip_output_file_check
    def initialize(name)
      @name = name
      @step_type = :map
      @chdir = :working_file_dir
      @skip_output_file_check = false
    end
  end

  # DSL used to build a pipeline
  class PipelineDSL
    attr_reader :pipeline

    def initialize(pipeline)
      @pipeline = pipeline
      @step = nil
    end

    # define a step with the passed-in name, and make it the current step
    # for subsequent DSL methods
    def step(name)
      if pipeline.steps.any? { |step| step.name == name.to_s }
        puts "Error: step '#{name}' defined twice"
        exit 1
      end
      @step = Step.new(name.to_s)
      pipeline.steps << @step
    end

    # description of step
    def desc(desc)
      @step.desc = desc
    end

    # define the step type
    def step_type(step_type)
      @step.step_type = step_type
    end

    # define what directory to change into, before executing the run
    # block. this exists to accomodate inflexible programs, such as bundler, that
    # require running from a certain dir. valid values are
    # :working_file_dir (default), :script_dir, and :output_dir
    def chdir(dir_type)
      dir_type_sym = dir_type.to_sym
      if [:working_file_dir, :script_dir, :output_dir].member?(dir_type_sym)
        @step.chdir = dir_type_sym
      else
        puts "Error: invalid chdir value: #{dir_type}"
        exit 1
      end
    end

    # define the block to be run for the current step
    def run(&block)
      @step.run = block
    end

    # allows pipeline to define custom CLI options.  block should take
    # 2 arguments: the OptionParser object, and a Hash into which
    # the code should insert custom options
    def option_parser(&block)
      @pipeline.option_parser_cb = block
    end
  end

  # Execute steps in a data pipeline of file transformations.
  class Pipeline
    attr_accessor :input_file_specs, :steps, :actual_steps, :stream, :options, :option_parser, :option_parser_cb

    def initialize(&block)
      @options = {}
      @steps = []
      @input_file_specs = []
      dsl = PipelineDSL.new(self)
      dsl.instance_eval(&block)
    end

    # executes the passed-in list of steps
    def execute(*args)
      if args.empty?
        args = ARGV
      end
      parse_args(args)

      if input_file_specs.empty?
        puts "No input files specified.\n\n"
        puts @option_parser
        exit 0
      end

      if actual_steps.empty?
        puts "No steps specified.\n\n"
        puts @option_parser
        exit 0
      end

      if @options[:processes]
        paths = @input_file_specs.join(' ')
        verbose_flag = !RUBY_PLATFORM.include?('darwin') ? '--verbose' : ''
        cmd = "ls #{paths} | sort | xargs -P #{@options[:processes]} #{verbose_flag} -I FILENAME #{$PROGRAM_NAME} #{options_and_values} FILENAME"
        puts "running: #{cmd}" if @options[:verbose]
        exec cmd
        exit
      end

      stream.force
    end

    # run a shell command
    def run_command(command)
      puts "running: #{command}" if @options[:verbose]
      result = system(command)
      if !result
        puts "error occurred running this command: #{command}"
        puts 'stopping.'
        exit 1
      end
    end

    # convenience method for chdir
    def chdir(dir)
      Dir.chdir(dir)
    end

    private

    def actual_steps
      if options[:all_steps]
        @steps.map(&:name)
      else
        options[:steps]
      end
    end

    def check_file_exists(path)
      if !File.exist?(path)
        puts "Error: expected file #{path} to exist. Stopping."
        exit 1
      end
    end

    def parse_args(argv)
      @option_parser = OptionParser.new do |opts|

        opts.separator ''
        opts.separator 'NOTE: when using a shell and specifying a glob for input files,'
        opts.separator 'be sure to quote the glob to avoid expansion.'
        opts.separator ''

        # all options should define a long format whose name is
        # exactly the same as the var name in @options; this lets us
        # easily pass them along when constructing the command for xargs
        opts.on('-a', '--all-steps', 'Run all steps in the pipeline') do |v|
          @options[:all_steps] = true
        end
        opts.on('-s', '--steps STEPS', 'list of steps as comma-sep string') do |v|
          @options[:steps] = v.split(',')
        end
        opts.on('-o', '--output-dir DIR', 'Output directory') do |v|
          @options[:output_dir] = v
        end
        opts.on('-d', '--delete-original', 'Delete original file (file at start of pipeline)') do |v|
          @options[:delete_original] = true
        end
        opts.on('-i', '--delete-intermediate', 'Delete intermediate files (files generated during pipeline)') do |v|
          @options[:delete_intermediate] = true
        end
        opts.on('-p', '--processes PROCESSES', 'Number of parallel processes (defaults to 1)') do |v|
          @options[:processes] = v
        end
        opts.on('-v', '--verbose', 'Verbose mode') do |v|
          @options[:verbose] = true
        end
        opts.on_tail('-h', '--help', 'Show this help message') do
          puts opts
          puts "\nSteps defined:\n\n"
          steps.each do |step|
            puts "#{[step.name, step.desc].compact.join(' - ')}"
          end
          puts "\n"
          exit
        end
        if option_parser_cb
          option_parser_cb.call(opts, @options)
        end
      end
      @option_parser.parse!(argv)
      # what's left after parsing are the input files
      @input_file_specs = argv
    end

    # returns a string of CLI options and values that user specified
    # for current process invocation
    def options_and_values
      array = []
      @option_parser.top.each_option do |opt|
        # TODO: I'm not sure this really finds all options but it's good enough for now
        if opt.is_a?(OptionParser::Switch::RequiredArgument) || opt.is_a?(OptionParser::Switch::NoArgument)
          key = opt.long.first[2..-1].tr('-', '_').to_sym
          val = @options[key]
          if (key != :processes) && val
            array << opt.long.first
            if val.is_a?(Array)
              array << val.join(',')
            elsif !%w(true false).member?(val.to_s)
              array << val
            end
          end
        end
      end
      array.join(' ')
    end

    # Transform the input file specs to arguments appropriate for the
    # 'ls' program. Namely this means appending * to directory paths.
    def input_file_specs_for_ls
      @input_file_specs.flat_map do |spec|
        path = Pathname.new(spec)
        if path.directory?
          full_path = path.join('*').to_s
        else
          full_path = spec
        end
        # this works even when full_path is a glob
        File.expand_path(full_path)
      end
    end

    # Builds the lazy enumerable (i.e. stream) for this pipeline
    def stream
      if !@stream
        @stream = input_file_specs_for_ls.lazy.map do |file|
          expanded = File.expand_path(file)
          stage = Stage.new
          stage.output_dir = @options[:output_dir]
          stage.original = expanded
          stage.complete_path = expanded
          stage
        end
        actual_steps.each do |actual_step|
          step = @steps.find { |step_item| step_item.name == actual_step.to_s }
          if !step
            puts "Error: couldn't find a step named #{actual_step}, exiting."
            exit 1
          end
          # TODO: handle different step_types like flat_map
          @stream = @stream.map do |stage|
            case step.chdir
            when :working_file_dir
              Dir.chdir(stage.dir)
            when :script_dir
              Dir.chdir(FilePipeline.calling_script_dir)
            when :output_dir
              Dir.chdir(stage.output_dir)
            end

            result = instance_exec(stage, &step.run)

            new_stage = stage.dup

            if result.is_a?(Hash)
              output_file = result[:output_file] ? File.expand_path(result[:output_file]) : nil
              if !step.skip_output_file_check
                check_file_exists(output_file)
              end
              # only delete input file if:
              # - an output file exists
              # - it's not the same as the input file
              # - 'delete_original' is true and the file is original OR 'delete_intermediate' is true and file is intermediate
              is_intermediate = stage.complete_path != stage.original
              if output_file && output_file != stage.complete_path && (is_intermediate ? @options[:delete_intermediate] : @options[:delete_original])
                File.delete(stage.complete_path)
              end
              new_stage.complete_path = output_file
            end

            new_stage
          end
        end
      end
      @stream
    end

  end

  class << self

    # directory of main calling script (NOT the dir of THIS file,
    # although it may happen to be the same)
    attr_accessor :calling_script_dir

    def define(&block)
      Pipeline.new(&block)
    end
  end

  FilePipeline.calling_script_dir = File.dirname(File.expand_path($0))

end
