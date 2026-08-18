# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::HandRaiseLeadsHelper, feature_category: :acquisition do
  describe '#hand_raise_modal_dataset' do
    it 'provides the expected dataset' do
      user = build_stubbed(:user)
      root_namespace = build_stubbed(:namespace)
      allow(helper).to receive(:current_user).and_return(user)
      result = {
        user: {
          namespace_id: root_namespace.id,
          user_name: user.username,
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.company
        }.to_json,
        submit_path: gitlab_subscriptions_hand_raise_leads_path
      }

      expect(helper.hand_raise_modal_dataset(root_namespace)).to eq(result)
    end
  end

  describe '#code_suggestions_usage_app_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json,
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'secondary',
          variant: 'confirm',
          class: '@sm/panel:gl-w-auto gl-w-full @sm/panel:gl-ml-3 @sm/panel:gl-mt-0 gl-mt-3'
        }.to_json
      }

      expect(helper.code_suggestions_usage_app_hand_raise_lead_data).to eq(result)
    end
  end

  describe '#billing_action_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'billing-group',
        cta_tracking: { action: 'click_link', property: 'code' }.to_json,
        button_attributes: {}.to_json
      }

      expect(helper.billing_action_hand_raise_lead_data('code')).to eq(result)
    end
  end

  describe '#group_trial_status' do
    let_it_be(:group) { build_stubbed(:group) }

    context 'when trial is active' do
      before do
        allow(group).to receive(:trial_active?).and_return(true)
      end

      it 'returns correct status' do
        expect(helper.group_trial_status(group)).to eq 'trial_active'
      end
    end

    context 'when trial is expired' do
      before do
        allow(group).to receive(:trial_active?).and_return(false)
      end

      it 'returns correct status' do
        expect(helper.group_trial_status(group)).to eq 'trial_expired'
      end
    end
  end
end
