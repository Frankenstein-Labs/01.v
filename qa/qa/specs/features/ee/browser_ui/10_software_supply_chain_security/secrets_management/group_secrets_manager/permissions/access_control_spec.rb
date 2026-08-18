# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    :requires_admin,
    feature_category: :secrets_management
  ) do
    include_context 'group secrets manager base'
    describe 'Access secret permissions' do
      context 'when a maintainer accesses the secret permissions' do
        let(:maintainer) { create(:user) }

        it 'cannot access the group secret permissions' do
          # Managing group secret permissions needs Owner (admin_group); even a Maintainer is denied
          # the group settings page entirely.
          group.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            group.reload!
            group.find_member(maintainer.username).present?
          end

          Flow::Login.while_signed_in(as: maintainer) do
            visit("#{group.web_url}/-/edit#js-permissions-settings")

            expect(page).to have_text('404: Page not found')
          end
        end
      end

      context 'when a non-member accesses the secret permissions' do
        let(:non_group_owner) { create(:user) }
        let(:other_group) { create(:group) }

        it 'cannot access the group secret permissions' do
          other_group.add_member(non_group_owner, Resource::Members::AccessLevel::OWNER)

          Flow::Login.while_signed_in(as: non_group_owner) do
            visit("#{group.web_url}/-/edit#js-permissions-settings")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
