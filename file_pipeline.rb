#
# Define and execute pipelines of file transformations. Features:
#
# - runtime composition of pipeline 'steps'
#
# - verification of creation of output files for each step
#
# - deletion of intermediate files as a file moves through a pipeline
#
# - parallel execution (using xargs to launch processes that serially
# execute all steps of the pipeline on a file)
#
# - pure ruby, runnable simply with 'load'; no 3rd party libraries used
#
# Sample usage:
#
# ./my_processing_script.rb step1 step2 step3 -i /input_dir

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
    attr_accessor :name, :step_type, :run, :delete_input_file, :skip_output_file_check
    def initialize(name)
      @name = name
      @step_type = :map
      @delete_input_file = false
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

    # define the step type
    def step_type(step_type)
      @step.step_type = step_type
    end

    # define the block to be run for the current step
    def run(&block)
      @step.run = block
    end

    # @param delete_input_file [Boolean] if true, the input file will be deleted
    # after the step is executed, UNLESS it's the original file
    def delete_input_file(delete_input_file)
      @step.delete_input_file = delete_input_file
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
        cmd = "ls #{paths} | sort | xargs -P #{@options[:processes]} --verbose -I FILENAME #{$PROGRAM_NAME} #{options_and_values} FILENAME"
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
      options[:steps]
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
        opts.on('-s', '--steps STEPS', 'list of steps as comma-sep string') do |v|
          @options[:steps] = v.split(',')
        end
        opts.on('-o', '--output-dir DIR', 'Output directory') do |v|
          @options[:output_dir] = v
        end
        opts.on('-a', '--allow-original-deletion', 'Allow deleting original files') do |v|
          @options[:allow_original_deletion] = true
        end
        opts.on('-p', '--processes PROCESSES', 'Number of parallel processes (defaults to 1)') do |v|
          @options[:processes] = v
        end
        opts.on('-v', '--verbose', 'Verbose mode') do |v|
          @options[:verbose] = true
        end
        opts.on_tail('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
        option_parser_cb.call(opts, @options)
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
            Dir.chdir(stage.dir)

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
              # - it's not the original file OR we're allowed to delete original files
              if step.delete_input_file && output_file && output_file != stage.complete_path && (@options[:allow_original_deletion] || stage.complete_path != stage.original)
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
    def define(&block)
      Pipeline.new(&block)
    end
  end
end
