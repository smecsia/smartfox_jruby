require File.expand_path(File.dirname(__FILE__) + '/common')

java_import java.lang.Runtime
java_import java.lang.System

module SmartfoxJruby
  class SfsRunner

    def initialize(home_dir, opts = {})
      @home_dir = home_dir
      @opts = opts
      @launched = false
      @fault = false
      @pid = nil
    end

    def run!
      Thread.new do
        begin
          info "Changing dir to #{work_dir}"
          Dir.chdir(work_dir) do
            info "Running cmd #{cmd}"
            IO.popen(cmd) do |output|
              @pid = output.pid
              info "Running child with pid=#{output.pid}..."
              output.each do |line|
                debug(line.gsub(/\n/, ""))
                @launched = true if line =~ /SmartFoxServer 2X \(.+\) READY!/
              end
            end
            @fault = true
          end
        rescue Exception => e
          error "#{e}"
        end
      end
    end

    def kill!
      info "Checking running processes: #{pids.join(",")}"
      pids.each { |pid|
        pid = pid.try(:strip).try(:to_i)
        info "Killing the process with pid=#{pid}..."
        Process.kill("KILL", pid) if Process.alive?(pid)
        wait_with_timeout(5) { !Process.alive?(pid) } rescue ""
      }
    end

    def run_and_wait!(opts = {})
      run!
      wait_until_launched_or_fault(opts[:timeout])
    end


    def kill_and_wait!(opts = {})
      kill!
      wait_until_terminated(opts[:timeout])
    end

    def running?
      !pids.blank? && pids.map { |pid| Process.alive?(pid.to_i) }.include?(true)
    end

    def launched?
      @launched
    end

    def fault?
      @fault
    end

    def wait_until_terminated(timeout = nil)
      wait_with_timeout(timeout) { !running? }
    end

    def wait_until_launched_or_fault(timeout = nil)
      wait_with_timeout(timeout) { launched? or fault? }
    end

    private

    def pids
      pids_out = `pgrep -f "#{work_dir}"`
      (pids_out.try(:split, "\n")) || []
    end

    def error(msg)
      @opts[:logger].error(msg) unless @opts[:logger].blank?
    end

    def debug(msg)
      @opts[:logger].debug(msg) unless @opts[:logger].blank?
    end

    def info(msg)
      @opts[:logger].info(msg) unless @opts[:logger].blank?
    end

    def work_dir
      Pathname.new(@home_dir).join("SFS2X").to_s
    end

    def env
      %W[].to_java :string
    end

    def cmd
      %Q[#{java_bin} -cp #{classpath} #{java_opts} -Dsmartfox.work_dir="#{work_dir}" com.smartfoxserver.v2.Main]
    end

    def java_bin
      Pathname.new(System.getProperty("java.home")).join("bin").join("java")
    end

    def java_opts
      %Q[-XX:MaxPermSize=512m -Xms128m -Xms1024m]
    end

    def classpath
      %Q[aimy:./:lib/*:lib/Jetty/*:extensions/__lib__/*]
    end

  end

end

