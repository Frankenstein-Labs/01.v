# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::UserPermissions::EffectiveCapabilitiesService,
  feature_category: :secrets_management do
  # Concrete subclass used to exercise the base class without a live OpenBao.
  let(:concrete_service_class) do
    Class.new(described_class) do
      attr_writer :stubbed_client

      private

      def user_scoped_client
        @stubbed_client
      end
    end
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let_it_be(:current_user) { create(:user) }

  let(:client_double) { instance_double(SecretsManagement::SecretsManagerClient) }

  let(:data_path) { secrets_manager.ci_full_path('*') }
  let(:detailed_metadata_path) { secrets_manager.detailed_metadata_path('*') }

  subject(:service) do
    svc = concrete_service_class.new(
      secrets_manager: secrets_manager,
      current_user: current_user,
      resource: project
    )
    svc.stubbed_client = client_double
    svc
  end

  # OpenBao returns the per-path capability map under the "data" envelope.
  # readMetadata is derived from `list` on the detailed-metadata path, which is
  # the path the secrets list service actually reads.
  def stub_capabilities_self(data_caps:, detailed_metadata_caps:)
    allow(client_double).to receive(:capabilities_self)
      .with(paths: [data_path, detailed_metadata_path])
      .and_return({ "data" => { data_path => data_caps, detailed_metadata_path => detailed_metadata_caps } })
  end

  describe '#execute' do
    # Isolate the OpenBao-only mapping tests from the entitlement layer.
    # Contexts that specifically exercise the entitlement gates re-enable the
    # flag explicitly.
    before do
      stub_feature_flags(secrets_manager_paid_experience: false)
    end

    context 'when the user has no grant (empty capabilities)' do
      before do
        stub_capabilities_self(data_caps: ['deny'], detailed_metadata_caps: ['deny'])
      end

      it 'returns false for all capabilities' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when the user has a read-only grant' do
      before do
        stub_capabilities_self(data_caps: [], detailed_metadata_caps: %w[list])
      end

      it 'returns read=true and others false' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when the user has a read+write grant' do
      before do
        stub_capabilities_self(data_caps: %w[create update], detailed_metadata_caps: %w[list])
      end

      it 'returns read/create/update=true and delete=false' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => true, 'update' => true, 'delete' => false)
      end
    end

    context 'when the user has a full-access grant' do
      before do
        stub_capabilities_self(data_caps: %w[create update delete], detailed_metadata_caps: %w[list])
      end

      it 'returns true for all capabilities' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => true, 'update' => true, 'delete' => true)
      end
    end

    context 'when capabilities_self returns nil (no policies)' do
      before do
        allow(client_double).to receive(:capabilities_self)
          .with(paths: [data_path, detailed_metadata_path])
          .and_return(nil)
      end

      it 'returns false for all capabilities' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when OpenBao raises ApiError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::ApiError, 'connection refused'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when OpenBao raises ConnectionError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::ConnectionError, 'timeout'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when OpenBao raises ServiceUnavailableError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::ServiceUnavailableError, 'service unavailable'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when OpenBao raises AuthenticationError' do
      before do
        allow(client_double).to receive(:capabilities_self).and_raise(
          SecretsManagement::SecretsManagerClient::AuthenticationError, 'auth failed'
        )
      end

      it 'returns false for all capabilities (fail closed)' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when data path has delete without create or update' do
      before do
        stub_capabilities_self(data_caps: %w[delete], detailed_metadata_caps: %w[list])
      end

      it 'returns delete=true, create=false, update=false, read=true' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => false, 'update' => false, 'delete' => true)
      end
    end

    context 'when data path has update without create' do
      before do
        stub_capabilities_self(data_caps: %w[update], detailed_metadata_caps: %w[list])
      end

      it 'returns update=true, create=false, delete=false, read=true' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => false, 'update' => true, 'delete' => false)
      end
    end

    context 'when response contains unknown/extra capabilities (sudo, root)' do
      before do
        stub_capabilities_self(data_caps: %w[create sudo root], detailed_metadata_caps: %w[list root])
      end

      it 'ignores unknown capabilities and only maps the four known booleans' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => true, 'update' => false, 'delete' => false)
      end
    end

    context 'when response contains list on the data path' do
      before do
        stub_capabilities_self(data_caps: %w[create list], detailed_metadata_caps: %w[list])
      end

      it 'does not leak list on data path into the read boolean' do
        result = service.execute

        # read is derived from the detailed-metadata path only; list on data_path is ignored
        expect(result).to eq('read_metadata' => true, 'create' => true, 'update' => false, 'delete' => false)
      end
    end

    context 'when response is missing the detailed-metadata path key' do
      before do
        allow(client_double).to receive(:capabilities_self)
          .with(paths: [data_path, detailed_metadata_path])
          .and_return({ "data" => { data_path => %w[create update delete] } })
      end

      it 'returns read=false and data caps resolved from data path' do
        result = service.execute

        expect(result).to eq('read_metadata' => false, 'create' => true, 'update' => true, 'delete' => true)
      end
    end

    context 'when response is missing the data path key' do
      before do
        allow(client_double).to receive(:capabilities_self)
          .with(paths: [data_path, detailed_metadata_path])
          .and_return({ "data" => { detailed_metadata_path => %w[list] } })
      end

      it 'returns read=true and all data caps false' do
        result = service.execute

        expect(result).to eq('read_metadata' => true, 'create' => false, 'update' => false, 'delete' => false)
      end
    end

    context 'when the entitlement layer denies writes but permits reads (:blocked)' do
      # Guards against the "button shown for an action the user can't perform"
      # regression: OpenBao may grant write capability but the mutation-side
      # `EnforcesWriteEntitlement` will reject it, so we must not report those
      # writes as available on `userPermissions`. `:blocked` still permits
      # reads so `read_metadata` stays true.
      let_it_be(:root_group) { create(:group) }
      let_it_be(:project) { create(:project, group: root_group) }
      let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        stub_capabilities_self(data_caps: %w[create update delete], detailed_metadata_caps: %w[list])
        allow(::SecretsManagement::Entitlement).to receive(:for).and_return(
          ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :grace)
        )
      end

      it 'zeroes out the write booleans while leaving reads intact' do
        result = service.execute

        expect(result).to eq(
          'read_metadata' => true,
          'create' => false,
          'update' => false,
          'delete' => false
        )
      end
    end

    context 'when the entitlement layer denies reads (:ineligible)' do
      # :ineligible is the one state where `permits_read?` is false. The policy
      # layer already prevents the secrets list query there, so `read_metadata`
      # must not claim the list is readable even when a leftover OpenBao grant
      # exists.
      let_it_be(:root_group) { create(:group) }
      let_it_be(:project) { create(:project, group: root_group) }
      let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        stub_capabilities_self(data_caps: %w[create update delete], detailed_metadata_caps: %w[list])
        allow(::SecretsManagement::Entitlement).to receive(:for).and_return(
          ::SecretsManagement::Entitlement.new(state: :ineligible)
        )
      end

      it 'returns false for all capabilities' do
        result = service.execute

        expect(result).to eq(
          'read_metadata' => false,
          'create' => false,
          'update' => false,
          'delete' => false
        )
      end
    end

    context 'when the entitlement layer permits reads and writes' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:project) { create(:project, group: root_group) }
      let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        stub_capabilities_self(data_caps: %w[create update delete], detailed_metadata_caps: %w[list])
        allow(::SecretsManagement::Entitlement).to receive(:for).and_return(
          ::SecretsManagement::Entitlement.new(state: :paid)
        )
      end

      it 'returns the OpenBao capabilities unchanged' do
        result = service.execute

        expect(result).to eq(
          'read_metadata' => true,
          'create' => true,
          'update' => true,
          'delete' => true
        )
      end
    end
  end
end
