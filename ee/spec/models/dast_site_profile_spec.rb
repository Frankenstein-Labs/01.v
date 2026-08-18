# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DastSiteProfile, :dynamic_analysis,
  feature_category: :dynamic_application_security_testing do
  let_it_be(:project) { create(:project) }

  subject(:dast_site_profile) { create(:dast_site_profile, :with_dast_site_validation, project: project, id: 'site-profile-id') }

  it_behaves_like 'sanitizable', :dast_site_profile, %i[name scan_file_path]

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:dast_site) }
    it { is_expected.to have_many(:secret_variables).class_name('Dast::SiteProfileSecretVariable') }
  end

  describe 'validations' do
    let_it_be(:dast_site) { create(:dast_site, project: project) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_length_of(:auth_password_field).is_at_most(255) }
    it { is_expected.to validate_length_of(:auth_url).is_at_most(1024).allow_nil }
    it { is_expected.to validate_length_of(:auth_username).is_at_most(255) }
    it { is_expected.to validate_length_of(:auth_username_field).is_at_most(255) }
    it { is_expected.to validate_length_of(:auth_submit_field).is_at_most(255) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:dast_site_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
    it { is_expected.to validate_length_of(:scan_file_path).is_at_most(1024) }

    describe '#auth_url' do
      context 'when the auth_uri is nil' do
        it 'is valid' do
          expect(dast_site_profile).to be_valid
        end
      end

      context 'when the auth_url is not a valid uri' do
        subject(:dast_site_profile) { build(:dast_site_profile, project: project, dast_site: dast_site, auth_url: 'hello-world') }

        it 'is not valid' do
          expect(dast_site_profile).not_to be_valid
        end
      end

      context 'when the auth_url is not public' do
        subject(:dast_site_profile) { build(:dast_site_profile, project: project, dast_site: dast_site) }

        it 'is valid' do
          expect(dast_site_profile).to be_valid
        end
      end
    end

    describe '#excluded_urls' do
      let(:excluded_urls) { [] }

      subject(:dast_site_profile) { build(:dast_site_profile, project: project, dast_site: dast_site, excluded_urls: excluded_urls) }

      it { is_expected.to allow_value(Array.new(25, generate(:url))).for(:excluded_urls) }
      it { is_expected.not_to allow_value(Array.new(26, generate(:url))).for(:excluded_urls) }

      context 'when there are some urls that are invalid' do
        let(:excluded_urls) do
          [
            generate(:url),
            generate(:url) + '/' + SecureRandom.alphanumeric(1024),
            'hello-world',
            'hello-world' + '/' + SecureRandom.alphanumeric(1024)
          ]
        end

        it 'is not valid', :aggregate_failures do
          expected_full_messages = [
            "Excluded urls contains invalid URLs (#{excluded_urls[2]}, #{excluded_urls[3]})",
            "Excluded urls contains URLs that exceed the 1024 character limit (#{excluded_urls[1]}, #{excluded_urls[3]})"
          ]

          expect(dast_site_profile).not_to be_valid
          expect(dast_site_profile.errors.full_messages).to eq(expected_full_messages)
        end
      end
    end

    describe '#project' do
      context 'when the project_id and dast_site.project_id do not match' do
        let_it_be(:dast_site) { create(:dast_site) }

        subject(:dast_site_profile) { build(:dast_site_profile, dast_site: dast_site, project: project) }

        it 'is not valid', :aggregate_failures do
          expect(dast_site_profile).not_to be_valid
          expect(dast_site_profile.errors.full_messages).to include('Project does not match dast_site.project')
        end
      end
    end

    describe '#scan_file_path' do
      context 'when the scan_file_path is nil' do
        subject(:dast_site_profile) do
          build(
            :dast_site_profile, dast_site: dast_site, project: project,
            target_type: target_type,
            scan_file_path: nil
          )
        end

        context 'when the target_type is website' do
          let_it_be(:target_type) { 'website' }

          it 'is valid' do
            expect(dast_site_profile).to be_valid
          end
        end
      end

      context 'when the scan_file_path is not nil' do
        let_it_be(:scan_file_path) { 'https://www.domain.com/test-api-specification.json' }

        subject(:dast_site_profile) do
          build(
            :dast_site_profile, dast_site: dast_site, project: project,
            target_type: target_type,
            scan_method: scan_method,
            scan_file_path: scan_file_path
          )
        end

        context 'when the target_type is api' do
          let_it_be(:target_type) { 'api' }

          shared_examples 'invalid url' do
            let_it_be(:scan_file_path) { 'invalid_url' }

            it 'is not valid', :aggregate_failures do
              expect(dast_site_profile).not_to be_valid
              expect(dast_site_profile.errors.full_messages).to include(error_message)
            end
          end

          context 'when the scan_method is openapi' do
            let_it_be(:scan_method) { 'openapi' }

            let_it_be(:error_message) { 'OpenAPI Specification file URL is not a valid URL.' }

            it_behaves_like 'invalid url'
          end

          context 'when the scan_method is har' do
            let_it_be(:scan_method) { 'har' }

            let_it_be(:error_message) { 'HAR file URL is not a valid URL.' }

            it_behaves_like 'invalid url'
          end

          context 'when the scan_method is postman' do
            let_it_be(:scan_method) { 'postman' }

            let_it_be(:error_message) { 'Postman collection file URL is not a valid URL.' }

            it_behaves_like 'invalid url'
          end

          context 'when the scan_method is graphql' do
            let_it_be(:scan_method) { 'graphql' }

            context 'when the scan_file_path is an file_path' do
              let_it_be(:scan_file_path) { '/graphql' }

              it 'is valid' do
                expect(dast_site_profile).to be_valid
              end
            end
          end
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :ensure_scan_file_path' do
      let_it_be(:dast_site) { create(:dast_site, project: project) }

      context 'when target_type is api and scan_file_path is blank' do
        it 'sets scan_file_path to dast_site.url' do
          profile = create(:dast_site_profile, project: project, dast_site: dast_site, target_type: :api, scan_file_path: nil)

          expect(profile.scan_file_path).to eq(dast_site.url)
        end
      end

      context 'when target_type is website and scan_file_path is present' do
        it 'sets scan_file_path to nil' do
          profile = create(:dast_site_profile, project: project, dast_site: dast_site, target_type: :website, scan_file_path: 'https://example.com/api.json')

          expect(profile.scan_file_path).to be_nil
        end
      end

      context 'when target_type is api and scan_file_path is present' do
        it 'does not change scan_file_path' do
          scan_file_path = 'https://example.com/openapi.json'
          profile = create(:dast_site_profile, project: project, dast_site: dast_site, target_type: :api, scan_file_path: scan_file_path)

          expect(profile.scan_file_path).to eq(scan_file_path)
        end
      end

      context 'when target_type is website and scan_file_path is blank' do
        it 'does not change scan_file_path' do
          profile = create(:dast_site_profile, project: project, dast_site: dast_site, target_type: :website, scan_file_path: nil)

          expect(profile.scan_file_path).to be_nil
        end
      end
    end
  end

  describe 'scopes' do
    describe '.with_dast_site_and_validation' do
      before do
        dast_site_profile.dast_site_validation.update!(state: :failed)
      end

      it 'eager loads the association', :aggregate_failures do
        dast_site_profile

        recorder = ActiveRecord::QueryRecorder.new do
          dast_site_profile.dast_site
          dast_site_profile.dast_site_validation
        end

        expect(dast_site_profile.status).to eq('failed') # ensures guard passed
        expect(recorder.count).to be_zero
      end
    end

    describe '.with_name' do
      it 'returns the dast_site_profiles with given name' do
        result = described_class.with_name(dast_site_profile.name)
        expect(result).to eq([dast_site_profile])
      end
    end
  end

  describe 'enums' do
    let(:target_types) do
      { website: 0, api: 1 }
    end

    let(:scan_methods) do
      { site: 0, openapi: 1, har: 2, postman: 3, graphql: 4 }
    end

    it { is_expected.to define_enum_for(:target_type).with_values(**target_types) }

    it { is_expected.to define_enum_for(:scan_method).with_values(**scan_methods).with_prefix }
  end

  describe '.names' do
    it 'returns the names for the DAST site profiles with the given IDs' do
      first_profile = create(:dast_site_profile, name: 'First profile')
      second_profile = create(:dast_site_profile, name: 'Second profile')

      names = described_class.names([first_profile.id, second_profile.id])

      expect(names).to contain_exactly('First profile', 'Second profile')
    end

    context 'when a profile is not found' do
      it 'rescues the error and returns an empty array' do
        names = described_class.names([0])

        expect(names).to be_empty
      end
    end
  end

  describe 'instance methods' do
    describe '#destroy!' do
      context 'when the associated dast_site has no dast_site_profiles' do
        it 'is also destroyed' do
          dast_site_profile.destroy!

          expect { dast_site_profile.dast_site.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when the associated dast_site has dast_site_profiles' do
        it 'is not destroyed' do
          create(:dast_site_profile, dast_site: dast_site_profile.dast_site, project: dast_site_profile.project)

          dast_site_profile.destroy!

          expect { dast_site_profile.dast_site.reload }.not_to raise_error
        end
      end
    end

    describe '#status' do
      context 'when dast_site_validation association does not exist' do
        it 'is none', :aggregate_failures do
          dast_site_profile.dast_site.update!(dast_site_validation_id: nil)

          expect(dast_site_profile.dast_site_validation).to be_nil
          expect(dast_site_profile.status).to eq('none')
        end
      end

      context 'when dast_site_validation association does exist' do
        it 'is dast_site_validation#state' do
          expect(dast_site_profile.status).to eq(dast_site_profile.dast_site_validation.state)
        end
      end
    end

    describe '#validation_started_at' do
      context 'when dast_site_validation association does not exist' do
        it 'is none', :aggregate_failures do
          dast_site_profile.dast_site.update!(dast_site_validation_id: nil)

          expect(dast_site_profile.dast_site_validation).to be_nil
          expect(dast_site_profile.validation_started_at).to be_nil
        end
      end

      context 'when dast_site_validation association does exist' do
        it 'is dast_site_validation#validation_started_at' do
          expect(dast_site_profile.validation_started_at).to eq(dast_site_profile.dast_site_validation.validation_started_at)
        end
      end
    end

    describe '#referenced_in_security_policies' do
      context 'there is no security_orchestration_policy_configuration assigned to project' do
        it 'returns empty array' do
          expect(dast_site_profile.referenced_in_security_policies).to eq([])
        end
      end

      context 'there is security_orchestration_policy_configuration assigned to project' do
        let(:group_security_policy_configuration) { instance_double(Security::OrchestrationPolicyConfiguration, present?: true, active_policy_names_with_dast_site_profile: Set.new) }
        let(:security_orchestration_policy_configuration) { instance_double(Security::OrchestrationPolicyConfiguration, present?: true, active_policy_names_with_dast_site_profile: ['Policy Name'].to_set) }

        before do
          allow(dast_site_profile.project).to receive(:security_orchestration_policy_configuration).and_return(security_orchestration_policy_configuration)
          allow(dast_site_profile.project).to receive(:all_security_orchestration_policy_configurations).and_return([group_security_policy_configuration, security_orchestration_policy_configuration])
        end

        it 'calls security_orchestration_policy_configuration.active_policy_names_with_dast_site_profile with profile name' do
          expect(group_security_policy_configuration).to receive(:active_policy_names_with_dast_site_profile).with(dast_site_profile.name)
          expect(security_orchestration_policy_configuration).to receive(:active_policy_names_with_dast_site_profile).with(dast_site_profile.name)

          dast_site_profile.referenced_in_security_policies
        end

        it 'returns the referenced policy name' do
          expect(dast_site_profile.referenced_in_security_policies).to eq(['Policy Name'])
        end
      end
    end

    describe '#ci_variables' do
      let(:collection) { dast_site_profile.ci_variables }
      let(:keys) { dast_site_profile.ci_variables.map { |variable| variable[:key] } }
      let(:excluded_urls) { dast_site_profile.excluded_urls.join(',') }

      context 'without_dast_submit_field' do
        it 'returns a collection of variables' do
          expected_variables = [
            { key: 'DAST_WEBSITE', value: dast_site_profile.dast_site.url, public: true, masked: false },
            { key: 'DAST_EXCLUDE_URLS', value: excluded_urls, public: true, masked: false },
            { key: 'DAST_AUTH_URL', value: dast_site_profile.auth_url, public: true, masked: false },
            { key: 'DAST_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
            { key: 'DAST_USERNAME_FIELD', value: dast_site_profile.auth_username_field, public: true, masked: false },
            { key: 'DAST_PASSWORD_FIELD', value: dast_site_profile.auth_password_field, public: true, masked: false },
            { key: 'DAST_API_HTTP_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false }
          ]

          expect(collection.to_runner_variables).to eq(expected_variables)
        end
      end

      context 'with_dast_submit_field' do
        subject(:dast_site_profile) { create(:dast_site_profile, :with_dast_site_validation, :with_dast_submit_field, project: project) }

        it 'returns a collection of variables' do
          expected_variables = [
            { key: 'DAST_WEBSITE', value: dast_site_profile.dast_site.url, public: true, masked: false },
            { key: 'DAST_EXCLUDE_URLS', value: excluded_urls, public: true, masked: false },
            { key: 'DAST_AUTH_URL', value: dast_site_profile.auth_url, public: true, masked: false },
            { key: 'DAST_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
            { key: 'DAST_USERNAME_FIELD', value: dast_site_profile.auth_username_field, public: true, masked: false },
            { key: 'DAST_PASSWORD_FIELD', value: dast_site_profile.auth_password_field, public: true, masked: false },
            { key: 'DAST_SUBMIT_FIELD', value: dast_site_profile.auth_submit_field, public: true, masked: false },
            { key: 'DAST_API_HTTP_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false }
          ]

          expect(collection.to_runner_variables).to eq(expected_variables)
        end
      end

      context 'with optional_variables' do
        subject(:dast_site_profile) { create(:dast_site_profile, :with_dast_site_validation, project: project, optional_variables: [{ "value" => "true", "variable" => "DAST_AUTH_CLEAR_INPUT_FIELDS" }, { "value" => "2", "variable" => "DAST_ACTIVE_SCAN_WORKER_COUNT" }]) }

        it 'appends the optional variables' do
          expected_variables = [
            { key: 'DAST_WEBSITE', value: dast_site_profile.dast_site.url, public: true, masked: false },
            { key: 'DAST_EXCLUDE_URLS', value: excluded_urls, public: true, masked: false },
            { key: 'DAST_AUTH_URL', value: dast_site_profile.auth_url, public: true, masked: false },
            { key: 'DAST_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
            { key: 'DAST_USERNAME_FIELD', value: dast_site_profile.auth_username_field, public: true, masked: false },
            { key: 'DAST_PASSWORD_FIELD', value: dast_site_profile.auth_password_field, public: true, masked: false },
            { key: 'DAST_API_HTTP_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
            { key: 'DAST_AUTH_CLEAR_INPUT_FIELDS', value: "true", public: true, masked: false },
            { key: 'DAST_ACTIVE_SCAN_WORKER_COUNT', value: "2", public: true, masked: false }
          ]

          expect(collection.to_runner_variables).to eq(expected_variables)
        end

        context 'with optional_variables that are duplicates of other variables' do
          subject(:dast_site_profile) { create(:dast_site_profile, :with_dast_site_validation, project: project, optional_variables: [{ "value" => "https://gitlab.com", "variable" => "DAST_WEBSITE" }, { "value" => "2", "variable" => "DAST_ACTIVE_SCAN_WORKER_COUNT" }]) }

          it 'ignores the duplicate optional variables' do
            expected_variables = [
              { key: 'DAST_WEBSITE', value: dast_site_profile.dast_site.url, public: true, masked: false },
              { key: 'DAST_EXCLUDE_URLS', value: excluded_urls, public: true, masked: false },
              { key: 'DAST_AUTH_URL', value: dast_site_profile.auth_url, public: true, masked: false },
              { key: 'DAST_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
              { key: 'DAST_USERNAME_FIELD', value: dast_site_profile.auth_username_field, public: true, masked: false },
              { key: 'DAST_PASSWORD_FIELD', value: dast_site_profile.auth_password_field, public: true, masked: false },
              { key: 'DAST_API_HTTP_USERNAME', value: dast_site_profile.auth_username, public: true, masked: false },
              { key: 'DAST_ACTIVE_SCAN_WORKER_COUNT', value: "2", public: true, masked: false }
            ]

            expect(collection.to_runner_variables).to eq(expected_variables)
          end
        end
      end

      context 'when target_type=api' do
        let_it_be(:dast_site) { create(:dast_site, project: project) }

        shared_examples 'an api target' do
          subject(:dast_site_profile) do
            build(
              :dast_site_profile, target_type: :api, scan_method: scan_method,
              scan_file_path: scan_file_path,
              dast_site: dast_site
            )
          end

          it 'has the correct collection of variables', :aggregate_failures do
            expect(keys).not_to include(*excluded)
            expect(collection).to include(*included)
          end
        end

        context 'when scan_method is openapi' do
          let(:targeting_api) { 'test-api-specification.json' }
          let(:scan_file_path) { "http://test-deployment/#{targeting_api}" }
          let(:scan_method) { :openapi }

          let(:excluded) { %w[DAST_WEBSITE DAST_EXCLUDE_URLS DAST_API_HAR DAST_API_POSTMAN_COLLECTION DAST_API_GRAPHQL] }

          let(:included) do
            [
              { key: 'DAST_API_OPENAPI', value: scan_file_path, public: true },
              { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
              { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
            ]
          end

          it_behaves_like 'an api target'

          context 'when scan_file_path is blank' do
            let(:scan_file_path) { nil }

            let(:included) do
              [
                { key: 'DAST_API_OPENAPI', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
              ]
            end

            it_behaves_like 'an api target'
          end
        end

        context 'when scan_method is har' do
          let(:targeting_api) { 'test-api-recording.har' }
          let(:scan_file_path) { "http://test-deployment/#{targeting_api}" }
          let(:scan_method) { :har }

          let(:excluded) { %w[DAST_WEBSITE DAST_EXCLUDE_URLS DAST_API_OPENAPI DAST_API_POSTMAN_COLLECTION DAST_API_GRAPHQL] }

          let(:included) do
            [
              { key: 'DAST_API_HAR', value: scan_file_path, public: true },
              { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
              { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
            ]
          end

          it_behaves_like 'an api target'

          context 'when scan_file_path is blank' do
            let(:scan_file_path) { nil }

            let(:included) do
              [
                { key: 'DAST_API_HAR', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
              ]
            end

            it_behaves_like 'an api target'
          end
        end

        context 'when scan_method is postman' do
          let(:targeting_api) { 'postman-collection_serviceA.json' }
          let(:scan_file_path) { "http://test-deployment/#{targeting_api}" }
          let(:scan_method) { :postman }

          let(:excluded) { %w[DAST_WEBSITE DAST_EXCLUDE_URLS DAST_API_OPENAPI DAST_API_HAR DAST_API_GRAPHQL] }

          let(:included) do
            [
              { key: 'DAST_API_POSTMAN_COLLECTION', value: scan_file_path, public: true },
              { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
              { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
            ]
          end

          it_behaves_like 'an api target'

          context 'when scan_file_path is blank' do
            let(:scan_file_path) { nil }

            let(:included) do
              [
                { key: 'DAST_API_POSTMAN_COLLECTION', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
              ]
            end

            it_behaves_like 'an api target'
          end
        end

        context 'when scan_method is graphql' do
          let(:scan_file_path) { '/graphql' }
          let(:scan_method) { :graphql }

          let(:excluded) { %w[DAST_WEBSITE DAST_EXCLUDE_URLS DAST_API_OPENAPI DAST_API_HAR DAST_API_POSTMAN_COLLECTION] }

          let(:included) do
            [
              { key: 'DAST_API_GRAPHQL', value: scan_file_path, public: true },
              { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
              { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
            ]
          end

          it_behaves_like 'an api target'

          context 'when scan_file_path is blank' do
            let(:scan_file_path) { nil }

            let(:included) do
              [
                { key: 'DAST_API_GRAPHQL', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_TARGET_URL', value: dast_site_profile.dast_site.url, public: true },
                { key: 'DAST_API_EXCLUDE_URLS', value: excluded_urls, public: true }
              ]
            end

            it_behaves_like 'an api target'
          end
        end
      end

      context 'when auth is disabled' do
        subject(:dast_site_profile) { build(:dast_site_profile, auth_enabled: false) }

        it 'returns a collection of variables excluding any auth variables', :aggregate_failures do
          expect(keys).not_to include('DAST_AUTH_URL', 'DAST_USERNAME', 'DAST_USERNAME_FIELD', 'DAST_PASSWORD_FIELD', 'DAST_SUBMIT_FIELD')
        end
      end

      context 'when excluded_urls is empty' do
        subject(:dast_site_profile) { build(:dast_site_profile, excluded_urls: []) }

        it 'is removed from the collection' do
          expect(keys).not_to include('DAST_EXCLUDE_URLS')
          expect(keys).not_to include('DAST_API_EXCLUDE_URLS')
        end
      end

      context 'when a variable is set to nil' do
        subject(:dast_site_profile) { build(:dast_site_profile, auth_enabled: true, auth_username_field: nil) }

        it 'is removed from the collection' do
          expect(keys).not_to include('DAST_USERNAME_FIELD')
        end
      end
    end

    describe '#secret_ci_variables' do
      let_it_be(:user) { create(:user, developer_of: project) }

      context 'when user can read secrets' do
        before do
          stub_licensed_features(security_on_demand_scans: true)
          allow(Ability).to receive(:allowed?).and_call_original
        end

        it 'works with policy' do
          expect(Ability.allowed?(user, :create_on_demand_dast_scan, dast_site_profile)).to be_truthy
        end

        it 'checks the policy' do
          expect(Ability).to receive(:allowed?).with(user, :create_on_demand_dast_scan, dast_site_profile).and_call_original

          dast_site_profile.secret_ci_variables(user)
        end

        context 'when there are no secret_variables' do
          it 'returns an empty collection' do
            expect(dast_site_profile.secret_ci_variables(user).size).to be_zero
          end
        end

        context 'when there are secret_variables' do
          let_it_be(:maintainer_user) { create(:user, maintainer_of: project) }

          it 'returns a collection containing that variable' do
            variable = create(:dast_site_profile_secret_variable, dast_site_profile: dast_site_profile)

            expect(dast_site_profile.secret_ci_variables(maintainer_user).to_runner_variables).to include(key: variable.key, value: variable.value, public: false, masked: true)
          end

          context 'when password is configured' do
            let(:api_password) { Dast::SiteProfileSecretVariable::API_PASSWORD }
            let(:password) { Dast::SiteProfileSecretVariable::PASSWORD }

            it 'returns a collection containing the password and api password' do
              variable = create(:dast_site_profile_secret_variable, :password, dast_site_profile: dast_site_profile)

              secret_ci_variables = dast_site_profile.secret_ci_variables(maintainer_user).to_runner_variables

              expect(secret_ci_variables).to include(key: api_password, value: variable.value, public: false, masked: true)
              expect(secret_ci_variables).to include(key: password, value: variable.value, public: false, masked: true)
            end
          end

          context 'when request headers are configured' do
            let(:api_request_header) { Dast::SiteProfileSecretVariable::API_REQUEST_HEADERS }
            let(:request_header) { Dast::SiteProfileSecretVariable::REQUEST_HEADERS }

            it 'returns a collection containing the api request headers' do
              variable = create(:dast_site_profile_secret_variable, :request_headers, dast_site_profile: dast_site_profile)

              secret_ci_variables = dast_site_profile.secret_ci_variables(maintainer_user).to_runner_variables

              expect(secret_ci_variables).to include(key: api_request_header, value: variable.value, public: false, masked: true)
              expect(secret_ci_variables).to include(key: request_header, value: variable.value, public: false, masked: true)
            end
          end
        end
      end

      context 'when user cannot read secrets' do
        before do
          stub_licensed_features(security_on_demand_scans: false)
        end

        it 'returns an empty collection' do
          create(:dast_site_profile_secret_variable, dast_site_profile: dast_site_profile)

          expect(dast_site_profile.secret_ci_variables(user).size).to be_zero
        end
      end

      context 'when user is a developer and the profile has secret variables' do
        before do
          stub_licensed_features(security_on_demand_scans: true)
          create(:dast_site_profile_secret_variable, :password, dast_site_profile: dast_site_profile)
        end

        it 'returns an empty collection' do
          expect(dast_site_profile.secret_ci_variables(user).size).to be_zero
        end
      end
    end

    describe '#can_edit_profile?' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:project) { create(:project, :small_repo) }
      let_it_be(:user) { create(:user, maintainer_of: project) }
      let_it_be(:dast_profile) { create(:dast_profile, project: project, branch_name: 'master') }

      subject(:dast_site_profile) { DastSiteProfilesFinder.new(id: dast_profile.dast_site_profile_id).execute.to_a.first }

      where(:can_push_to_branch, :result) do
        false | false
        true  | true
      end

      with_them do
        before do
          stub_licensed_features(security_on_demand_scans: true)
        end

        it do
          expect_next_instance_of(Gitlab::UserAccess) do |instance|
            expect(instance).to receive(:can_push_to_branch?).with('master').and_return(can_push_to_branch)
          end

          expect(dast_site_profile.can_edit_profile?(user)).to eq(result)
        end
      end
    end

    describe '#can_edit_profile? avoids N+1 queries' do
      it do
        project = create(:project, :small_repo)
        user = create(:user, maintainer_of: project)
        dast_profile1 = create(:dast_profile, project: project, branch_name: 'master')
        dast_site_profile1 = dast_profile1.dast_site_profile

        control = ActiveRecord::QueryRecorder.new { dast_site_profile1.can_edit_profile?(user) }

        create(:dast_profile, project: project, branch_name: 'master', dast_site_profile: dast_site_profile1)

        expect { dast_site_profile1.can_edit_profile?(user) }.not_to exceed_query_limit(control)
      end
    end
  end

  context 'with loose foreign key on dast_site_profiles.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:dast_site_profile, project: parent) }
    end
  end
end
