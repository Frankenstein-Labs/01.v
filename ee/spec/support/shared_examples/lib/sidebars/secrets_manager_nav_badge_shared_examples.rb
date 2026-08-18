# frozen_string_literal: true

# Shared coverage for the "New" badge on the Secrets manager sidebar item.
#
# The including context must define:
#   - `secrets_manager_menu_item`: the rendered `:secrets_manager` menu item
#   - `user`: the current user used to build the sidebar context
RSpec.shared_examples 'secrets manager nav item with a New badge' do
  describe 'New badge' do
    before do
      stub_licensed_features(native_secrets_management: true)
    end

    context 'on a date before the badge expires' do
      around do |example|
        travel_to(::SecretsManagement::NavBadge::BADGE_EXPIRES_ON - 1.day) { example.run }
      end

      context 'when secrets_manager_paid_experience is enabled' do
        it 'adds a "New" badge to the menu item' do
          expect(secrets_manager_menu_item.badge).to eq({ label: 'New' })
        end
      end

      context 'when secrets_manager_paid_experience is disabled' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
        end

        it 'does not add a badge to the menu item' do
          expect(secrets_manager_menu_item.badge).to be_nil
        end
      end

      context 'when the user has dismissed the badge callout' do
        before do
          allow(user).to receive(:dismissed_callout?).and_call_original
          allow(user).to receive(:dismissed_callout?)
            .with(feature_name: 'secrets_manager_nav_badge').and_return(true)
        end

        it 'does not add a badge to the menu item' do
          expect(secrets_manager_menu_item.badge).to be_nil
        end
      end
    end

    context 'on a date after the badge expires' do
      around do |example|
        travel_to(::SecretsManagement::NavBadge::BADGE_EXPIRES_ON + 1.day) { example.run }
      end

      it 'does not add a badge to the menu item' do
        expect(secrets_manager_menu_item.badge).to be_nil
      end
    end
  end
end
