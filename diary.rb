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

        Diary::Utils.exec(Diary::Config::EDITOR, Diary::Config::EDIT_OPTS, file)
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

    class ViewCommand < Command

      def run
      end

    end

    class GrepCommand < Command

      def run
        grepargs = (@args || []).join ' '
        files = Diary::Utils.all_diary_files
        Diary::Utils.exec "grep #{grepargs} #{files}"
      end

    end

    EDIT = EditCommand
    HELP = HelpCommand
    CAT  = CatCommand
    VIEW = ViewCommand
    GREP = GrepCommand

  end

  module Config

    DIARYDIR = ENV['HOME'] + "/.diary"

    PAGEDIR = DIARYDIR + "/pages"

    CONFFILE = DIARYDIR + "/diaryrc"

    FILE_EXT = "cal"

    EDITOR = ENV['EDITOR'] || "/usr/bin/vim"
    EDIT_OPTS = "-c :$ " unless ENV['EDITOR']

    ENTRY_TIMEFMT = "%A, %m.%d.%Y"
    DEFAULT_CONTENT = " " * 15 + Date.today.strftime(ENTRY_TIMEFMT) + "\n"

    DEFAULT_CMD = Diary::Commands::EDIT

  end

  module Options

    def self.parse!(argv)
      options = OpenStruct.new
      options.verbose = false
      options.command = Diary::Config::DEFAULT_CMD
      options.command_args = nil

      options.command = decide_command ARGV.shift
      options.command_args = ARGV.clone

      options
    end

    def self.decide_command c
      case c
      when "edit" then Diary::Commands::EDIT
      when "cat"  then Diary::Commands::CAT
      when "view" then Diary::Commands::VIEW
      when "grep" then Diary::Commands::GREP
      else
        Diary::Commands::EDIT
      end
    end

  end

  module Utils
    extend self

    def mkdir_p p
      FileUtils.mkdir_p p
    end

    def create(f, content)
      FileUtils.touch f

      File.open(f, "w") do |file|
        c = if content.is_a? File
          File.read content
        else
          content
        end

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
      system args.join(' ')
    end

  end

end


Diary::Utils.mkdir_p Diary::Config::DIARYDIR

if __FILE__ == $0
  opts = Diary::Options.parse! ARGV

  cmd = opts.command.new opts.command_args

  cmd.run
end
