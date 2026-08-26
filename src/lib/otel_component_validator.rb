# src/otel-collector/lib/component_validator.rb
require 'yaml'

module OtelValidator
  # Environment-aware configuration loader
  def self.load_builder_config(package_config_path, local_dev_path)
    target_path = File.exist?(package_config_path) ? package_config_path : local_dev_path
    YAML.load_file(target_path)
  rescue => e
    raise "Failed to parse builder configuration: #{e.message}"
  end

  # Dynamically extracts standard 'type' and optional 'deprecated_type' 
  def self.extract_included_components(builder_config, vendor_base_dir, component_type)
    gomods = builder_config.fetch(component_type, []).map { |entry| entry.fetch('gomod').split(" ")[0] }
    
    gomods.flat_map do |gomod|
      metadata_path = File.join(vendor_base_dir, gomod, "metadata.yaml")
      next unless File.exist?(metadata_path)
      
      metadata = YAML.load_file(metadata_path)
      types = [metadata['type']]
      types << metadata['deprecated_type'] if metadata['deprecated_type']
      types
    end.compact.uniq.sort
  end

  def self.validate_used_components!(type, used_components, included_components)
    used_components.each do |component|
      unless included_components.include?(component)
        formatted_allowed = included_components.map { |name| "\"#{name}\"" }.join(", ")
        raise "Invalid #{type}: \"#{component}\" is not supported by this collector. Available: [#{formatted_allowed}]"
      end
    end
  end
end
