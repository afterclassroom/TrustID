require 'yaml'
config_path = Rails.root.join('config', 'application.yml')
if File.exist?(config_path)
  config = YAML.load_file(config_path)
  config.each do |key, value|
    ENV[key.to_s] ||= value.to_s
  end
end
