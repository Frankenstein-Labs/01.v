# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- enrollment checks require DB persistence
RSpec.describe SecretsManagement::Availability, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :empty_repo, group: group) }

  describe '.for_project?' do
    before do
      stub_licensed_features(native_secrets_management: true)
    end

    context 'when feature flag is enabled and namespace is enrolled', :saas do
      before do
        stub_feature_flags(secrets_manager: project)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns true' do
        expect(described_class.for_project?(project)).to be true
      end
    end

    context 'when feature flag is enabled and instance is enrolled' do
      before do
        stub_feature_flags(secrets_manager: project)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.for_project?(project)).to be true
      end
    end

    context 'when feature flag is enabled but not enrolled' do
      before do
        stub_feature_flags(secrets_manager: project)
      end

      it 'returns false' do
        expect(described_class.for_project?(project)).to be false
      end
    end

    context 'when feature flag is disabled', :saas do
      before do
        stub_feature_flags(secrets_manager: false)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns false even when enrolled' do
        expect(described_class.for_project?(project)).to be false
      end
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(native_secrets_management: false)
        stub_feature_flags(secrets_manager: project)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns false' do
        expect(described_class.for_project?(project)).to be false
      end
    end
  end

  describe '.for_group?' do
    before do
      stub_licensed_features(native_secrets_management: true)
    end

    context 'when feature flag is enabled and namespace is enrolled', :saas do
      before do
        stub_feature_flags(group_secrets_manager: group)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns true' do
        expect(described_class.for_group?(group)).to be true
      end
    end

    context 'when feature flag is enabled and instance is enrolled' do
      before do
        stub_feature_flags(group_secrets_manager: group)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.for_group?(group)).to be true
      end
    end

    context 'when feature flag is enabled but not enrolled' do
      before do
        stub_feature_flags(group_secrets_manager: group, secrets_manager_paid_experience: false)
      end

      it 'returns false' do
        expect(described_class.for_group?(group)).to be false
      end
    end

    context 'when paid experience is enabled and group is a top-level group', :saas do
      let_it_be(:subgroup) { create(:group, parent: group) }

      before do
        stub_feature_flags(group_secrets_manager: true, secrets_manager_paid_experience: group)
      end

      it 'returns true for the top-level group even when not enrolled' do
        expect(described_class.for_group?(group)).to be true
      end

      it 'returns false for a subgroup when the root is not enrolled' do
        expect(described_class.for_group?(subgroup)).to be false
      end

      context 'when the root is enrolled' do
        before do
          create(:secrets_manager_namespace_enrollment, namespace: group)
        end

        it 'returns true for a subgroup' do
          expect(described_class.for_group?(subgroup)).to be true
        end
      end
    end

    context 'when feature flag is disabled', :saas do
      before do
        stub_feature_flags(group_secrets_manager: false)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns false even when enrolled' do
        expect(described_class.for_group?(group)).to be false
      end
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(native_secrets_management: false)
        stub_feature_flags(group_secrets_manager: group)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns false' do
        expect(described_class.for_group?(group)).to be false
      end
    end
  end

  describe '.for_instance?' do
    context 'when license is available and instance is enrolled' do
      before do
        allow(::License).to receive(:feature_available?).and_call_original
        allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.for_instance?).to be true
      end
    end

    context 'when license is not available' do
      before do
        allow(::License).to receive(:feature_available?).and_call_original
        allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(false)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns false' do
        expect(described_class.for_instance?).to be false
      end
    end

    context 'when instance is not enrolled' do
      before do
        allow(::License).to receive(:feature_available?).and_call_original
        allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
      end

      it 'returns false' do
        expect(described_class.for_instance?).to be false
      end
    end
  end

  describe '.enabled_for_project?' do
    context 'when feature flag is enabled and namespace is enrolled', :saas do
      before do
        stub_feature_flags(secrets_manager: project)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns true' do
        expect(described_class.enabled_for_project?(project)).to be true
      end
    end

    context 'when feature flag is enabled and instance is enrolled' do
      before do
        stub_feature_flags(secrets_manager: project)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.enabled_for_project?(project)).to be true
      end
    end

    context 'when feature flag is enabled but not enrolled' do
      before do
        stub_feature_flags(secrets_manager: project)
      end

      it 'returns false' do
        expect(described_class.enabled_for_project?(project)).to be false
      end
    end

    context 'when feature flag is disabled', :saas do
      before do
        stub_feature_flags(secrets_manager: false)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns false even when enrolled' do
        expect(described_class.enabled_for_project?(project)).to be false
      end
    end

    it 'does not require the license' do
      stub_licensed_features(native_secrets_management: false)
      stub_feature_flags(secrets_manager: project)
      stub_application_setting(secrets_manager_instance_enrolled: true)

      expect(described_class.enabled_for_project?(project)).to be true
    end
  end

  describe '.enabled_for_group?' do
    context 'when feature flag is enabled and namespace is enrolled', :saas do
      before do
        stub_feature_flags(group_secrets_manager: group)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns true' do
        expect(described_class.enabled_for_group?(group)).to be true
      end
    end

    context 'when feature flag is enabled and instance is enrolled' do
      before do
        stub_feature_flags(group_secrets_manager: group)
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.enabled_for_group?(group)).to be true
      end
    end

    context 'when feature flag is enabled but not enrolled' do
      before do
        stub_feature_flags(group_secrets_manager: group, secrets_manager_paid_experience: false)
      end

      it 'returns false' do
        expect(described_class.enabled_for_group?(group)).to be false
      end
    end

    context 'when paid experience is enabled and group is a top-level group', :saas do
      let_it_be(:subgroup) { create(:group, parent: group) }

      before do
        stub_feature_flags(group_secrets_manager: true, secrets_manager_paid_experience: group)
      end

      it 'returns true for the top-level group even when not enrolled' do
        expect(described_class.enabled_for_group?(group)).to be true
      end

      it 'returns false for a subgroup when the root is not enrolled' do
        expect(described_class.enabled_for_group?(subgroup)).to be false
      end
    end

    context 'when feature flag is disabled', :saas do
      before do
        stub_feature_flags(group_secrets_manager: false)
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns false even when enrolled' do
        expect(described_class.enabled_for_group?(group)).to be false
      end
    end

    it 'does not require the license' do
      # Pin paid_experience off so this passes via the instance-enrolled
      # branch rather than accidentally via the paid-experience shortcut
      # when the FF's default flips.
      stub_licensed_features(native_secrets_management: false)
      stub_feature_flags(group_secrets_manager: group, secrets_manager_paid_experience: false)
      stub_application_setting(secrets_manager_instance_enrolled: true)

      expect(described_class.enabled_for_group?(group)).to be true
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
