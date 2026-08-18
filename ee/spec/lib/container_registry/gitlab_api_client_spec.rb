# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::GitlabApiClient, feature_category: :container_registry do
  include_context 'container registry client'

  let(:path) { 'namespace/path/to/repository' }

  shared_examples 'returning 400 when Geo is enabled' do
    before do
      allow(::Gitlab::Geo).to receive(:enabled?).and_return(true)
    end

    it { is_expected.to eq(:bad_request) }
  end

  describe '#rename_base_repository_path' do
    subject do
      client.rename_base_repository_path(path, name: 'newname')
    end

    it_behaves_like 'returning 400 when Geo is enabled'
  end

  describe '#move_repository_to_namespace' do
    subject do
      client.move_repository_to_namespace(path, namespace: 'group/oldproject')
    end

    it_behaves_like 'returning 400 when Geo is enabled'
  end
end
