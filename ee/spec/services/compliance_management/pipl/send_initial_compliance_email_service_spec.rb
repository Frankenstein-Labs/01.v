# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::SendInitialComplianceEmailService, feature_category: :compliance_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:pipl_user) { create(:pipl_user, user: user) }

  subject(:send_email) { described_class.new(user: user).execute }

  before do
    stub_ee_application_setting(enforce_pipl_compliance: true)
  end

  it 'sends the pipl email' do
    expect do
      perform_enqueued_jobs do
        send_email
      end
    end.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  it 'updates the timestamp', :freeze_time do
    expect { send_email }
      .to change { pipl_user.reload.initial_email_sent_at }
            .from(nil).to(Time.current)
  end

  it 'returns success response' do
    expect(send_email).to be_success
  end

  context 'when the validations fail' do
    context 'when the email has already been sent' do
      before do
        pipl_user.update!(initial_email_sent_at: Time.current)
      end

      it 'returns a service response error' do
        expect(send_email.message).to eq('Initial email has already been sent')
      end
    end

    context 'when the user is not provided' do
      let(:user) { nil }

      it 'returns a service response error' do
        expect(send_email.message).to eq('User does not exist')
      end
    end

    context 'when the pipl user record does not exist' do
      before do
        pipl_user.destroy!
      end

      it 'returns a service response error' do
        expect(send_email.message).to eq('Pipl user record does not exist')
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

    it 'does not change the timestamp' do
      expect { send_email }
        .to not_change { pipl_user.initial_email_sent_at }
    end
  end

  context 'when updating the timestamp fails' do
    before do
      allow(user).to receive(:pipl_user).and_return(pipl_user)
      allow(pipl_user).to receive(:update!).and_raise(StandardError)
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it 'raises an exception and does not perform the operation' do
      expect { send_email }.to raise_error(StandardError)
      expect(pipl_user.initial_email_sent_at).to be_nil
      expect(ActionMailer::Base.deliveries.count).to be(0)
    end
  end
end
