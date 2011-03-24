module RhcpShell #:nodoc:

  class Version
    include Singleton

    MAJOR = 0
    MINOR = 2
    TINY  = 11

    def Version.to_s
      [ MAJOR, MINOR, TINY ].join(".")
    end
  end
  
end
