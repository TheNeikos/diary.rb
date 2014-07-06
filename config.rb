module Diary
  class Config < Hash

    # defaults
    def initialize(other_config_path = false)
      self[:root]         = Dir.home + "/.diary"
      self[:content_dir]  = self[:root] + "/content"
      self[:configfile]   = other_config_path || self[:root] + "/diary.conf"
      self[:editor]       = "/usr/bin/vi"
      self[:ext]          = "txt"

      self.merge non_default_config
    end

    def []=(k, v)
      super[k.to_sym] = v
    end

    def [](k)
      super[k.to_sym]
    end

    protected

    def non_default_config
      # TODO: read self[:configfile] file to hash and return
    end

  end
end

