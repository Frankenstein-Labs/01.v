# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretRotationInfo, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_parent) { create(:group) }

  let(:rotation_info_factory) { :group_secret_rotation_info }
  let(:parent) { group }
  let(:parent_association) { :group }

  it_behaves_like 'a secret rotation info'

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end
end
