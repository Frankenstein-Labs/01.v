# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ScanProfileResolver, feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  let(:resolver) { described_class }

  describe '#resolve' do
    shared_examples 'raises resource not available error' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_scan_profile(id)
        end
      end
    end

    context 'when user does not have permission' do
      let(:id) { scan_profile.to_global_id }

      include_examples 'raises resource not available error'
    end

    context 'when user has permission' do
      before_all do
        group.add_developer(current_user)
      end

      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when resolving by numeric persisted id' do
        context 'when scan profile exists' do
          let(:id) { scan_profile.to_global_id }

          it 'returns the scan profile' do
            expect(resolve_scan_profile(id)).to eq(scan_profile)
          end
        end

        context 'when scan profile does not exist' do
          let(:id) { build_scan_profile_gid(non_existing_record_id) }

          include_examples 'raises resource not available error'
        end

        context 'when scan profile is soft-deleted' do
          let(:id) { scan_profile.to_global_id }

          before do
            ::Security::ScanProfile.find(scan_profile.id).destroy!
          end

          include_examples 'raises resource not available error'
        end
      end

      context 'when resolving by scan type enum' do
        context 'when scan type exists' do
          let(:id) { build_scan_profile_gid('secret_detection') }

          it 'returns the default scan profile matching the scan type' do
            result = resolve_scan_profile(id)

            expect(result.scan_type).to eq('secret_detection')
          end
        end

        context 'when scan type exists but default profile does not' do
          let(:id) { build_scan_profile_gid('container_scanning') }

          include_examples 'raises resource not available error'
        end

        context 'when scan type does not exist in enum' do
          let(:id) { build_scan_profile_gid('non_existing_enum_type') }

          include_examples 'raises resource not available error'
        end
      end

      context 'when security_scan_profiles feature is disabled' do
        let(:id) { scan_profile.to_global_id }

        before do
          stub_licensed_features(security_scan_profiles: false)
        end

        include_examples 'raises resource not available error'
      end
    end
  end

  def resolve_scan_profile(id)
    resolve(resolver, args: { id: id }, ctx: { current_user: current_user }, arg_style: :internal)
  end

  def build_scan_profile_gid(id)
    GlobalID.new(::Gitlab::GlobalId.build(model_name: 'Security::ScanProfile', id: id))
  end
end
