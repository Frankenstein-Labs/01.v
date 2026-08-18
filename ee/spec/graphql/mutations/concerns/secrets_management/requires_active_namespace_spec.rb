# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::RequiresActiveNamespace, feature_category: :secrets_management do
  let(:host_class) do
    Class.new do
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include SecretsManagement::RequiresActiveNamespace
    end
  end

  let(:instance) { host_class.new }

  subject(:guard) { instance.send(:raise_if_namespace_inactive!, namespace) }

  shared_examples 'allows the operation' do
    it 'does not raise' do
      expect { guard }.not_to raise_error
    end
  end

  shared_examples 'blocks the operation' do |message|
    it 'raises a resource-not-available error with the inactive-namespace message' do
      expect { guard }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, message)
    end
  end

  context 'with a group' do
    context 'when active' do
      let_it_be(:namespace) { create(:group) }

      it_behaves_like 'allows the operation'
    end

    context 'when inactive' do
      let_it_be(:namespace) { create(:group_with_deletion_schedule) }

      it_behaves_like 'blocks the operation', described_class::GROUP_INACTIVE_ERROR
    end
  end

  context 'with a project' do
    context 'when active' do
      let_it_be(:namespace) { create(:project) }

      it_behaves_like 'allows the operation'
    end

    context 'when inactive' do
      let_it_be(:namespace) { create(:project, :archived) }

      it_behaves_like 'blocks the operation', described_class::PROJECT_INACTIVE_ERROR
    end
  end
end
