# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::CreateUpstreamService, feature_category: :virtual_registry do
  shared_examples 'creating an upstream entry successfully' do
    it 'creates an upstream entry when provided params are valid' do
      payload = execute.payload

      expect(execute).to be_success
      expect(payload).to have_attributes(expected_attributes)
    end
  end

  shared_examples 'handling invalid parameters' do
    context 'with invalid params' do
      let(:params) { { name: '',  url: 'http://invalid.url', cache_validity_hours: 'a' } }

      it 'fails to create an upstream entry' do
        expect(execute).to be_error && have_attributes(
          reason: :invalid,
          message: contain_exactly("Cache validity hours is not a number", "Name can't be blank")
        )
      end
    end
  end

  shared_examples 'handling unauthorized users' do
    context 'with no user' do
      let(:user) { nil }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end
  end

  let(:service) { described_class.new(registry: registry, current_user: user, params: params) }

  context 'for Maven virtual registry upstreams' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:user) { create(:user, owner_of: registry.group) }
    let_it_be(:params) { { name: 'Maven Central', url: 'https://repo.maven.apache.org/maven2', cache_validity_hours: 24 } }

    let(:expected_attributes) do
      {
        group_id: registry.group.id,
        name: "Maven Central",
        cache_validity_hours: 24,
        url: "https://repo.maven.apache.org/maven2"
      }
    end

    describe '#execute' do
      subject(:execute) { service.execute }

      it_behaves_like 'creating an upstream entry successfully'
      it_behaves_like 'handling invalid parameters'
      it_behaves_like 'handling unauthorized users'
    end
  end

  context 'for Container virtual registry upstreams' do
    let_it_be(:registry) { create(:virtual_registries_container_registry) }
    let_it_be(:user) { create(:user, owner_of: registry.group) }
    let_it_be(:params) { { name: 'Docker Central', url: 'https://docker.io', cache_validity_hours: 24 } }

    let(:expected_attributes) do
      {
        group_id: registry.group.id,
        name: "Docker Central",
        cache_validity_hours: 24,
        url: "https://docker.io"
      }
    end

    describe '#execute' do
      subject(:execute) { service.execute }

      it_behaves_like 'creating an upstream entry successfully'
      it_behaves_like 'handling invalid parameters'
      it_behaves_like 'handling unauthorized users'
    end
  end
end
