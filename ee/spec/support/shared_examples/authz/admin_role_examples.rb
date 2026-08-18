# frozen_string_literal: true

RSpec.shared_examples 'permission is allowed/disallowed with feature flags toggled' do
  with_them do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(license => true)
      end

      it { is_expected.to be_disallowed(permission) }

      context 'when admin mode enabled', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(permission) }
      end

      context 'when admin mode disabled' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(permission) }
      end
    end

    context 'when feature is disabled' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(license => false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_disallowed(permission) }
      end
    end
  end
end
