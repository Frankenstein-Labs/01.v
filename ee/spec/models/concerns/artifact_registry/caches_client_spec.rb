# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArtifactRegistry::CachesClient, feature_category: :artifact_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  let(:resource_class) do
    Class.new do
      include ArtifactRegistry::CachesClient
    end
  end

  let(:resource) { resource_class.new }

  describe '#artifact_registry_client' do
    it 'builds the client bound to the current user' do
      expect(ArtifactRegistry::Client).to receive(:new).with(current_user: user).and_call_original

      expect(resource.artifact_registry_client(current_user: user)).to be_a(ArtifactRegistry::Client)
    end

    it 'memoizes one client per user across calls (one client per request)' do
      first = resource.artifact_registry_client(current_user: user)
      second = resource.artifact_registry_client(current_user: user)

      expect(first).to be(second)
    end

    it 'builds a distinct client for a different principal' do
      first = resource.artifact_registry_client(current_user: user)
      second = resource.artifact_registry_client(current_user: other_user)

      expect(first).not_to be(second)
    end
  end
end
