# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretRotationInfo, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:other_parent) { create(:project) }

  let(:rotation_info_factory) { :project_secret_rotation_info }
  let(:parent) { project }
  let(:parent_association) { :project }

  it_behaves_like 'a secret rotation info'

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end
end
