# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Members::StandardRolesResolver, feature_category: :api do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) do
      resolve(described_class, obj: group, args: args, lookahead: positive_lookahead, arg_style: :internal)
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, maintainers: user) }

    context 'when no access_level filter is provided' do
      let_it_be(:args) { nil }

      it 'excludes the Minimal Access role' do
        expect(result.pluck(:access_level)).not_to include(::Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'returns all standard roles sorted by access level' do
        expected = ::Gitlab::Access.options_with_owner.to_a

        expect(result.pluck(:name, :access_level)).to eq(expected)
      end

      it 'includes the Security Manager role' do
        expect(result.pluck(:access_level)).to include(::Gitlab::Access::SECURITY_MANAGER)
      end

      context 'when the security manager role is disabled', :disable_security_manager do
        it 'does not include the Security Manager role' do
          expect(result.pluck(:access_level)).not_to include(::Gitlab::Access::SECURITY_MANAGER)
        end
      end
    end

    context 'when filtering by a single access_level' do
      let_it_be(:args) { { access_level: [::Gitlab::Access::MAINTAINER] } }

      it 'returns only the specified role' do
        expect(result.count).to eq(1)

        role = result.first
        expect(role[:access_level]).to eq(::Gitlab::Access::MAINTAINER)
      end
    end
  end
end
