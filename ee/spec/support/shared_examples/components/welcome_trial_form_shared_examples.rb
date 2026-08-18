# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::Welcome::TrialFormComponent do
  include FormComponentHelpers

  let(:view_model_selector) { '#js-create-trial-welcome-form' }
  let(:user) { build(:user, first_name: 'John', last_name: 'Doe', company: 'Acme Corp') }
  let(:form_params) do
    {
      glm_source: 'some-source',
      glm_content: 'some-content'
    }.with_indifferent_access
  end

  let(:kwargs) do
    { user: user, params: form_params }.merge(additional_kwargs)
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
          country: '',
          state: ''
        },
        submitPath: trials_path(
          step: 'full',
          glm_source: 'some-source',
          glm_content: 'some-content'
        ),
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it { is_expected.to have_content('Welcome to GitLab') }

    it 'has body content' do
      is_expected
        .to have_content('We need a few more details from you to activate your trial.')
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'includes all user data fields' do
      view_model = parsed_component_data
      user_data = view_model['userData']

      expect(user_data['firstName']).to eq(user.first_name)
      expect(user_data['lastName']).to eq(user.last_name)
      expect(user_data['emailDomain']).to eq(user.email_domain)
      expect(user_data['companyName']).to eq(user.company)
      expect(user_data['country']).to eq('')
      expect(user_data['state']).to eq('')
    end

    it 'includes submit path with all parameters' do
      view_model = parsed_component_data
      expected_path = trials_path(
        step: 'full',
        glm_source: 'some-source',
        glm_content: 'some-content'
      )

      expect(view_model['submitPath']).to eq(expected_path)
    end

    it 'includes GTM event label' do
      view_model = parsed_component_data
      expect(view_model['gtmSubmitEventLabel']).to eq('saasTrialSubmit')
    end
  end

  context 'when glm_params are not provided' do
    let(:form_params) { {}.with_indifferent_access }
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          emailDomain: user.email_domain,
          companyName: user.company,
          country: '',
          state: ''
        },
        submitPath: trials_path(
          step: 'full'
        ),
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'excludes GLM params from submit path' do
      view_model = parsed_component_data
      submit_path = view_model['submitPath']

      expect(submit_path).not_to include('glm_source')
      expect(submit_path).not_to include('glm_content')
    end
  end

  describe 'user data variations' do
    context 'when user has blank last name' do
      let(:user) { build(:user, first_name: 'John', last_name: '', company: 'Acme Corp') }
      let(:expected_form_data_attributes) do
        {
          userData: {
            firstName: user.first_name,
            lastName: user.last_name,
            emailDomain: user.email_domain,
            companyName: user.company,
            country: '',
            state: ''
          }
        }.with_indifferent_access
      end

      it 'renders form with correct attributes' do
        expect_form_data_attribute(expected_form_data_attributes)
      end
    end

    context 'when user has present last name' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe', company: 'Acme Corp') }

      it 'includes last name in user data' do
        view_model = parsed_component_data
        user_data = view_model['userData']

        expect(user_data['lastName']).to eq('Doe')
      end
    end

    context 'when user has no organization' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe', company: nil) }

      it 'handles nil organization gracefully' do
        view_model = parsed_component_data
        expect(view_model.dig('userData', 'companyName')).to be_nil
      end
    end

    context 'when user has blank organization' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe', company: '') }

      it 'handles blank organization' do
        view_model = parsed_component_data
        expect(view_model.dig('userData', 'companyName')).to eq('')
      end
    end

    context 'when user has special characters in name' do
      let(:user) { build(:user, first_name: "John's", last_name: 'O\'Connor', company: 'Acme & Co.') }

      it 'handles special characters in user data' do
        view_model = parsed_component_data
        user_data = view_model['userData']

        expect(user_data['firstName']).to eq("John's")
        expect(user_data['lastName']).to eq('O\'Connor')
        expect(user_data['companyName']).to eq('Acme & Co.')
      end
    end
  end

  describe 'form data structure' do
    it 'generates valid JSON' do
      view_model = parsed_component_data
      expect(view_model).to be_a(Hash)
    end

    it 'includes all required top-level keys' do
      view_model = parsed_component_data

      expect(view_model).to have_key('userData')
      expect(view_model).to have_key('submitPath')
      expect(view_model).to have_key('gtmSubmitEventLabel')
    end

    it 'has userData as a hash' do
      view_model = parsed_component_data
      expect(view_model['userData']).to be_a(Hash)
    end

    it 'has submitPath as a string' do
      view_model = parsed_component_data
      expect(view_model['submitPath']).to be_a(String)
    end

    it 'has gtmSubmitEventLabel as a string' do
      view_model = parsed_component_data
      expect(view_model['gtmSubmitEventLabel']).to be_a(String)
    end

    it 'includes all required userData fields' do
      view_model = parsed_component_data
      user_data = view_model['userData']

      expected_keys = %w[firstName lastName emailDomain companyName country state]
      expect(user_data.keys).to match_array(expected_keys)
    end
  end

  describe 'parameter handling edge cases' do
    context 'with only glm_source provided' do
      let(:form_params) { { glm_source: 'partial-source' }.with_indifferent_access }

      it 'includes partial GLM params in submit path' do
        view_model = parsed_component_data
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_source=partial-source')
        expect(submit_path).not_to include('glm_content')
      end
    end

    context 'with only glm_content provided' do
      let(:form_params) { { glm_content: 'partial-content' }.with_indifferent_access }

      it 'includes partial GLM params in submit path' do
        view_model = parsed_component_data
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_content=partial-content')
        expect(submit_path).not_to include('glm_source')
      end
    end

    context 'with additional unrecognized params' do
      let(:form_params) do
        {
          glm_source: 'some-source',
          glm_content: 'some-content',
          random_param: 'should-be-ignored'
        }.with_indifferent_access
      end

      it 'only includes recognized params in submit path' do
        view_model = parsed_component_data
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_source=some-source')
        expect(submit_path).to include('glm_content=some-content')
        expect(submit_path).not_to include('random_param')
      end
    end
  end
end
