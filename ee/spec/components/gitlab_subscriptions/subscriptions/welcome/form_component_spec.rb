# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Subscriptions::Welcome::FormComponent, :aggregate_failures, feature_category: :acquisition do
  include FormComponentHelpers

  let(:view_model_selector) { '#js-subscription-welcome-form' }
  let(:user) { build(:user) }
  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      company_name: 'test',
      group_name: 'test-group',
      project_name: 'test-project',
      namespace_id: 123,
      errors: {}
    }.with_indifferent_access
  end

  let(:expected_form_data) do
    {
      userData: {
        firstName: 'John',
        lastName: 'Doe',
        showNameFields: false,
        companyName: 'test',
        groupName: 'test-group',
        projectName: 'test-project'
      },
      submitPath: users_sign_up_welcome_path,
      namespaceId: 123,
      serverValidations: {}
    }.with_indifferent_access
  end

  before do
    render_inline(described_class.new(user, params))
  end

  subject(:component) { page }

  it 'renders the welcome heading' do
    is_expected.to have_content(s_('InProductMarketing|Welcome to GitLab'))
  end

  it 'renders the setup description' do
    is_expected.to have_content(s_('InProductMarketing|Set up your GitLab environment.'))
  end

  it 'renders the form container' do
    expect(component.find('#js-subscription-welcome-form')).to be_present
  end

  it 'passes correct form data to component' do
    expect_form_data_attribute(expected_form_data)
  end

  context 'with missing optional params' do
    let(:params) do
      {
        namespace_id: nil,
        errors: {}
      }.with_indifferent_access
    end

    let(:expected_form_data) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          showNameFields: false,
          companyName: '',
          groupName: '',
          projectName: ''
        },
        submitPath: users_sign_up_welcome_path,
        namespaceId: nil,
        serverValidations: {}
      }.with_indifferent_access
    end

    it 'provides default values for missing params' do
      expect_form_data_attribute(expected_form_data)
    end
  end

  context 'with server validations' do
    let(:params) do
      {
        company_name: 'test',
        group_name: 'test-group',
        project_name: 'test-project',
        namespace_id: 123,
        errors: {
          group_name: ['Group name is invalid'],
          project_name: ['Project name already exists']
        }
      }.with_indifferent_access
    end

    let(:expected_form_data) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          showNameFields: false,
          companyName: 'test',
          groupName: 'test-group',
          projectName: 'test-project'
        },
        submitPath: users_sign_up_welcome_path,
        namespaceId: 123,
        serverValidations: {
          group_name: ['Group name is invalid'],
          project_name: ['Project name already exists']
        }
      }.with_indifferent_access
    end

    it 'passes server validation errors to form' do
      expect_form_data_attribute(expected_form_data)
    end
  end
end
