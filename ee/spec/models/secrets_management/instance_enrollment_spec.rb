# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::InstanceEnrollment, feature_category: :secrets_management do
  describe '.enrolled?' do
    context 'when instance is enrolled' do
      before do
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.enrolled?).to be true
      end
    end

    context 'when instance is not enrolled' do
      it 'returns false' do
        expect(described_class.enrolled?).to be false
      end
    end
  end

  describe '.beta?' do
    context 'when instance is enrolled' do
      before do
        stub_application_setting(secrets_manager_instance_enrolled: true)
      end

      it 'returns true' do
        expect(described_class.beta?).to be true
      end
    end

    context 'when instance is not enrolled' do
      it 'returns false' do
        expect(described_class.beta?).to be false
      end
    end
  end

  describe '.enrollment_allowed?' do
    before do
      allow(::License).to receive(:feature_available?).and_call_original
      allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
    end

    context 'when not on GitLab.com' do
      context 'when feature flag is enabled' do
        before do
          stub_feature_flags(secrets_manager_instance_enrollment: true)
        end

        it 'returns true' do
          expect(described_class.enrollment_allowed?).to be true
        end

        context 'when license is not available' do
          before do
            allow(::License).to receive(:feature_available?)
              .with(:native_secrets_management).and_return(false)
          end

          it 'returns false' do
            expect(described_class.enrollment_allowed?).to be false
          end
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_instance_enrollment: false)
        end

        it 'returns false' do
          expect(described_class.enrollment_allowed?).to be false
        end
      end
    end

    context 'when on GitLab.com', :saas do
      it 'returns false' do
        expect(described_class.enrollment_allowed?).to be false
      end
    end
  end
end
