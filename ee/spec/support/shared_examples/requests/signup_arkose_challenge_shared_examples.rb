# frozen_string_literal: true

RSpec.shared_examples 'creates a user with ArkoseLabs risk band on signup request' do
  let(:arkose_labs_params) { { arkose_labs_token: 'arkose-labs-token' } }
  let(:params) { { user: user_attrs }.merge(arkose_labs_params) }

  before do
    stub_arkose_token_verification(token_verification_response: :success)
  end

  subject(:create_user) { post registration_path, params: params }

  shared_examples 'creates the user' do
    it 'creates the user' do
      create_user

      created_user = User.find_by_email(user_attrs[:email])
      expect(created_user).not_to be_nil
    end
  end

  shared_examples 'renders new action with an alert flash' do
    it 'renders new action with an alert flash', :aggregate_failures do
      create_user

      expect(flash[:alert]).to eq(
        s_('Session|There was a error loading the user verification challenge. Refresh to try again.')
      )
      expect(response).to render_template(:new)
    end
  end

  shared_examples 'skips verification and data recording' do
    it 'skips verification and data recording', :aggregate_failures do
      expect(Arkose::TokenVerificationService).not_to receive(:new)
      expect(Arkose::RecordUserDataService).not_to receive(:new)

      create_user
    end
  end

  context 'when arkose verification succeeds' do
    it_behaves_like 'creates the user'

    it "records the user's data from Arkose Labs and logs the event", :aggregate_failures do
      allow(Gitlab::AppLogger).to receive(:info)

      expect { create_user }.to change { UserCustomAttribute.count }.from(0)

      expect(Gitlab::AppLogger).to have_received(:info).with(
        hash_including(message: 'Arkose challenge solved')
      )

      expect(Gitlab::AppLogger).to have_received(:info).with(
        hash_including(message: 'Arkose risk band assigned to user')
      )
    end
  end

  context 'when user is not persisted' do
    before do
      create(:user, email: user_attrs[:email])
    end

    it "does not record the user's data from Arkose Labs" do
      expect(Arkose::RecordUserDataService).not_to receive(:new)

      # try to create a user with duplicate email
      create_user
    end
  end

  context 'when feature is disabled' do
    before do
      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(false)
    end

    it_behaves_like 'creates the user'

    it_behaves_like 'skips verification and data recording'

    context 'when reCAPTCHA is enabled' do
      before do
        stub_application_setting(recaptcha_enabled: true)
      end

      it_behaves_like 'creates the user'

      context 'when reCAPTCHA verification fails' do
        before do
          allow_next_instance_of(described_class) do |controller|
            allow(controller).to receive(:verify_recaptcha).and_return(false)
          end
        end

        it 'does not create the user' do
          create_user

          expect(User.find_by(email: user_attrs[:email])).to be_nil
          expect(flash[:alert]).to eq(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
        end
      end
    end
  end

  context 'when arkose verification fails' do
    context 'when arkose is operational' do
      before do
        stub_arkose_token_verification(token_verification_response: :failed, service_down: false)
      end

      it_behaves_like 'renders new action with an alert flash'

      it 'skips data recording' do
        expect(Arkose::RecordUserDataService).not_to receive(:new)

        create_user
      end

      it 'logs the event' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'Arkose was unable to verify the token'
          )
        )

        create_user
      end
    end

    context 'when arkose is experiencing an outage' do
      before do
        stub_arkose_token_verification(token_verification_response: :failed, service_down: true)
      end

      it_behaves_like 'creates the user'

      it 'logs the event' do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'Arkose challenge skipped',
            reason: 'Arkose is experiencing an outage',
            username: user_attrs[:username]
          )
        )

        create_user
      end
    end
  end
end
