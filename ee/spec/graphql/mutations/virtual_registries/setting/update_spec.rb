# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Setting::Update, feature_category: :virtual_registry do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:setting) { create(:virtual_registries_setting, :disabled, group: group) }
  let_it_be(:current_user) { create(:user) }
  let(:params) { { full_path: group.full_path, enabled: true } }

  specify { expect(described_class).to require_graphql_authorizations(:admin_virtual_registry) }

  describe '#resolve' do
    subject { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    before do
      stub_licensed_features(packages_virtual_registry: true)
    end

    shared_examples 'updating the virtual registries setting' do
      it 'updates the setting and returns no errors' do
        expect(subject).to eq(
          virtual_registries_setting: setting,
          errors: []
        )
        expect(setting.reload.enabled).to be(true)
      end
    end

    shared_examples 'denying access to virtual registries setting' do
      it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'with different user roles' do
      where(:user_role, :shared_examples_name) do
        :owner | 'updating the virtual registries setting'
        :maintainer | 'denying access to virtual registries setting'
        :anonymous  | 'denying access to virtual registries setting'
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", current_user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end

    context 'for admin' do
      let_it_be(:current_user) { build_stubbed(:user, :admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'updating the virtual registries setting'
      end

      context 'when admin mode is disabled' do
        it_behaves_like 'denying access to virtual registries setting'
      end
    end

    context 'for subgroups' do
      let_it_be(:parent_group) { group }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:current_user) { create(:user, owner_of: [group, parent_group]) }

      it_behaves_like 'denying access to virtual registries setting'
    end

    context 'when the maven_virtual_registry feature flag is disabled' do
      before do
        stub_feature_flags(maven_virtual_registry: false)
      end

      it_behaves_like 'denying access to virtual registries setting'
    end

    context 'when package license is not available' do
      before do
        stub_licensed_features(packages_virtual_registry: false)
      end

      it_behaves_like 'denying access to virtual registries setting'
    end
  end
end
