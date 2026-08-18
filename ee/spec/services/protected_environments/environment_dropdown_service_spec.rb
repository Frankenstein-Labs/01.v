# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedEnvironments::EnvironmentDropdownService, feature_category: :environment_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }

  let(:maintainer_role) { { id: 40, text: 'Maintainers', before_divider: true } }
  let(:developer_role) { { id: 30, text: 'Developers + Maintainers', before_divider: true } }

  describe '#roles_hash' do
    subject { described_class.new(container).roles_hash }

    context 'when container is a project' do
      let(:container) { project }

      it 'returns a hash with all access levels for allowed to deploy option' do
        expect(subject[:roles]).to match_array([maintainer_role, developer_role])
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      it 'returns a hash with only maintainer access level for allowed to deploy option' do
        expect(subject[:roles]).to match_array([maintainer_role])
      end

      it 'does not include the developer role' do
        expect(subject[:roles]).not_to include(developer_role)
      end
    end
  end
end
