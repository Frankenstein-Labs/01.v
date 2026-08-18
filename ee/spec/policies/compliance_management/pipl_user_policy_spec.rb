# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::PiplUserPolicy, feature_category: :compliance_management do
  let_it_be(:pipl_user) { create(:pipl_user) }

  let_it_be(:simple_user) { create(:user) }
  let_it_be(:admin_user) { create(:user, :admin_bot) }
  let(:current_user) { admin_user }

  subject { described_class.new(current_user, pipl_user) }

  shared_examples 'rules work as expected' do
    context 'when the user is an admin' do
      it { is_expected.to be_allowed(:block_pipl_user) }
      it { is_expected.to be_allowed(:delete_pipl_user) }

      context 'when the enforce_pipl_compliance setting is disabled' do
        before do
          stub_ee_application_setting(enforce_pipl_compliance: false)
        end

        it { is_expected.to be_disallowed(:block_pipl_user) }
        it { is_expected.to be_disallowed(:delete_pipl_user) }
      end
    end

    context 'when the user is not an admin' do
      let(:current_user) { simple_user }

      it { is_expected.to be_disallowed(:block_pipl_user) }
      it { is_expected.to be_disallowed(:delete_pipl_user) }
    end
  end

  context 'when system admin_mode is enabled', :enable_admin_mode do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it_behaves_like 'rules work as expected'
  end

  context 'when system admin_mode is enabled', :do_not_mock_admin_mode_setting do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it_behaves_like 'rules work as expected'
  end
end
