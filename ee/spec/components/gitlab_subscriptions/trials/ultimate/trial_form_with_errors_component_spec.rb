# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Ultimate::TrialFormWithErrorsComponent, :aggregate_failures, feature_category: :acquisition do
  it_behaves_like GitlabSubscriptions::Trials::Ultimate::TrialFormComponent do
    let(:additional_kwargs) { { namespace_create_errors: 'some error' } }
    let(:extra_namespace_data) { { createErrors: 'some error' } }

    context 'with default content for error condition' do
      let(:form_params) do
        {
          first_name: '_first_name_',
          last_name: '_last_name_',
          company_name: '_company_name_',
          phone_number: '123456',
          country: '_country_',
          state: '_state_',
          new_group_name: '_new_group_name_'
        }.with_indifferent_access
      end

      let(:expected_form_data_attributes) do
        {
          userData: {
            firstName: '_first_name_',
            lastName: '_last_name_',
            emailDomain: user.email_domain,
            companyName: '_company_name_',
            showNameFields: false,
            phoneNumber: '123456',
            country: '_country_',
            state: '_state_'
          },
          namespaceData: {
            anyTrialEligibleNamespaces: false,
            initialValue: '',
            items: [],
            newGroupName: '_new_group_name_',
            createErrors: 'some error'
          }
        }.with_indifferent_access
      end

      it 'renders form with correct attributes' do
        expect_form_data_attribute(expected_form_data_attributes)
      end
    end

    context 'without a few params present' do
      let(:form_params) do
        {
          first_name: '_first_name_',
          last_name: '_last_name_',
          company_name: '_company_name_'
        }.with_indifferent_access
      end

      let(:expected_form_data_attributes) do
        {
          userData: {
            firstName: '_first_name_',
            lastName: '_last_name_',
            companyName: '_company_name_',
            emailDomain: user.email_domain,
            showNameFields: false
          },
          namespaceData: {
            anyTrialEligibleNamespaces: false,
            initialValue: '',
            items: [],
            createErrors: 'some error'
          }
        }.with_indifferent_access
      end

      it 'falls back to the defaults' do
        expect_form_data_attribute(expected_form_data_attributes)
      end
    end
  end
end
