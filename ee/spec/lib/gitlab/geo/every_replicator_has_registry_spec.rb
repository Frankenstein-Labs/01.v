# frozen_string_literal: true

require 'spec_helper'

# The consistency worker's REGISTRY_CLASSES is derived from Gitlab::Geo::REPLICATOR_CLASSES
# (see Gitlab::Geo.registry_classes), which makes REPLICATOR_CLASSES the single source of truth.
# This spec guards that derivation: every replicator must resolve a real registry and have a
# registry factory, so a mis-wired or half-added replicator fails loudly here instead of
# silently dropping out of the consistency worker, GraphQL registry enum, or RegistrableType union.
RSpec.describe 'Every Geo replicator', feature_category: :geo_replication do
  let(:replicator_classes) { Gitlab::Geo::REPLICATOR_CLASSES }

  it 'derives the registry consistency worker list from every replicator' do
    expect(::Geo::Secondary::RegistryConsistencyWorker::REGISTRY_CLASSES)
      .to match_array(replicator_classes.map(&:registry_class))
  end

  it 'maps exactly the graphql-registerable replicators into the RegistrableType union' do
    registerable = replicator_classes.select(&:graphql_registerable?)

    expect(::Types::Geo::RegistrableType::GEO_REGISTRY_TYPES.keys)
      .to match_array(registerable.map(&:registry_class))
  end

  it 'resolves a registry class that inherits from Geo::BaseRegistry', :aggregate_failures do
    replicator_classes.each do |replicator_class|
      expect(replicator_class.registry_class).to be < ::Geo::BaseRegistry
    end
  end

  it 'has a registered registry factory', :aggregate_failures do
    replicator_classes.each do |replicator_class|
      factory_name = :"geo_#{replicator_class.replicable_name}_registry"

      expect(FactoryBot.factories.registered?(factory_name))
        .to be(true), "Missing factory :#{factory_name} for #{replicator_class}"
    end
  end
end
