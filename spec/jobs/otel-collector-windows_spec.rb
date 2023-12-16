# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'support/shared_examples_for_otel_collector.rb'

describe 'otel-collector-windows' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../..')) }
  let(:job) { release.job('otel-collector-windows') }
  let(:config_path) { '/var/vcap/jobs/otel-collector-windows/config' }

  it_behaves_like 'common config.yml'
end
