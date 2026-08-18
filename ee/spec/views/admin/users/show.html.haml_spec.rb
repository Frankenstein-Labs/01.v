# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/show.html.haml', feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user, email: 'user@example.com') }

  let(:page) { Nokogiri::HTML.parse(rendered) }
  let(:credit_card_status) { page.at('#credit-card-status')&.text }
  let(:phone_status) { page.at('#phone-status')&.text }
  let(:phone_number) { page.at('#phone-number')&.text }

  before do
    assign(:user, user)
  end

  it 'does not include credit card validation status' do
    render

    expect(rendered).not_to include('Credit card validated')
    expect(credit_card_status).to be_nil
  end

  it 'does not include phone number validation status' do
    render

    expect(phone_status).to be_nil
  end

  it 'does not show primary email as secondary email - lists primary email only once' do
    render

    expect(rendered).to have_text('user@example.com', count: 1)
  end

  context 'for namespace plan info' do
    context 'when gitlab_com_subscriptions SaaS feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'includes the plan info' do
        render

        expect(rendered).to have_text('Plan:')
      end

      context 'when namespace is not paid' do
        it 'indicates there is no plan' do
          render

          expect(rendered).to have_text('No Plan')
        end
      end

      context 'when namespace is paid', :saas do
        let(:namespace) { build(:group) }
        let(:user) { build_stubbed(:user, namespace: namespace) }

        before do
          build(:gitlab_subscription, :ultimate, namespace: namespace)
        end

        it 'indicates there is a paid plan' do
          render

          expect(rendered).to have_text('Ultimate')
        end
      end
    end

    context 'when gitlab_com_subscriptions SaaS feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'includes the plan info' do
        render

        expect(rendered).not_to have_text('Plan:')
      end
    end
  end

  context 'when on Gitlab.com', :saas do
    it 'includes credit card validation status' do
      render

      expect(credit_card_status).to match(/Validated:\s+No/)
    end

    it 'includes phone number validation status' do
      render

      expect(phone_status).to match(/Validated:\s+No/)
    end

    context 'when user has validated a credit card' do
      let!(:validation) { create(:credit_card_validation, user: user) }

      it 'includes credit card validation status' do
        render

        expect(credit_card_status).to include 'Validated at:'
      end
    end

    context 'when user has validated a phone number' do
      before do
        create(
          :phone_number_validation,
          :validated,
          user: user,
          international_dial_code: 1,
          phone_number: '123456789',
          country: 'US'
        )
        user.reload
      end

      it 'includes phone validation status' do
        render

        expect(phone_status).to include 'Validated at:'
      end

      it 'includes last attempted phone number' do
        render

        expect(phone_number).to include 'Last attempted number:'
        expect(phone_number).to include "+1 123456789 (US)"
      end
    end
  end

  describe 'email confirmation/verification code last sent at' do
    let(:timestamp) { page.at("[data-testid=\"#{test_id}\"]") }

    where(:sent_at_attr, :test_id, :displayed, :label) do
      :confirmation_sent_at | 'email-confirmation-code-last-sent-at' | lazy { timestamp } | 'Email confirmation code last sent at' # rubocop:disable Layout/LineLength, Lint/RedundantCopDisableDirective -- should be in a single line
      :locked_at            | 'email-verification-code-last-sent-at' | lazy { timestamp } | 'Locked account email verification code last sent at' # rubocop:disable Layout/LineLength, Lint/RedundantCopDisableDirective -- should be in a single line
    end

    with_them do
      context 'when email has been sent' do
        before do
          user.update!(sent_at_attr => Time.zone.parse('2020-04-16 20:15:32 UTC'))
        end

        it 'shows the correct date and time' do
          render

          expect(timestamp).to have_content("#{label}: Apr 16, 2020 8:15pm (code expired)")
        end

        context 'when code has not expired' do
          it 'does not display "(code expired)"' do
            travel_to(Time.zone.parse('2020-04-16 20:30:00 UTC')) do
              render

              expect(timestamp).not_to have_content('(code expired)')
            end
          end
        end
      end

      context 'when email has not been sent' do
        it 'shows "never"' do
          render

          expect(timestamp).to have_content("#{label}: never")
        end
      end
    end
  end
end
