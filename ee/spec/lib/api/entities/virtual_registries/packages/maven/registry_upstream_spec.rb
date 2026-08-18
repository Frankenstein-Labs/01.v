# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::VirtualRegistries::Packages::Maven::RegistryUpstream, feature_category: :virtual_registry do
  let(:registry_upstream) { build_stubbed(:virtual_registries_packages_maven_registry_upstream) }
  let(:options) { {} }

  subject { described_class.new(registry_upstream, options).as_json }

  it { is_expected.to include(:id, :registry_id, :upstream_id, :position, :local_upstream_id) }

  context 'for exclude_registry_id option' do
    let(:options) { { exclude_registry_id: true } }

    it { is_expected.to not_include(:registry_id) }
  end

  context 'for exclude_upstream_id option' do
    let(:options) { { exclude_upstream_id: true } }

    it { is_expected.to not_include(:upstream_id) }
  end
end
