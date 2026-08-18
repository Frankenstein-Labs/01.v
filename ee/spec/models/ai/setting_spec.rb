# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Setting, feature_category: :ai_abstraction_layer do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:organization) { create(:common_organization) }

  describe 'concerns' do
    it { is_expected.to include_module(Ai::HasRolePermissions) }
    it { is_expected.to include_module(Ai::CustomizablePermission) }

    it_behaves_like 'settings with role permissions'
  end

  describe 'associations', :aggregate_failures do
    it 'has expected associations' do
      is_expected.to belong_to(:amazon_q_oauth_application).class_name('Authn::OauthApplication').optional
      is_expected.to belong_to(:amazon_q_service_account_user).class_name('User').optional
      is_expected.to belong_to(:organization).class_name('Organizations::Organization').optional(false)
    end
  end

  describe 'validations', :aggregate_failures do
    context 'when validating duo_cli_enabled' do
      it 'defaults to true' do
        expect(described_class.for_organization(organization).duo_cli_enabled).to be(true)
      end
    end

    context 'when validating the ai_audit_events_streaming_enabled value' do
      describe 'new record' do
        it 'defaults to false' do
          setting = described_class.new

          expect(setting.ai_audit_events_streaming_enabled).to be(false)
        end
      end

      describe 'existing record' do
        it 'persists boolean updates' do
          setting = create(:ai_settings)

          setting.update!(ai_audit_events_streaming_enabled: true)
          expect(setting).to be_valid
          expect(setting.reload.ai_audit_events_streaming_enabled).to be(true)

          setting.update!(ai_audit_events_streaming_enabled: false)
          expect(setting.reload.ai_audit_events_streaming_enabled).to be(false)
        end

        it 'rejects unknown keys in feature_settings' do
          setting = create(:ai_settings)

          setting.feature_settings = setting.feature_settings.merge('unknown_key' => true)

          expect(setting).not_to be_valid
        end
      end
    end

    context 'when validating the duo_core_features_enabled value' do
      describe 'new record' do
        it 'returns nil as the default value' do
          setting = described_class.new

          expect(setting.duo_core_features_enabled).to be_nil
        end
      end

      describe 'existing record' do
        it 'accepts only boolean values for the update' do
          setting = create(:ai_settings)

          setting.update!(duo_core_features_enabled: true)
          expect(setting).to be_valid

          setting.update!(duo_core_features_enabled: false)
          expect(setting).to be_valid

          setting.duo_core_features_enabled = nil
          expect(setting).to be_invalid
        end
      end
    end

    it { is_expected.to validate_length_of(:amazon_q_role_arn).is_at_most(2048).allow_nil }

    context 'for organization_id' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:existing_setting) { create(:ai_settings, organization: other_organization) }

      it 'rejects duplicate non-nil values' do
        setting = described_class.new(organization: other_organization)

        setting.valid?

        expect(setting.errors[:organization_id]).to include('has already been taken')
      end

      it 'requires an organization' do
        setting = described_class.new

        setting.valid?

        expect(setting.errors[:organization]).to include('must exist')
      end
    end
  end

  describe 'before_validation' do
    describe '#normalize_domain_lists' do
      subject(:setting) { described_class.for_organization(organization) }

      it 'lowercases allowed_domains before validation' do
        setting.allowed_domains = ['EXAMPLE.COM', 'GitLab.Com']
        setting.valid?
        expect(setting.allowed_domains).to match_array(['example.com', 'gitlab.com'])
      end

      it 'lowercases denied_domains before validation' do
        setting.denied_domains = ['EVIL.COM', 'Bad.Org']
        setting.valid?
        expect(setting.denied_domains).to match_array(['evil.com', 'bad.org'])
      end
    end
  end

  describe 'after_commit' do
    context 'for trigger_todo_creation' do
      context 'on update' do
        let_it_be_with_reload(:setting) { create(:ai_settings) }

        it 'triggers the todo creation' do
          expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker)
            .to receive(:perform_in).with(7.days, setting.organization_id)

          setting.update!(duo_core_features_enabled: true)
        end

        context 'when duo core features are disabled' do
          it 'does not trigger the todo creation for nil update' do
            expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(duo_core_features_enabled: false)
          end

          context 'when changed from true to false' do
            before do
              setting.update!(duo_core_features_enabled: true)
            end

            it 'does not trigger the todo creation' do
              expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

              setting.update!(duo_core_features_enabled: false)
            end
          end
        end

        context 'when gitlab_duo_saas_only feature is available' do
          before do
            stub_saas_features(gitlab_duo_saas_only: true)
          end

          it 'does not trigger the todo creation' do
            expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(duo_core_features_enabled: true)
          end
        end

        context 'when it is a different column update' do
          it 'does not trigger the todo creation' do
            expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(amazon_q_role_arn: 'arn:aws:iam::123456789012:role/example')
          end
        end
      end

      context 'on create' do
        it 'does not trigger the todo creation' do
          expect(GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

          create(:ai_settings, duo_core_features_enabled: true)
        end
      end
    end
  end

  describe '.self_hosted?' do
    subject(:setting) { described_class.self_hosted? }

    context 'when self-hosted models exist' do
      let!(:self_hosted_model) { create(:ai_self_hosted_model) }

      it { is_expected.to be true }
    end

    context 'when no self-hosted models exist' do
      it { is_expected.to be false }
    end
  end

  describe '.for_organization' do
    let_it_be(:other_organization) { create(:organization) }

    it 'creates and returns the settings row for the organization' do
      setting = described_class.for_organization(organization)

      expect(setting).to be_persisted
      expect(setting.organization_id).to eq(organization.id)
    end

    it 'returns the existing row on subsequent calls' do
      first = described_class.for_organization(organization)
      second = described_class.for_organization(organization)

      expect(second).to eq(first)
    end

    it 'creates separate settings rows for separate organizations', :aggregate_failures do
      setting = described_class.for_organization(organization)
      other_setting = described_class.for_organization(other_organization)

      expect(other_setting).to be_persisted
      expect(other_setting).not_to eq(setting)
      expect(other_setting.organization).to eq(other_organization)
    end

    it 'raises ArgumentError when organization is nil' do
      expect { described_class.for_organization(nil) }.to raise_error(ArgumentError, 'organization is required')
    end
  end

  describe '.for_organization_read_only' do
    it 'returns unpersisted, read-only defaults without creating a row', :aggregate_failures do
      setting = nil

      expect { setting = described_class.for_organization_read_only(organization) }
        .not_to change { described_class.count }

      expect(setting).not_to be_persisted
      expect(setting).to be_readonly
      expect(setting.organization).to eq(organization)
      expect(setting.duo_agent_platform_enabled).to be(true)
    end

    it 'returns a fresh, read-only copy of the existing row', :aggregate_failures do
      persisted_setting = described_class.for_organization(organization)

      setting = described_class.for_organization_read_only(organization)

      expect(setting).to be_persisted
      expect(setting).to be_readonly
      expect(setting).to eq(persisted_setting)
      expect(setting).not_to equal(persisted_setting)
    end

    it 'raises ArgumentError when organization is nil' do
      expect { described_class.for_organization_read_only(nil) }
        .to raise_error(ArgumentError, 'organization is required')
    end
  end

  describe '.for_current_or_default_organization' do
    context 'when a request organization is assigned' do
      it 'returns the read-only setting for the current organization' do
        allow(::Current).to receive_messages(organization_assigned: true, organization: organization)

        setting = described_class.for_current_or_default_organization

        expect(setting).to be_readonly
        expect(setting.organization).to eq(organization)
      end
    end

    context 'when no request organization is assigned' do
      before do
        allow(::Current).to receive(:organization_assigned).and_return(false)
      end

      it 'falls back to the default organization' do
        default_organization = create(:organization, :default) # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- exercising the default organization fallback

        setting = described_class.for_current_or_default_organization

        expect(setting).to be_readonly
        expect(setting.organization).to eq(default_organization)
      end

      context 'when no default organization exists' do
        it 'returns read-only defaults without an organization' do
          allow(::Organizations::Organization).to receive(:default_organization).and_return(nil)

          setting = described_class.for_current_or_default_organization

          expect(setting).not_to be_persisted
          expect(setting).to be_readonly
          expect(setting.organization).to be_nil
        end
      end
    end
  end

  describe '.duo_core_features_enabled_uncached?' do
    subject(:setting) { described_class.duo_core_features_enabled_uncached?(organization) }

    it 'returns the current persisted value without using the cached lookup' do
      ai_settings = described_class.for_organization(organization)
      ai_settings.update!(duo_core_features_enabled: true)
      described_class.duo_core_features_enabled?(organization)
      ai_settings.update!(duo_core_features_enabled: false)

      expect(setting).to be(false)
    end
  end

  describe '.amazon_q_service_account?' do
    let_it_be(:amazon_q_user) { create(:user, organization: organization) }

    before do
      described_class.for_organization(organization).update!(amazon_q_service_account_user: amazon_q_user)
    end

    it 'returns true for the configured Amazon Q service account user' do
      expect(described_class.amazon_q_service_account?(amazon_q_user)).to be true
    end

    it 'returns false for a different user' do
      other_user = create(:user, organization: organization)
      expect(described_class.amazon_q_service_account?(other_user)).to be false
    end

    context 'when no Amazon Q service account is configured' do
      before do
        described_class.for_organization(organization).update!(amazon_q_service_account_user: nil)
      end

      it 'returns false' do
        expect(described_class.amazon_q_service_account?(amazon_q_user)).to be false
      end
    end
  end

  describe '.duo_core_features_enabled?' do
    subject(:setting) { described_class.duo_core_features_enabled?(organization) }

    where(:duo_core_features_enabled, :expected_result) do
      true  | true
      false | false
      nil   | false
    end

    with_them do
      before do
        described_class.for_organization(organization).update!(duo_core_features_enabled: duo_core_features_enabled)
      end

      it 'returns the expected result' do
        expect(setting).to eq(expected_result)
      end
    end
  end
end
