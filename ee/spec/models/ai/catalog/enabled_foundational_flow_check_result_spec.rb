# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::EnabledFoundationalFlowCheckResult, feature_category: :duo_agent_platform do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }

    it { is_expected.to belong_to(:enabled_foundational_flow).class_name('Ai::Catalog::EnabledFoundationalFlow') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization_id) }
    it { is_expected.to validate_presence_of(:enabled_foundational_flow_id) }
    it { is_expected.to validate_presence_of(:check_id) }
    it { is_expected.to validate_presence_of(:status) }

    describe 'check_id uniqueness scoped to enabled_foundational_flow_id' do
      subject { create(:ai_catalog_enabled_foundational_flow_check_result) }

      it { is_expected.to validate_uniqueness_of(:check_id).scoped_to(:enabled_foundational_flow_id) }
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(failure: 0, success: 1) }
  end
end
