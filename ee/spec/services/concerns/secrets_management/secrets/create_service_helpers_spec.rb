# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Secrets::CreateServiceHelpers,
  feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:current_user) { user }

  let(:service_instance) do
    Class.new do
      include SecretsManagement::Secrets::CreateServiceHelpers

      attr_reader :secrets_manager, :current_user

      def initialize(secrets_manager, current_user)
        @secrets_manager = secrets_manager
        @current_user = current_user
      end
    end.new(secrets_manager, current_user)
  end

  before do
    allow(secrets_manager).to receive(:active?).and_return(true) if secrets_manager
  end

  describe '#secrets_limit_exceeded_response' do
    subject(:response) { service_instance.send(:secrets_limit_exceeded_response) }

    context 'when secrets_manager is ProjectSecretsManager' do
      let(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(123)
      end

      it 'returns an error ServiceResponse with the expected reason' do
        expect(response).to be_error
        expect(response.reason).to eq(:secrets_limit_exceeded)
      end

      it 'includes the limit and scope in the message' do
        expect(response.message).to include('Maximum number of secrets (123)')
        expect(response.message).to include('for this project')
      end
    end

    context 'when secrets_manager is GroupSecretsManager' do
      let(:secrets_manager) { create(:group_secrets_manager, group: group) }

      before do
        allow(secrets_manager).to receive(:secrets_limit).and_return(456)
      end

      it 'returns an error ServiceResponse with the expected reason' do
        expect(response).to be_error
        expect(response.reason).to eq(:secrets_limit_exceeded)
      end

      it 'includes the limit and scope in the message' do
        expect(response.message).to include('Maximum number of secrets (456)')
        expect(response.message).to include('for this group')
      end
    end
  end

  describe '#secrets_count_service' do
    it 'raises a NotImplementedError' do
      expect { service_instance.send(:secrets_count_service) }
        .to raise_error(NotImplementedError, /must implement #secrets_count_service/)
    end
  end
end
