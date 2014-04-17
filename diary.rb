#!/usr/bin/env ruby

#
# diary.rb
# ========
#
# Dependency-less clone of the awesome shell script "diary" which can be found
# here:
#
#   http://sourceforge.net/projects/diary/
#
# With attempt to be compatible, but providing more functionality.
#
# All loaded libraries should be shipped with ruby itself. So there is no need
# to install any gem to run this script.
#

require 'yaml'
require 'optparse'
require 'date'
require 'find'
require 'ostruct'
require 'fileutils'

class Date

  def diarypath
    self.strftime "%Y/%m"
  end

  def diaryfilename
    self.strftime("/%d.#{Diary::Config::FILE_EXT}")
  end

end

module Diary

  module Config

    DIARYDIR = ENV['HOME'] + "/.diary"

    PAGEDIR = DIARYDIR + "/pages"

    CONFFILE = DIARYDIR + "/diaryrc"

    FILE_EXT = "cal"

    EDITOR = ENV['EDITOR'] || "/usr/bin/vim"
    EDIT_OPTS = "-c :$ " unless ENV['EDITOR']

    ENTRY_TIMEFMT = "%A, %m.%d.%Y"
    DEFAULT_CONTENT = " " * 15 + Date.today.strftime(ENTRY_TIMEFMT)

  end

  module Commands # enumeration foo

    class Command # kindof abstract

      attr_reader :args

      def initialize(args)
        @args = args
      end

      def run
        raise "Not implemented"
      end
    end

    class EditCommand < Command

      def run
        filepath  = Diary::Config::PAGEDIR + "/" + Date.today.diarypath
        Diary::Utils.mkdir_p filepath

        file = filepath + Date.today.diaryfilename
        Diary::Utils.create(file, Diary::Config::DEFAULT_CONTENT)

        Diary::Utils.exec(Dairy::Config::EDITOR, Diary::Config::EDIT_OPTS, file)
      end

    end

    class HelpCommand < Command

      def run
        puts Diary::Options.help
        exit 1
      end

    end

    class CatCommand < Command

      def run
      end

    end

    class GrepCommand < Command

      def run
        grepargs = @args.join ' '
        files = Diary::Utils.all_diary_files
        Diary::Utils.exec "grep #{grepargs} #{files}"
      end
    end

    EDIT = Diary::Commands::EditCommand
    HELP = Diary::Commands::HelpCommand
    CAT  = 3
    VIEW = 4
    GREP = 5

  end

  module Options

    attr_reader :options

    @options = OpenStruct.new
    @options.verbose = false
    @options.command = Diary::Commands::EDIT
    @options.command_args = nil

    PARSER = OptionParser.new do |opts|

      opts.banner = "#{$0} [OPTIONS]"

      opts.on("edit ARGS", "Edit the current day") do |args|
        @options.command = Diary::Commands::EDIT
        @options.command_args = args
      end

      opts.on("help", "-h", "--help", "Show help") do
        @options.command = Diary::Commands::HELP
      end

      opts.on("cat ARGS", "Cat the current date") do |args|
        @options.command = Diary::Commands::CAT
        @options.command_args = args
      end

      opts.on("view ARGS", "View the current date") do |args|
        @options.command = Diary::Commands::VIEW
        @options.command_args = args
      end

      opts.on("grep ARGS", "Grep for something") do |args|
        @options.command = Diary::Commands::GREP
        @options.command_args = args
      end

    end

    def self.parse!(argv)
      Diary::Options::PARSER.parse! argv
      @options
    end

    def self.help
      Diary::Options::PARSER.help
    end

  end

  module Utils

    def mkdir_p p
      FileUtils.mkdir_p p
    end

    def create(f, content)
      FileUtils.touch f

      File.open(f, "w") do |file|
        c = content.is_a? File ? File.read(content) : content
        file.write c
      end

      nil
    end

    def all_diary_files
      f = []

      begin
        Find.find(Diary::Config::PAGEDIR) do |file|
          next if FileTest.directory? file
          if File.basename(file) =~ /.*\.#{Diary::Config::FILE_EXT}/
            f << file
          end
        end
      rescue Errno::ENOENT
        $stderr.puts "Cannot find #{Diary::Config::PAGEDIR}"
      end

      f
    end

    def exec(*args)
      `#{args.join ' '}`
    end

  end

end


Diary::Utils.mkdir_p Diary::Config::DIARYDIR

if __FILE__ == $0
  opts = Diary::Options.parse! ARGV

  cmd = opts.command.new opts.command_args

  cmd.run
end
