# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::PipelineJwt, feature_category: :secrets_management do
  include ProjectForksHelper

  let_it_be_with_reload(:project) { create(:project, :repository, :public) }
  let_it_be_with_reload(:build) { create(:ci_build, project: project) }
  let_it_be(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_pem)
  end

  describe '.for_build' do
    let(:token) { described_class.for_build(build, aud: 'https://secrets.example') }

    subject(:payload) { ::JWT.decode(token, nil, false).first }

    it 'includes secrets_manager_scope="pipeline" in the payload' do
      expect(payload['secrets_manager_scope']).to eq('pipeline')
    end

    context 'when project is not in a group' do
      it 'includes an empty project_group_ids' do
        expect(payload['project_group_ids']).to eq([])
      end
    end

    context 'when project is in a group' do
      let(:group) { create(:group) }

      before do
        project.namespace = group
        project.save!
      end

      it 'includes project_group_ids with the group ID' do
        expect(payload['project_group_ids']).to eq([group.id.to_s])
      end
    end

    context 'when project is in a nested group hierarchy' do
      let!(:root_group) { create(:group) }
      let!(:subgroup_a) { create(:group, parent: root_group) }
      let!(:subgroup_b) { create(:group, parent: subgroup_a) }

      before do
        project.namespace = subgroup_b
        project.save!
      end

      it 'includes project_group_ids with all ancestor group IDs' do
        expect(payload['project_group_ids']).to match_array([
          subgroup_b.id.to_s,
          subgroup_a.id.to_s,
          root_group.id.to_s
        ])
      end
    end

    context 'when the pipeline is for a merge request from a forked project' do
      let_it_be(:user_namespace) { create(:namespace) }
      let_it_be_with_reload(:target_project) { project }
      let_it_be(:user) { user_namespace.owner }

      let_it_be_with_reload(:forked_project) do
        # Ensure user has permission to fork the project
        target_project.add_developer(user)
        fork_project(target_project, user, repository: true, namespace: user_namespace)
      end

      let(:merge_request) do
        create(:merge_request,
          source_project: forked_project,
          source_branch: 'feature',
          target_project: target_project,
          target_branch: 'master')
      end

      let(:pipeline) do
        create(:ci_pipeline,
          source: :merge_request_event,
          merge_request: merge_request,
          project: target_project,
          user: user)
      end

      let(:build) do
        create(:ci_build,
          project: target_project,
          user: user,
          pipeline: pipeline)
      end

      context 'and fork project is not in a group but target project is' do
        let!(:target_group) { create(:group) }

        before do
          target_project.update!(namespace: target_group)
        end

        it 'includes empty project_group_ids from the fork project' do
          expect(payload['project_group_ids']).to eq([])
        end
      end

      context 'and both target and fork projects are in different group hierarchies' do
        let!(:target_root_group) { create(:group) }
        let!(:target_subgroup) { create(:group, parent: target_root_group) }
        let!(:fork_root_group) { create(:group) }
        let!(:fork_subgroup) { create(:group, parent: fork_root_group) }

        before do
          target_project.update!(namespace: target_subgroup)
          forked_project.update!(namespace: fork_subgroup)
        end

        it 'includes project_group_ids from the fork project, not the target project' do
          expect(payload['project_group_ids']).to match_array([
            fork_subgroup.id.to_s,
            fork_root_group.id.to_s
          ])
        end
      end

      context 'and fork project is in a group but target project is not' do
        let!(:fork_group) { create(:group) }

        before do
          forked_project.update!(namespace: fork_group)
        end

        it 'includes project_group_ids from the fork project group' do
          expect(payload['project_group_ids']).to eq([fork_group.id.to_s])
        end
      end

      context 'and both projects are in the same group hierarchy' do
        let!(:shared_group) { create(:group) }

        before do
          target_project.update!(namespace: shared_group)
          forked_project.update!(namespace: shared_group)
        end

        it 'includes project_group_ids from the fork project (which happens to be the same)' do
          expect(payload['project_group_ids']).to eq([shared_group.id.to_s])
        end
      end
    end
  end
end
