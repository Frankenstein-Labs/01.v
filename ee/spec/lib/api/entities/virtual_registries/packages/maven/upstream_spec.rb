# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::VirtualRegistries::Packages::Maven::Upstream, feature_category: :virtual_registry do
  let(:options) { {} }

  subject(:upstream_data) { described_class.new(upstream, options).as_json }

  context 'for a remote upstream' do
    let(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }

    it 'exposes the correct attributes' do
      is_expected.to include(
        :id, :name, :description, :group_id, :upstream_type,
        :url, :username,
        :cache_validity_hours, :metadata_cache_validity_hours, :created_at, :updated_at
      ).and not_include(:registry_upstream, :registry_upstreams, :local_group_id, :local_project_id)
    end

    it 'sets upstream_type to "remote"' do
      expect(upstream_data[:upstream_type]).to eq('remote')
    end

    context 'for with_registry_upstream option' do
      let(:options) { { with_registry_upstream: true } }

      it { is_expected.to include(:registry_upstream) }
    end

    context 'for with_registry_upstreams option' do
      let(:options) { { with_registry_upstreams: true } }

      it { is_expected.to include(:registry_upstreams) }
    end
  end

  context 'for a local upstream' do
    let(:upstream) { build_stubbed(:virtual_registries_packages_maven_local_upstream) }

    it 'exposes the correct attributes' do
      is_expected.to include(
        :id, :name, :description, :group_id, :upstream_type,
        :local_project_id, :local_group_id,
        :cache_validity_hours, :metadata_cache_validity_hours, :created_at, :updated_at
      ).and not_include(:url, :username, :registry_upstream, :registry_upstreams)
    end

    it 'sets upstream_type to "local"' do
      expect(upstream_data[:upstream_type]).to eq('local')
    end
  end
end
