# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro::TrialFormComponent, :aggregate_failures, feature_category: :acquisition do
  include FormComponentHelpers

  let(:view_model_selector) { '#js-create-trial-form' }
  let(:eligible_namespaces) { Group.none }
  let(:user) { build(:user) }
  let(:form_params) do
    {
      garbage: 'garbage',
      namespace_id: 1
    }.with_indifferent_access
  end

  let(:kwargs) do
    { user: user, params: form_params, eligible_namespaces: eligible_namespaces }
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          emailDomain: user.email_domain,
          companyName: user.company,
          showNameFields: false
        },
        submitPath: trials_duo_pro_path(step: 'full'),
        gtmSubmitEventLabel: 'saasDuoProTrialSubmit'
      }.with_indifferent_access
    end

    it { is_expected.to have_content(s_('DuoProTrial|Start your free GitLab Duo Pro trial')) }

    it 'has body content' do
      is_expected
        .to have_content(s_('DuoProTrial|We just need some additional information to activate your trial.'))
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has advantages section' do
      is_expected.to have_content(s_('DuoProTrial|GitLab Duo Pro is designed to make teams'))
    end
  end

  context 'when namespace_id is not provided' do
    let(:form_params) { super().except(:namespace_id) }
    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: false,
          initialValue: '',
          items: []
        },
        submitPath: trials_duo_pro_path(step: 'full')
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  describe 'with single eligible namespace' do
    let(:group) { build_stubbed(:group) }
    let(:form_params) { super().except(:namespace_id) }
    let(:eligible_namespaces) { [group] }
    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: true,
          initialValue: group.id.to_s,
          items: [
            {
              text: eligible_namespaces.first.name,
              value: eligible_namespaces.first.id.to_s
            }
          ]
        },
        submitPath: trials_duo_pro_path(step: 'full')
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  describe 'with multiple eligible namespaces' do
    let(:eligible_namespaces) do
      [
        build_stubbed(:group),
        build_stubbed(:group, name: 'name', path: 'path'),
        build_stubbed(:group, name: 'name', path: 'path2')
      ]
    end

    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: true,
          initialValue: '1',
          items: [
            {
              text: eligible_namespaces.first.name,
              value: eligible_namespaces.first.id.to_s
            },
            {
              text: 'name (/path)',
              value: eligible_namespaces.second.id.to_s
            },
            {
              text: 'name (/path2)',
              value: eligible_namespaces.third.id.to_s
            }
          ]
        }
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has values for the option value attribute' do
      parsed_component_data.dig('namespaceData', 'items').each do |option|
        msg = "Group selector option '#{option['text']}' has non-numeric value '#{option['value']}', " \
          'which could cause issues with form submission'

        expect(option['value']).to match(/^\d+$/), msg
      end
    end
  end
end
