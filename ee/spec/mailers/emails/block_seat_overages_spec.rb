# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Emails::BlockSeatOverages, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  describe '#no_more_seats' do
    let_it_be(:recipient_email) { 'admin@email.com' }
    let_it_be(:recipient) { build(:user, id: 1, email: recipient_email, name: 'RecipientName') }
    let_it_be(:user) { build(:user, id: 2, email: 'user@email.com', name: 'UserName') }
    let_it_be(:project_or_group) { build(:group, id: 111, name: 'GroupName') }

    subject(:email) { Notify.no_more_seats(recipient.id, user.id, project_or_group) }

    context "when recipient exists" do
      let_it_be(:email_subject) { 'Action required: Purchase more seats' }

      before do
        allow(User).to receive(:find_by_id).with(1).and_return(recipient)
        allow(User).to receive(:find_by_id).with(2).and_return(user)
      end

      it 'sends the email to the correct recipient' do
        expect(email).to be_delivered_to([recipient.notification_email_or_default])
      end

      it 'sends the email with expected contents' do
        expect(email).to have_subject(email_subject)

        expect(email.html_part.to_s).to include("Hi #{recipient.name},")
        expect(email.html_part.to_s)
          .to include("#{user.name} tried to invite the following users to the " \
                      "<strong>#{project_or_group.name}</strong> group, but your namespace has no available seats.")
        expect(email.html_part.to_s).to include("You must purchase more seats for your subscription before these " \
                                                "users can be added.")
        expect(email.html_part.to_s).to include("Purchasing more seats does not automatically approve " \
                                                "<strong>requested</strong> users.")
        expect(email.html_part.to_s).to include("After you complete your purchase, you should ask #{user.name} to " \
                                                "make another request to add these users.")
      end

      it 'shows a link to buy more seats' do
        expect(email.html_part.to_s)
          .to include(::Gitlab::Routing.url_helpers.subscription_portal_add_extra_seats_url(project_or_group.id))
      end

      context 'when adding members to a project' do
        let_it_be(:project_or_group) { build(:project, id: 111, name: 'ProjectName') }

        it 'uses the correct label' do
          expect(email.html_part.to_s)
            .to include("#{user.name} tried to invite the following users to " \
                        "the <strong>#{project_or_group.name}</strong> project")
        end
      end
    end
  end

  describe '#dormant_user_blocked_on_reactivation' do
    let_it_be(:recipient) { build(:user, :admin, id: 10, name: 'AdminUser') }
    let_it_be(:blocked_user) { build(:user, id: 20, name: 'Dormant User', username: 'dormant_user') }

    before do
      allow(User).to receive(:find_by_id).with(10).and_return(recipient)
      allow(User).to receive(:find_by_id).with(20).and_return(blocked_user)
    end

    it 'links to the documentation' do
      email = Notify.dormant_user_blocked_on_reactivation(recipient.id, blocked_user.id)

      expect(email).to have_body_text(help_page_url('subscriptions/manage_seats.md', anchor: 'buy-more-seats'))
      expect(email).to have_body_text(help_page_url('subscriptions/manage_seats.md', anchor: 'view-seat-usage'))
      expect(email).to have_body_text(help_page_url('subscriptions/manage_seats.md', anchor: 'restricted-access'))
    end

    context 'on Self-Managed' do
      subject(:email) { Notify.dormant_user_blocked_on_reactivation(recipient.id, blocked_user.id) }

      it_behaves_like 'it should not have Gmail Actions links'
      it_behaves_like 'a user cannot unsubscribe through footer link'
      it_behaves_like 'appearance header and footer enabled'
      it_behaves_like 'appearance header and footer not enabled'

      it 'sends mail with expected contents' do
        expect(email).to have_subject('Action required: Dormant user blocked due to seat limits')
        expect(email).to be_delivered_to([recipient.notification_email_or_default])
        expect(email).to have_body_text('Dormant User')
        expect(email).to have_body_text('dormant_user')
        expect(email).to have_body_text('restricted access')
        expect(email).to have_body_text('pending approval')
      end

      it 'links to the admin users page' do
        expect(email).to have_body_text(::Gitlab::Routing.url_helpers.admin_users_url)
      end
    end

    context 'on GitLab.com', :saas do
      let_it_be(:group_name) { 'Enterprise group' }
      let_it_be(:group) { build(:group, id: 30, path: 'enterprise-group', name: group_name) }

      subject(:email) { Notify.dormant_user_blocked_on_reactivation(recipient.id, blocked_user.id, group.id) }

      before do
        allow(Group).to receive(:find_by_id).with(30).and_return(group)
      end

      it 'sends mail with expected contents' do
        expect(email).to have_subject("#{group_name} | Action required: Dormant user blocked due to seat limits")
        expect(email).to be_delivered_to([recipient.notification_email_or_default])
        expect(email).to have_body_text('Dormant User')
        expect(email).to have_body_text('dormant_user')
        expect(email).to have_body_text('restricted access')
        expect(email).to have_body_text('pending approval')
      end

      context 'when the group does not exist' do
        subject(:email) do
          Notify.dormant_user_blocked_on_reactivation(recipient.id, blocked_user.id, non_existing_record_id)
        end

        before do
          allow(Group).to receive(:find_by_id).with(non_existing_record_id).and_return(nil)
        end

        it 'does not send the email' do
          expect(email.message).to be_a(ActionMailer::Base::NullMail)
        end
      end
    end

    context 'when recipient does not exist' do
      before do
        allow(User).to receive(:find_by_id).with(non_existing_record_id).and_return(nil)
      end

      subject(:email) { Notify.dormant_user_blocked_on_reactivation(non_existing_record_id, blocked_user.id) }

      it 'does not send the email' do
        expect(email.message).to be_a(ActionMailer::Base::NullMail)
      end
    end

    context 'when blocked user does not exist' do
      before do
        allow(User).to receive(:find_by_id).with(non_existing_record_id).and_return(nil)
      end

      subject(:email) { Notify.dormant_user_blocked_on_reactivation(recipient.id, non_existing_record_id) }

      it 'does not send the email' do
        expect(email.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
