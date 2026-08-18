# frozen_string_literal: true

module QA
  RSpec.describe 'Fulfillment', :requires_admin, only: { subdomain: :staging },
    feature_category: :subscription_management do
    describe 'Utilization' do
      let(:hash) { SecureRandom.hex(8) }

      let(:group_owner) do
        create(:user, :hard_delete, :with_personal_access_token, email: "test-user-#{hash}@gitlab.com")
      end

      let(:owner_api_client) { group_owner.api_client }

      let(:user_2) { create(:user) }
      let(:user_3) { create(:user) }
      let(:user_4) { create(:user) }
      let(:user_5) { create(:user) }
      let(:user_6) { create(:user) }
      let(:user_7) { create(:user) }

      let(:private_group) do
        Resource::Sandbox.fabricate_via_browser_ui! do |sandbox|
          sandbox.path = "fulfillment-private-group-#{hash}"
          sandbox.api_client = owner_api_client
          sandbox.visibility = 'private'
        end
      end

      let(:invitee_group) do
        Resource::Sandbox.fabricate_via_browser_ui! do |sandbox|
          sandbox.path = "invitee-group-#{hash}"
          sandbox.api_client = owner_api_client
          sandbox.visibility = 'private'
        end
      end

      let(:project) do
        create(:project, api_client: owner_api_client, name: "test-project-#{hash}", group: private_group)
      end

      before do
        Flow::Login.sign_in(as: group_owner)
      end

      context 'when Saas user limit experience' do
        it(
          'limit overage enforcement removed from private group when trial is started'
        ) do
          # Check enforcement notification for limit overage
          create_private_group_with_members
          send_private_group_over_limit
          private_group.visit!

          Page::Group::Show.perform do |group|
            expect { group }
              .to eventually_have_content(notifications(private_group, :limit_overage_enforcement_msg))
                .within(max_attempts: 5, sleep_interval: 2, reload_page: page)
          end

          # Remove the enforcement by starting a free Ultimate Trial
          Runtime::Browser.visit(:gitlab, EE::Page::Trials::New)

          # due to invited group used here we have more than one group so we have to select
          register_for_trial(group: private_group)
          private_group.visit!

          Page::Group::Show.perform do |group|
            expect(group).not_to have_content(notifications(private_group, :limit_overage_enforcement_msg))
          end

          # total user is 6, but 1 is an invited group member
          expect { private_group.list_members.count }.to eventually_eq(5)

          private_group.add_member(user_7)

          expect { private_group.list_members.count }.to eventually_eq(6)
        end

        it(
          'new group enforcement removed when trial started'
        ) do
          create_private_group_with_members
          page.refresh

          Page::Group::Show.perform do |group|
            expect { group }
              .to eventually_have_content(notifications(private_group, :limit_reached_enforcement_msg))
                .within(max_attempts: 5, sleep_interval: 2, reload_page: page)
          end

          Runtime::Browser.visit(:gitlab, EE::Page::Trials::New)
          register_for_trial
          private_group.visit!

          Page::Group::Show.perform do |group|
            expect(group).not_to have_content(notifications(private_group, :limit_reached_enforcement_msg))
          end
        end

        it(
          'enforcement does not allow adding more members'
        ) do
          create_private_group_with_members

          # Checks that it fails to add an additional member due to enforcement
          begin
            private_group.add_member(user_7)
          rescue Support::Repeater::RetriesExceededError
            expect { private_group.list_members.count }.to eventually_eq(5)
          end
        end

        it(
          'enforcement limit counts includes invited group and project members'
        ) do
          project.add_member(user_2)
          private_group.add_member(user_3)
          invitee_group.add_members(user_4, user_5, user_6)

          private_group.invite_group(invitee_group)
          private_group.visit!

          Page::Group::Show.perform do |group|
            expect { group }
              .to eventually_have_content(notifications(private_group, :limit_overage_enforcement_msg))
                .within(max_attempts: 5, sleep_interval: 2, reload_page: page)
          end

          aggregate_failures do
            expect(private_group.list_all_members.count).to eq(5) # excludes project unique members
            expect(invitee_group.list_members.count).to eq(4)
          end
        end
      end

      private

      def register_for_trial(group: nil)
        EE::Flow::Trial.register_for_trial(group: group)
        Page::Group::Show.perform do |group|
          expect(group).to have_notice(%r{You have successfully started .*GitLab.* trial})
        end
      end

      # group_owner is also counted, free user member limit for a new private group is 5
      def create_private_group_with_members
        private_group.add_members(user_2, user_3, user_4, user_5)
      end

      def send_private_group_over_limit
        invitee_group.add_member(user_6)
        private_group.invite_group(invitee_group)
      end

      # Returns user limit notification message
      #
      # @param [Resource::Group] group
      # @param [Symbol] type notification message type
      def notifications(group, type)
        {
          limit_reached_enforcement_msg:
            "Your top-level group #{group.path} has reached the 5 user limit To invite more users,
            you can reduce the number of users in your top-level group to 5 users or less",
          limit_overage_enforcement_msg:
            "Your top-level group #{group.path} is over the 5 user limit and has been placed in a read-only state"
        }.fetch(type).squish
      end
    end
  end
end
