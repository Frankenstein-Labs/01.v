# frozen_string_literal: true

# Shared coverage for dismissing the Secrets manager "New" nav badge when the
# secrets page is viewed.
#
# The including context must define:
#   - `request`: the request that renders the secrets index page (named subject)
#   - `reporter`: a user with access to the page (signed in by these examples)
#   - `secrets_container`: the group or project that owns the secrets page
RSpec.shared_examples 'dismisses the secrets manager nav badge on view' do
  context 'when the page is viewed' do
    before do
      stub_licensed_features(native_secrets_management: true)
      sign_in(reporter)
    end

    context 'on a date before the badge expires' do
      around do |example|
        travel_to(::SecretsManagement::NavBadge::BADGE_EXPIRES_ON - 1.day) { example.run }
      end

      it 'dismisses the secrets manager nav badge callout for the user' do
        request

        expect(Users::Callout.find_by(user: reporter, feature_name: :secrets_manager_nav_badge)).to be_present
      end

      context 'when secrets_manager_paid_experience is disabled' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
        end

        it 'does not dismiss the nav badge callout' do
          expect(Users::DismissCalloutService).not_to receive(:new)

          request

          expect(Users::Callout.find_by(user: reporter, feature_name: :secrets_manager_nav_badge)).to be_nil
        end
      end

      context 'when the badge is already dismissed' do
        # Dedicated user signed in only here so its `dismissed_callout?` state
        # isn't affected by an earlier request on the shared signed-in user.
        let_it_be(:dismissed_user, freeze: false) { create(:user, :with_namespace) }

        before do
          secrets_container.add_reporter(dismissed_user)
          create(:callout, user: dismissed_user, feature_name: :secrets_manager_nav_badge)
          sign_in(dismissed_user)
        end

        it 'does not dismiss the nav badge callout again' do
          expect(Users::DismissCalloutService).not_to receive(:new)

          request
        end
      end
    end

    context 'on a date after the badge expires' do
      around do |example|
        travel_to(::SecretsManagement::NavBadge::BADGE_EXPIRES_ON + 1.day) { example.run }
      end

      it 'does not dismiss the nav badge callout' do
        expect(Users::DismissCalloutService).not_to receive(:new)

        request

        expect(Users::Callout.find_by(user: reporter, feature_name: :secrets_manager_nav_badge)).to be_nil
      end
    end
  end
end
