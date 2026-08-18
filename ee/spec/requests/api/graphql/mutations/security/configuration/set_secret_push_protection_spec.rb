# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting Project Secret Push Protection', feature_category: :secret_detection do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:security_setting) { create(:project_security_setting, secret_push_protection_enabled: value_before) }
  let(:mutation_name) { :set_secret_push_protection }

  let(:value_before) { false }
  let(:enable) { true }

  context 'with project' do
    let(:project) { security_setting.project }
    let(:mutation) do
      graphql_mutation(
        mutation_name,
        namespace_path: project.full_path,
        enable: enable
      )
    end

    before do
      stub_licensed_features(
        secret_push_protection: true
      )
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable secret push protection' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.secret_push_protection_enabled }
      end
    end

    context 'when the user has permission' do
      before do
        project.add_maintainer(current_user)
      end

      where(:value_before, :enable, :value_after) do
        true  | false | false
        true  | true  | true
        false | true  | true
        false | false | false
      end

      with_them do
        it 'updates the namespace setting and returns the new value' do
          post_graphql_mutation(mutation, current_user: current_user)

          response = graphql_mutation_response(mutation_name)
          expect(response).to include({ 'secretPushProtectionEnabled' => value_after, 'errors' => [] })

          expect(security_setting.reload.secret_push_protection_enabled).to eq(value_after)
        end
      end
    end

    context 'when Secret Push Protection is not available for the project' do
      before do
        stub_licensed_features(secret_push_protection: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable secret push protection' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.secret_push_protection_enabled }
      end
    end

    context 'when a project is archived' do
      before do
        project.update!(archived: true)
      end

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable secret push protection' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.secret_push_protection_enabled }
      end
    end

    context 'when projects group is archived' do
      let_it_be(:group) { create(:group, :archived) }
      let_it_be(:project) { create(:project, group: group) }

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable secret push protection' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.secret_push_protection_enabled }
      end
    end
  end

  context 'with group' do
    let(:group) { create(:group) }
    let(:mutation) do
      graphql_mutation(
        mutation_name,
        namespace_path: group.full_path,
        enable: enable
      )
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable secret push protection' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.secret_push_protection_enabled }
      end
    end

    context 'when the user has permission' do
      before do
        group.add_maintainer(current_user)
        stub_licensed_features(
          secret_push_protection: true
        )
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
