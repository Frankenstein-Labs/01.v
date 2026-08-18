# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedRefs::AccessLevelParams, feature_category: :source_code_management do
  describe '#access_levels' do
    subject(:access_levels) { described_class.new(type, params).access_levels }

    let(:type) { :push }

    describe 'EE granular access levels' do
      context 'when allowed_to_push contains user_id entries' do
        let(:params) { { allowed_to_push: [{ user_id: 1 }] } }

        it 'returns the user access level' do
          expect(access_levels).to eq([{ user_id: 1 }])
        end
      end

      context 'when allowed_to_push contains group_id entries' do
        let(:params) { { allowed_to_push: [{ group_id: 1 }] } }

        it 'returns the group access level' do
          expect(access_levels).to eq([{ group_id: 1 }])
        end
      end

      context 'when allowed_to_push contains access_level entries' do
        let(:params) { { allowed_to_push: [{ access_level: Gitlab::Access::DEVELOPER }] } }

        it 'returns the specified access level' do
          expect(access_levels).to eq([{ access_level: Gitlab::Access::DEVELOPER }])
        end
      end

      context 'when allowed_to_push contains mixed granular entries' do
        let(:params) do
          {
            allowed_to_push: [
              { user_id: 1 },
              { group_id: 2 },
              { access_level: Gitlab::Access::DEVELOPER }
            ]
          }
        end

        it 'returns all granular access levels' do
          expect(access_levels).to contain_exactly(
            { user_id: 1 },
            { group_id: 2 },
            { access_level: Gitlab::Access::DEVELOPER }
          )
        end
      end

      context 'when allowed_to_push contains both deploy keys and granular entries' do
        let(:params) do
          {
            allowed_to_push: [
              { deploy_key_id: 1 },
              { user_id: 2 },
              { access_level: Gitlab::Access::DEVELOPER }
            ]
          }
        end

        it 'returns deploy keys from FOSS and granular access levels from EE' do
          expect(access_levels).to contain_exactly(
            { deploy_key_id: 1 },
            { user_id: 2 },
            { access_level: Gitlab::Access::DEVELOPER }
          )
        end
      end

      context 'when allowed_to_push contains member_role_id entries' do
        let(:params) { { allowed_to_push: [{ member_role_id: 1 }] } }

        it 'returns the member role access level' do
          expect(access_levels).to eq([{ member_role_id: 1 }])
        end
      end

      context 'when allowed_to_push contains member_role_id mixed with other entries' do
        let(:params) do
          {
            allowed_to_push: [
              { member_role_id: 1 },
              { user_id: 2 },
              { deploy_key_id: 3 }
            ]
          }
        end

        it 'returns all entries correctly' do
          expect(access_levels).to contain_exactly(
            { member_role_id: 1 },
            { user_id: 2 },
            { deploy_key_id: 3 }
          )
        end
      end
    end

    describe 'EE use_default_access_level? override' do
      context 'when allowed_to_push is blank' do
        let(:params) { {} }

        it 'uses default maintainer access level' do
          expect(access_levels).to eq([{ access_level: Gitlab::Access::MAINTAINER }])
        end
      end

      context 'when allowed_to_push is present but empty' do
        let(:params) { { allowed_to_push: [] } }

        it 'uses default maintainer access level' do
          expect(access_levels).to eq([{ access_level: Gitlab::Access::MAINTAINER }])
        end
      end

      context 'when allowed_to_push has entries' do
        let(:params) { { allowed_to_push: [{ access_level: Gitlab::Access::DEVELOPER }] } }

        it 'does not use default access level' do
          expect(access_levels).to eq([{ access_level: Gitlab::Access::DEVELOPER }])
        end
      end

      context 'when allowed_to_push has only member_role_id entries' do
        let(:params) { { allowed_to_push: [{ member_role_id: 1 }] } }

        it 'does not prepend default Maintainer access level' do
          expect(access_levels).to eq([{ member_role_id: 1 }])
        end
      end
    end

    describe 'with_defaults: false' do
      subject(:access_levels) { described_class.new(type, params, with_defaults: false).access_levels }

      context 'when allowed_to_push has granular entries' do
        let(:params) { { allowed_to_push: [{ user_id: 1 }, { group_id: 2 }] } }

        it 'returns granular access levels without default' do
          expect(access_levels).to contain_exactly(
            { user_id: 1 },
            { group_id: 2 }
          )
        end
      end
    end
  end
end
