require 'tmpdir'
require 'yaml'
require 'fileutils'

require_relative '../lib/generate_available_components'

RSpec.describe '#generate_component_map' do
  # Builds a fake release_dir with a builder config and matching vendored
  # metadata.yaml files, then returns the release_dir path.
  #
  #   components: { <type> => [ { gomod:, metadata: } | { gomod: } ] }
  # A component with no :metadata key has its gomod listed in the builder
  # config but no metadata.yaml written on disk (simulates a missing vendor dir).
  def build_release_dir(dir, components)
    builder_config = {}
    components.each do |type, entries|
      builder_config[type] = entries.map { |e| { 'gomod' => "#{e[:gomod]} v0.1.0" } }
    end

    config_path = File.join(dir, 'src/otel-collector-builder/config.yaml')
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, YAML.dump(builder_config))

    components.each_value do |entries|
      entries.each do |e|
        next unless e.key?(:metadata)
        metadata_path = File.join(dir, 'src/otel-collector/vendor', e[:gomod], 'metadata.yaml')
        FileUtils.mkdir_p(File.dirname(metadata_path))
        File.write(metadata_path, YAML.dump(e[:metadata]))
      end
    end

    dir
  end

  around(:each) do |example|
    Dir.mktmpdir do |tmp|
      @release_dir = tmp
      @output_path = File.join(tmp, 'out', 'available_components.yml')
      example.run
    end
  end

  def run(components)
    build_release_dir(@release_dir, components)
    generate_component_map(@release_dir, @output_path)
    YAML.load_file(@output_path)
  end

  it 'writes a manifest keyed under available_components with all five component types' do
    manifest = run({})

    expect(manifest.keys).to eq(['available_components'])
    expect(manifest['available_components'].keys).to contain_exactly(
      'processors', 'exporters', 'receivers', 'providers', 'extensions'
    )
  end

  it 'lists each vendored component with its display_name and type' do
    manifest = run(
      'exporters' => [
        { gomod: 'example.com/exporter/otlp',
          metadata: { 'type' => 'otlp', 'display_name' => 'OTLP' } },
      ]
    )

    expect(manifest['available_components']['exporters']).to eq(
      [{ 'display_name' => 'OTLP', 'type' => 'otlp' }]
    )
  end

  it 'includes deprecated_type only when present in metadata' do
    manifest = run(
      'receivers' => [
        { gomod: 'example.com/receiver/withdep',
          metadata: { 'type' => 'new', 'display_name' => 'New',
                      'deprecated_type' => 'old' } },
        { gomod: 'example.com/receiver/nodep',
          metadata: { 'type' => 'plain', 'display_name' => 'Plain' } },
      ]
    )

    receivers = manifest['available_components']['receivers']
    withdep = receivers.find { |c| c['type'] == 'new' }
    nodep = receivers.find { |c| c['type'] == 'plain' }

    expect(withdep).to eq(
      'display_name' => 'New', 'type' => 'new', 'deprecated_type' => 'old'
    )
    expect(nodep).to eq('display_name' => 'Plain', 'type' => 'plain')
    expect(nodep).not_to have_key('deprecated_type')
  end

  it 'omits deprecated_type when it is present but falsy' do
    # The guard is truthiness-based (`if metadata['deprecated_type']`), not
    # key presence — a `deprecated_type: false` must be dropped, not coerced
    # to the string "false".
    manifest = run(
      'receivers' => [
        { gomod: 'example.com/receiver/falsy',
          metadata: { 'type' => 'falsy', 'display_name' => 'Falsy',
                      'deprecated_type' => false } },
      ]
    )

    component = manifest['available_components']['receivers'].first
    expect(component).to eq('display_name' => 'Falsy', 'type' => 'falsy')
    expect(component).not_to have_key('deprecated_type')
  end

  it 'sorts components within each type by type name (not display_name)' do
    # display_name order is deliberately the REVERSE of type order, so a sort
    # keyed on the wrong field would produce a different result and fail.
    manifest = run(
      'processors' => [
        { gomod: 'example.com/processor/alpha',
          metadata: { 'type' => 'alpha', 'display_name' => 'Zzz' } },
        { gomod: 'example.com/processor/mid',
          metadata: { 'type' => 'mid', 'display_name' => 'Mmm' } },
        { gomod: 'example.com/processor/zeta',
          metadata: { 'type' => 'zeta', 'display_name' => 'Aaa' } },
      ]
    )

    components = manifest['available_components']['processors']
    expect(components.map { |c| c['type'] }).to eq(%w[alpha mid zeta])
    # Guard against a regression that sorts by display_name instead.
    expect(components.map { |c| c['display_name'] }).to eq(%w[Zzz Mmm Aaa])
  end

  it 'skips gomods whose metadata.yaml does not exist in vendor' do
    manifest = run(
      'extensions' => [
        { gomod: 'example.com/extension/present',
          metadata: { 'type' => 'present', 'display_name' => 'Present' } },
        { gomod: 'example.com/extension/missing' }, # no metadata written
      ]
    )

    types = manifest['available_components']['extensions'].map { |c| c['type'] }
    expect(types).to eq(['present'])
  end

  it 'takes only the first whitespace-delimited token of a gomod as the vendor path' do
    # Builder config stores "<module> <version>"; the vendor path is just the module.
    manifest = run(
      'providers' => [
        { gomod: 'example.com/provider/env',
          metadata: { 'type' => 'env', 'display_name' => 'Env' } },
      ]
    )

    expect(manifest['available_components']['providers'])
      .to eq([{ 'display_name' => 'Env', 'type' => 'env' }])
  end

  it 'coerces missing display_name and type to empty strings' do
    manifest = run(
      'exporters' => [
        { gomod: 'example.com/exporter/bare', metadata: { 'other' => 'x' } },
      ]
    )

    expect(manifest['available_components']['exporters'])
      .to eq([{ 'display_name' => '', 'type' => '' }])
  end

  it 'creates the output directory if it does not already exist' do
    expect(File).not_to exist(File.dirname(@output_path))
    run({})
    expect(File).to exist(@output_path)
  end

  it 'leaves a type empty when the builder config omits it' do
    manifest = run(
      'exporters' => [
        { gomod: 'example.com/exporter/otlp',
          metadata: { 'type' => 'otlp', 'display_name' => 'OTLP' } },
      ]
    )

    expect(manifest['available_components']['processors']).to eq([])
    expect(manifest['available_components']['receivers']).to eq([])
  end
end
