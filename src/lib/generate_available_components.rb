# src/otel-collector/lib/generate_available_components.rb
require 'yaml'
require 'fileutils'

def generate_component_map(release_dir, output_path)
  builder_config = YAML.load_file(File.join(release_dir, "src/otel-collector-builder/config.yaml"))
  component_types = ['processors', 'exporters', 'receivers', 'providers', 'extensions']
  
  manifest = { 'available_components' => {} }

  component_types.each do |type|
    manifest['available_components'][type] = []
    gomods = builder_config.fetch(type, []).map { |entry| entry.fetch('gomod').split(" ").first }

    gomods.each do |gomod|
      metadata_path = File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml")
      next unless File.exist?(metadata_path)

      metadata = YAML.load_file(metadata_path)
      
      component_entry = {
        'display_name' => metadata['display_name'].to_s,
        'type' => metadata['type'].to_s
      }
      component_entry['deprecated_type'] = metadata['deprecated_type'].to_s if metadata['deprecated_type']

      manifest['available_components'][type] << component_entry
    end
    
    manifest['available_components'][type].sort_by! { |c| c['type'] }
  end

  FileUtils.mkdir_p(File.dirname(output_path))
  File.write(output_path, YAML.dump(manifest))
end

if __FILE__ == $0
  release_dir, out_file = ARGV
  generate_component_map(release_dir, out_file)
end
