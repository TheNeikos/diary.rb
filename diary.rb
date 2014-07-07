if __FILE__ == $0
  config = {
    :debug => true,
    :root => "/tmp",
    :content_dir => "/tmp/content",
  }
  cp = Diary::CommandParser::Parser.new(ARGV, config)
  cp.parse!

  ex = Diary::Executer.new(cp.commands, config)
  ex.execute!
end
