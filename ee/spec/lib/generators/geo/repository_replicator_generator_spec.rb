# frozen_string_literal: true

require 'spec_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/assertions'
require 'generators/geo/repository_replicator_generator'

RSpec.describe Geo::RepositoryReplicatorGenerator, feature_category: :geo_replication do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests described_class
  destination File.expand_path('tmp', __dir__)

  before do
    prepare_destination

    run_generator %w[
      cool_widget
      --table-name=cool_widgets
      --sharding-key=project_id
      --milestone=19.1
      --model-class=CoolWidget
    ]
  end

  after do
    rm_rf(destination_root)
  end

  it 'generates a replicator using RepositoryReplicatorStrategy', :aggregate_failures do
    assert_file('ee/app/replicators/geo/cool_widget_replicator.rb') do |content|
      expect(content).to include('include ::Geo::RepositoryReplicatorStrategy')
      expect(content).to include('::CoolWidget')
      expect(content).to include('override :housekeeping_enabled?')
      expect(content).to include('def repository')
      expect(content).to include('model_record.repository')
      expect(content).not_to include('BlobReplicatorStrategy')
      expect(content).not_to include('carrierwave_uploader')
    end
  end

  it 'wires the existing model with repository-specific methods', :aggregate_failures do
    assert_file('ee/app/models/ee/cool_widget.rb') do |content|
      expect(content).to include('include ::Geo::ReplicableModel')
      expect(content).to include('include ::Geo::VerifiableModel')
      expect(content).to include('with_replicator ::Geo::CoolWidgetReplicator')
      expect(content).to include('def pool_repository')
      expect(content).to match(/def cool_widget_state\n\s*super \|\| build_cool_widget_state/)
      expect(content).to include('override :selective_sync_scope')
    end
  end

  it 'generates the registry and state models and their migrations', :aggregate_failures do
    assert_file('ee/app/models/geo/cool_widget_registry.rb') do |content|
      expect(content).to include('include ::Geo::ReplicableRegistry')
      expect(content).to include('include ::Geo::VerifiableRegistry')
    end
    assert_file('ee/app/models/geo/cool_widget_state.rb') do |content|
      expect(content).to include('include ::Geo::VerificationStateDefinition')
    end

    expect(Dir.glob(File.join(destination_root, 'ee/db/geo/migrate/*_create_cool_widget_registry.rb'))).not_to be_empty
    expect(Dir.glob(File.join(destination_root, 'db/migrate/*_create_cool_widget_states.rb'))).not_to be_empty
  end

  it 'generates the finder, resolver and GraphQL type', :aggregate_failures do
    assert_file('ee/app/finders/geo/cool_widget_registry_finder.rb')
    assert_file('ee/app/graphql/resolvers/geo/cool_widget_registries_resolver.rb')
    assert_file('ee/app/graphql/types/geo/cool_widget_registry_type.rb')
  end

  it 'uses the repository replicator spec shared example', :aggregate_failures do
    assert_file('ee/spec/replicators/geo/cool_widget_replicator_spec.rb') do |content|
      expect(content).to include("include_examples 'a repository replicator'")
      expect(content).to include('build(:cool_widget)')
    end
  end

  it 'does not generate any upload-partition artifacts', :aggregate_failures do
    assert_no_file('ee/app/models/geo/cool_widget.rb')
    assert_no_file('ee/spec/models/geo/cool_widget_spec.rb')

    expect(Dir.glob(File.join(destination_root, 'db/migrate/*_add_unique_index_on_*'))).to be_empty
  end
end
