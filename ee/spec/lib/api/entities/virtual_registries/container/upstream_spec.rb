# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::VirtualRegistries::Container::Upstream, feature_category: :virtual_registry do
  let(:upstream) { build_stubbed(:virtual_registries_container_upstream) }
  let(:options) { {} }

  subject { described_class.new(upstream, options).as_json }

  it 'exposes the correct attributes' do
    is_expected.to include(
      :id, :name, :description, :group_id, :url, :username, :cache_validity_hours, :created_at, :updated_at
    ).and not_include(:registry_upstream, :registry_upstreams)
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
