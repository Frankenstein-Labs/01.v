# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::UserPermissions::ProjectEffectiveCapabilitiesService,
  feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let_it_be(:current_user) { create(:user) }

  let(:client_double) { instance_double(SecretsManagement::SecretsManagerClient) }
  let(:data_path) { secrets_manager.ci_full_path('*') }
  let(:detailed_metadata_path) { secrets_manager.detailed_metadata_path('*') }

  subject(:service) do
    described_class.new(secrets_manager: secrets_manager, current_user: current_user, resource: project)
  end

  before do
    allow(SecretsManagement::SecretsManagerClient).to receive(:new).and_return(client_double)
    allow(SecretsManagement::ProjectUserJwt).to receive(:new).and_return(
      instance_double(SecretsManagement::ProjectUserJwt, encoded: 'test-user-jwt')
    )
  end

  def stub_capabilities_self(data_caps:, detailed_metadata_caps:)
    allow(client_double).to receive(:capabilities_self)
      .with(paths: [data_path, detailed_metadata_path])
      .and_return({ "data" => { data_path => data_caps, detailed_metadata_path => detailed_metadata_caps } })
  end

  describe '#execute' do
    before_all do
      project.add_reporter(current_user)
    end

    # OpenBao-only mapping tests. Entitlement gates are covered in the base
    # class spec, so keep the flag off here to avoid coupling the tests.
    before do
      stub_feature_flags(secrets_manager_paid_experience: false)
    end

    it 'builds a user-scoped client with CEL auth and the project namespace' do
      stub_capabilities_self(data_caps: [], detailed_metadata_caps: [])

      expect(SecretsManagement::SecretsManagerClient).to receive(:new).with(
        jwt: 'test-user-jwt',
        role: secrets_manager.user_auth_role,
        auth_namespace: secrets_manager.full_project_namespace_path,
        auth_mount: secrets_manager.user_auth_mount,
        namespace: secrets_manager.full_project_namespace_path,
        use_cel_auth: true
      )

      service.execute
    end

    it 'calls capabilities_self with the data and detailed-metadata paths' do
      expect(client_double).to receive(:capabilities_self)
        .with(paths: [data_path, detailed_metadata_path])
        .and_return({ "data" => { data_path => [], detailed_metadata_path => [] } })

      service.execute
    end

    context 'when the user has read-only capabilities' do
      before do
        stub_capabilities_self(data_caps: [], detailed_metadata_caps: %w[list])
      end

      it 'returns read=true and others false' do
        expect(service.execute).to eq('read_metadata' => true, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when the user has full capabilities' do
      before do
        stub_capabilities_self(data_caps: %w[create update delete], detailed_metadata_caps: %w[list])
      end

      it 'returns true for all capabilities' do
        expect(service.execute).to eq('read_metadata' => true, 'create' => true, 'update' => true, 'delete' => true)
      end
    end

    context 'when OpenBao raises ApiError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::ApiError, 'connection refused'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        expect(service.execute).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when OpenBao raises AuthenticationError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::AuthenticationError, 'auth failed'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        expect(service.execute).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end
  end
end
