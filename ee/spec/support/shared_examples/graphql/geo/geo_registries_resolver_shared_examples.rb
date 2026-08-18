# frozen_string_literal: true

RSpec.shared_examples_for 'a Geo registries resolver' do |registry_factory_name|
  include GraphqlHelpers
  include EE::GeoHelpers

  let_it_be(:secondary, freeze: true) { create(:geo_node) }

  before do
    stub_current_geo_node(secondary)
    stub_geo_setting(registry_replication: { enabled: true })
  end

  describe '#resolve' do
    # rubocop:disable Rails/SaveBang
    let(:replicator_class) { Gitlab::Geo::Replicator.for_class_name(described_class.name) }
    let(:factory_traits) { replicator_class.verification_enabled? ? [:synced, :verification_succeeded] : [:synced] }
    let!(:registry1) { create(registry_factory_name, :synced) }
    let!(:registry2) { create(registry_factory_name, *factory_traits) }
    let!(:registry3) { create(registry_factory_name) }
    let!(:registry4) { create(registry_factory_name, *factory_traits) }
    # rubocop:enable Rails/SaveBang

    let(:registries) { [registry1, registry2, registry3, registry4] }
    let(:gql_context) { { current_user: current_user } }

    context 'when the parent object is the current node' do
      context 'when the user has permission to view Geo data' do
        let_it_be(:current_user, freeze: true) { create(:admin) }

        context 'when admin mode is enabled', :enable_admin_mode do
          context 'when the ids argument is null' do
            it 'returns registries, in order' do
              expect(resolve_registries.to_a).to eq(registries)
            end
          end

          context 'when the ids argument is present' do
            it 'returns the requested registries, in order' do
              requested_ids = [registry3.to_global_id, registry1.to_global_id]
              args = { ids: requested_ids }
              expected = [registry1, registry3]

              expect(resolve_registries(args).to_a).to eq(expected)
            end

            it 'returns an error if the id is not supported' do
              requested_ids = [registry3.id, registry1.id]
              args = { ids: requested_ids }

              expect(resolve_registries(args)).to be_a(::GraphQL::CoercionError)
            end

            it 'returns an error if the id type does not match the registry' do
              requested_id = [create(:project).to_global_id]
              args = { ids: requested_id }

              expect(resolve_registries(args)).to be_a(::GraphQL::CoercionError)
            end
          end

          context 'when the replication_state argument is present' do
            it 'returns registries with requested replication state, in order' do
              args = { replication_state: ::Types::Geo::ReplicationStateEnum.values['SYNCED'].value }
              expected = [registry1, registry2, registry4]

              expect(resolve_registries(args).to_a).to eq(expected)
            end
          end

          context 'when the sort argument is present' do
            it 'returns all registries in sort order' do
              args = { sort: 'id_desc'.upcase }
              expected = [registry4, registry3, registry2, registry1]

              expect(resolve_registries(args).to_a).to eq(expected)
            end
          end

          context 'when replication is disabled' do
            before do
              stub_feature_flags(replicator_class.replication_enabled_feature_key => false)
            end

            it 'returns nothing' do
              expect(resolve_registries).to be_empty
            end
          end

          context 'with verification enabled' do
            before do
              skip_if_verification_is_not_enabled
            end

            context 'when the verification_state argument is present' do
              it 'returns registries with requested verification state, in order' do
                args = { verification_state: ::Types::Geo::VerificationStateEnum.values['SUCCEEDED'].value }
                expected = [registry2, registry4]

                expect(resolve_registries(args).to_a).to eq(expected)
              end
            end

            context 'when the verified_at sort argument is present' do
              it 'returns registries with requested verified_at, in order' do
                args = { sort: 'verified_at_asc'.upcase }
                expected = [registry2, registry4, registry1, registry3]

                expect(resolve_registries(args).to_a).to eq(expected)
              end
            end
          end

          context 'with verification disabled' do
            before do
              skip_if_verification_is_enabled
            end

            context 'when the verification_state argument is present' do
              it 'raises ArgumentError' do
                args = { verification_state: ::Types::Geo::VerificationStateEnum.values['SUCCEEDED'].value }
                message = "Filtering by verification_state is not supported " \
                  "because verification is not enabled for #{replicator_class.model}"

                expect { resolve_registries(args) }.to raise_error(ArgumentError, message)
              end
            end

            context 'when the verified_at sort argument is present' do
              it 'raises ArgumentError' do
                args = { sort: 'verified_at_asc'.upcase }
                message = "Sorting by verified_at is not supported " \
                  "because verification is not enabled for #{replicator_class.model}"

                expect { resolve_registries(args) }.to raise_error(ArgumentError, message)
              end
            end
          end
        end

        context 'when admin mode is disabled' do
          it 'returns nothing' do
            expect(resolve_registries).to be_empty
          end
        end
      end

      context 'when the user does not have permission to view Geo data' do
        let_it_be(:current_user, freeze: true) { create(:user) }

        it 'returns nothing' do
          expect(resolve_registries).to be_empty
        end
      end
    end

    context 'when the parent object is not the current node' do
      context 'when the user has permission to view Geo data' do
        let_it_be(:current_user, freeze: true) { create(:admin) }

        it "returns nothing, because we can't query other nodes' tracking databases" do
          result = resolve(described_class, obj: create(:geo_node), args: {}, ctx: gql_context)

          expect(result).to be_empty
        end
      end
    end
  end

  def resolve_registries(args = {})
    resolve(described_class, obj: secondary, args: args, ctx: gql_context)
  end
end
