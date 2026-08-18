# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::SendRecurringComplianceEmailService,
  :saas,
  feature_category: :compliance_management do
  let_it_be_with_reload(:pipl_user) { create(:pipl_user) }

  before_all do
    pipl_user.update!(initial_email_sent_at: Time.current)
  end

  subject(:send_email) { described_class.new(user: pipl_user.user).execute }

  context 'when enforce_pipl_compliance setting is enabled' do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it 'sends the pipl email' do
      stub_ee_application_setting(enforce_pipl_compliance: true)

      expect do
        perform_enqueued_jobs do
          send_email
        end
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'returns success response' do
      expect(send_email.error?).to be(false)
    end

    context 'when the validations fail' do
      context 'when the email has not been sent' do
        before do
          pipl_user.update!(initial_email_sent_at: nil)
        end

        it 'returns a service response error' do
          expect(send_email.message).to eq('User is not subject to PIPL or the initial email has yet to be sent')
        end
      end

      context 'when the user is not provided' do
        subject(:send_email) { described_class.new(user: user).execute }

        let(:user) { nil }

        it 'returns a service response error' do
          expect(send_email.message).to eq('User does not exist')
        end
      end

      context 'when the pipl user does not exist' do
        subject(:send_email) { described_class.new(user: user).execute }

        let(:user) { create(:user) }

        it 'returns a service response error' do
          expect(send_email.message).to eq('Pipl user record does not exist')
        end
      end

      context 'when the instance is not a saas one' do
        before do
          stub_saas_features(pipl_compliance: false)
        end

        it 'returns a service response error' do
          expect(send_email.message).to eq('Pipl Compliance is not available on this instance')
        end
      end

      context 'when the users belongs to a paid group' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, guests: pipl_user.user)
        end

        it 'does not send any emails' do
          expect do
            perform_enqueued_jobs do
              send_email
            end
          end.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end
  end

  context "when enforce_pipl_compliance setting is disabled" do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: false)
    end

    it 'returns a service response error' do
      expect(send_email.message).to eq("Feature 'enforce_pipl_compliance' is disabled")
    end

    it 'does not send the email' do
      expect { send_email }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
