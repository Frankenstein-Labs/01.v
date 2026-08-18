# frozen_string_literal: true

RSpec.shared_examples 'an artifact registry service handling validation errors' do |client_method:|
  it_behaves_like 'returning an error service response',
    message: described_class::ERROR_RESPONSES[:saas_only].message

  context 'with saas only feature enabled' do
    before do
      stub_saas_features(google_cloud_support: true)
    end

    shared_examples 'logging an error' do |message:|
      it 'logs an error' do
        expect(service).to receive(:log_error)
          .with(class_name: described_class.name, project_id: project.id, message: message)

        subject
      end
    end

    context 'with not enough permissions' do
      let_it_be(:user, freeze: false) { create(:user) }

      it_behaves_like 'returning an error service response',
        message: described_class::ERROR_RESPONSES[:access_denied].message

      context 'as a guest' do
        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'returning an error service response',
          message: described_class::ERROR_RESPONSES[:access_denied].message
      end

      context 'as anonymous' do
        let_it_be(:user, freeze: false) { nil }

        before do
          project.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
        end

        it_behaves_like 'returning an error service response',
          message: described_class::ERROR_RESPONSES[:access_denied].message
      end
    end

    %i[wlif artifact_registry].each do |integration_type|
      context "with #{integration_type}" do
        let(:integration) { public_send("#{integration_type}_integration") }

        context 'when not present' do
          before do
            integration.destroy!
          end

          it_behaves_like 'returning an error service response',
            message: described_class::ERROR_RESPONSES[:"no_#{integration_type}_integration"].message
        end

        context 'when disabled' do
          before do
            integration.update!(active: false)
          end

          it_behaves_like 'returning an error service response',
            message: described_class::ERROR_RESPONSES[:"#{integration_type}_integration_disabled"].message
        end
      end
    end

    context 'when client raises AuthenticationError' do
      before do
        allow(client_double).to receive(client_method)
          .and_raise(::GoogleCloud::AuthenticationError, 'boom')
      end

      it_behaves_like 'returning an error service response',
        message: described_class::ERROR_RESPONSES[:authentication_error].message
      it_behaves_like 'logging an error', message: 'boom'
    end

    context 'when client raises ApiError' do
      before do
        allow(client_double).to receive(client_method)
          .and_raise(::GoogleCloud::ApiError, 'boom')
      end

      it_behaves_like 'returning an error service response',
        message: described_class::ERROR_RESPONSES[:api_error].message
      it_behaves_like 'logging an error', message: 'boom'
    end
  end
end
