# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'support/shared_examples_for_otel_collector.rb'

describe 'otel-collector' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../..')) }
  let(:job) { release.job('otel-collector') }
  let(:config_path) { '/var/vcap/jobs/otel-collector/config' }

  it_behaves_like 'common config.yml'
end
