# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterprise::CreationFailureComponent, :aggregate_failures, feature_category: :acquisition do
  let(:namespace_id) { non_existing_record_id }
  let(:params) do
    ActionController::Parameters.new(
      glm_source: 'about.gitlab.com',
      glm_content: 'trial',
      first_name: 'John',
      last_name: 'Doe',
      company_name: 'Test Company',
      phone_number: '123-456-7890',
      country: 'US',
      state: 'CA',
      namespace_id: namespace_id
    ).permit!
  end

  let(:kwargs) do
    {
      result: result,
      params: params
    }
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'when lead creation failed' do
    let(:result) do
      ServiceResponse.error(
        message: 'Lead creation failed',
        reason: GitlabSubscriptions::Trials::UltimateCreateService::LEAD_FAILED,
        payload: { namespace_id: namespace_id }
      )
    end

    it 'displays the error title' do
      is_expected.to have_content(_('Trial registration unsuccessful'))
    end

    it 'displays the lead error content' do
      is_expected.to have_content('Lead creation failed')
    end

    it 'has the correct form action attribute' do
      form = find_by_testid('trial-form', context: component)
      expected_path = trials_duo_enterprise_path(
        step: GitlabSubscriptions::Trials::DuoEnterpriseCreateService::RESUBMIT_LEAD,
        glm_source: 'about.gitlab.com',
        glm_content: 'trial'
      )

      expect(form['action']).to eq(expected_path)
    end

    it 'renders all lead failed hidden fields' do
      is_expected.to have_selector("input[name='namespace_id'][value='#{namespace_id}']", visible: :hidden)
      is_expected.to have_selector("input[name='first_name'][value='John']", visible: :hidden)
      is_expected.to have_selector("input[name='last_name'][value='Doe']", visible: :hidden)
      is_expected.to have_selector("input[name='company_name'][value='Test Company']", visible: :hidden)
      is_expected.to have_selector("input[name='phone_number'][value='123-456-7890']", visible: :hidden)
      is_expected.to have_selector("input[name='country'][value='US']", visible: :hidden)
      is_expected.to have_selector("input[name='state'][value='CA']", visible: :hidden)
      is_expected.to have_selector("input[name='namespace_id'][value='#{namespace_id}']", visible: :hidden)
    end
  end

  context 'when trial creation failed' do
    let(:result) do
      ServiceResponse.error(
        message: 'Trial creation failed',
        reason: 'some_other_reason',
        payload: { namespace_id: namespace_id }
      )
    end

    it 'displays the error title' do
      is_expected.to have_content(_('Trial registration unsuccessful'))
    end

    it 'displays the trial error content' do
      is_expected.to have_content('Trial creation failed')
    end

    it 'has the correct form action attribute' do
      form = find_by_testid('trial-form', context: component)
      expected_path = trials_duo_enterprise_path(
        step: GitlabSubscriptions::Trials::DuoEnterpriseCreateService::RESUBMIT_TRIAL,
        glm_source: 'about.gitlab.com',
        glm_content: 'trial'
      )

      expect(form['action']).to eq(expected_path)
    end

    it 'renders only namespace_id hidden field' do
      is_expected.to have_selector("input[name='namespace_id'][value='#{namespace_id}']", visible: :hidden)
      is_expected.not_to have_selector("input[name='first_name']", visible: :hidden)
      is_expected.not_to have_selector("input[name='last_name']", visible: :hidden)
    end
  end

  context 'when trial creation failed with generic error' do
    let(:result) do
      ServiceResponse.error(
        message: 'Generic trial error',
        reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR,
        payload: { namespace_id: namespace_id }
      )
    end

    it 'displays support link in error content' do
      is_expected.to have_content(_('Please reach out to'))
      is_expected.to have_link(_('GitLab Support'), href: Gitlab::Saas.customer_support_url)
      is_expected.to have_content('Generic trial error')
    end
  end

  context 'without GLM parameters' do
    let(:params) do
      ActionController::Parameters.new(
        first_name: 'Jane',
        namespace_id: namespace_id
      ).permit!
    end

    let(:result) do
      ServiceResponse.error(
        message: 'Lead creation failed',
        reason: GitlabSubscriptions::Trials::DuoEnterpriseCreateService::LEAD_FAILED,
        payload: { namespace_id: namespace_id }
      )
    end

    it 'has form action without GLM parameters' do
      form = find_by_testid('trial-form', context: component)
      expected_path = trials_duo_enterprise_path(
        step: GitlabSubscriptions::Trials::DuoEnterpriseCreateService::RESUBMIT_LEAD
      )

      expect(form['action']).to eq(expected_path)
    end
  end
end
