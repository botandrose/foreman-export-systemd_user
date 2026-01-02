require "erb"
require "foreman/export"

class Foreman::Export::SystemdUser < Foreman::Export::Base
  TEMPLATE_DIR = File.expand_path("../../../../data/export/systemd_user", __FILE__)

  def initialize(location, engine, options = {})
    options = options.dup
    options[:template] ||= TEMPLATE_DIR
    super(location, engine, options)
  end

  def app
    options[:app] || File.basename(FileUtils.pwd)
  end

  def location
    super || "#{ENV["HOME"]}/.config/systemd/user"
  end

  def export
    super
    clean_old_units
    write_units
    install_include_dir
    configure_systemd
  end

  private

  def clean_old_units
    Dir["#{location}/#{app}*.target"]
      .concat(Dir["#{location}/#{app}*.service"])
      .concat(Dir["#{location}/#{app}*.target.wants/#{app}*.service"])
      .each do |file|
      clean file
    end

    Dir["#{location}/#{app}*.target.wants"].each do |file|
      clean_dir file
    end
  end

  def write_units
    process_master_names = []

    engine.each_process do |name, process|
      service_fn = "#{app}-#{name}@.service"
      write_template "systemd_user/process.service.erb", service_fn, binding

      create_directory("#{app}-#{name}.target.wants")
      1.upto(engine.formation[name])
        .collect { |num| engine.port_for(process, num) }
        .collect { |port| "#{app}-#{name}@#{port}.service" }
        .each do |process_name|
        create_symlink("#{app}-#{name}.target.wants/#{process_name}", "../#{service_fn}") rescue Errno::EEXIST # This is needed because rr-mocks do not call the origial cleanup
      end

      write_template "systemd_user/process_master.target.erb", "#{app}-#{name}.target", binding
      process_master_names << "#{app}-#{name}.target"
    end

    write_template "systemd_user/master.target.erb", "#{app}.target", binding
  end

  def run_command command
    puts command
    raise unless system(command)
  end

  def include_dir
    dir = options[:include_dir]
    return unless dir

    raise "include_dir '#{dir}' is not a directory" unless File.directory?(dir)
    dir
  end

  def install_include_dir
    if include_dir
      run_command "cp -r #{include_dir}/. #{location}/"
    end
  end

  def configure_systemd
    run_command "systemctl --user daemon-reload"
    run_command "test -f /var/lib/systemd/linger/$USER || loginctl enable-linger"
    run_command "systemctl --user enable #{app}.target"
    run_command "systemctl --user restart #{app}.target"
    enable_timers
  end

  def enable_timers
    if include_dir
      Dir.glob("#{include_dir}/*.timer").each do |timer|
        timer_name = File.basename(timer)
        run_command "systemctl --user enable --now #{timer_name}"
      end
    end
  end
end

