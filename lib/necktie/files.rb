require "tempfile"

module Necktie
  module Files
    # Return the contents of the file (same as File.read).
    def read(name)
      File.read(name)
    end

    # Writes contents to a new file, or overwrites existing file.  Takes string
    # as second argument, or yields to block. For example:
    #
    #   write "/etc/mailname", "example.com"
    #   write("/var/run/bowtie.pid") { Process.pid }
    # 
    # This method performs an atomic write using TMPDIR or (/tmp) as the
    # temporary directory and renaming the file over to the new location.
    # Ownership and premission are retained if replacing existing file.
    def write(name, contents = nil)
      contents ||= yield
      temp = Tempfile.new(File.basename(name))
      temp.write contents
      temp.close

      begin
        # Get original file permissions
        stat = File.stat(name)
      rescue Errno::ENOENT
        # No old permissions, write a temp file to determine the defaults
        stat_check = File.join(File.dirname(name), ".permissions_check.#{Thread.current.object_id}.#{Process.pid}.#{rand(1000000)}")
        File.open(stat_check, "w") { }
        stat = File.stat(stat_check)
        File.unlink stat_check
      end
      
      # Overwrite original file with temp file
      File.rename(temp.path, name)

      # Set correct permissions on new file
      File.chown stat.uid, stat.gid, name
      File.chmod stat.mode, name
    end

    # Append contents to a file, creating it if necessary.  Takes string as
    # second argument, or yields to block. For example:
    #   append "/etc/fstab", "/dev/sdh /vol xfs\n" unless read("/etc/fstab")["/dev/sdh "]
    def append(name, contents = nil)
      contents ||= yield
      File.open name, "a" do |f|
        f.write contents
      end
    end

    # Updates a file: read contents, substitue and write it back.  Takes two
    # arguments for substitution, or yields to block.  These two are equivalent:
    #   update "/etc/memcached.conf", /^-l 127.0.0.1/, "-l 0.0.0.0"
    #   update("/etc/memcached.conf") { |s| s.sub(/^-l 127.0.0.1/, "-l 0.0.0.0") }
    def update(name, from = nil, to = nil)
      contents = File.read(name)
      if from && to
        contents = contents.sub(from, to)
      else
        contents = yield(contents)
      end
      write name, contents
    end
  end
end

include Necktie::Files
