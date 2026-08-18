# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Auth::ContainerRegistryAuthenticationService, feature_category: :container_registry do
  include AdminModeHelper
  include_context 'container registry auth service context'

  shared_examples 'returning tag name patterns when tag rules exist' do
    context 'when the project has protection rules' do
      let(:push_delete_patterns_meta) { { 'tag_immutable_patterns' => %w[immutable1 immutable2] } }

      before_all do
        create(:container_registry_protection_tag_rule, project: project, tag_name_pattern: 'mutable')
        create(:container_registry_protection_tag_rule, :immutable, project: project, tag_name_pattern: 'immutable1')
        create(:container_registry_protection_tag_rule, :immutable, project: project, tag_name_pattern: 'immutable2')
      end

      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      it 'has the correct scope' do
        expect(payload).to include('access' => access)
      end
    end
  end

  describe 'with deploy keys' do
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be(:current_user) { nil }
    let_it_be(:project) { create(:project, group: group) }

    let(:deploy_token) { create(:deploy_token, projects: [project], read_registry: true, write_registry: true) }

    context 'with IP restriction' do
      before do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
        stub_licensed_features(group_ip_restriction: true)
      end

      context 'group with restriction' do
        context 'address is within the range' do
          before_all do
            create(:ip_restriction, group: group, range: '192.168.0.0/24')
          end

          it_behaves_like 'a container registry auth service'
        end

        context 'address is outside the range' do
          before_all do
            create(:ip_restriction, group: group, range: '10.0.0.0/8')
          end
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push,pull"], deploy_token: deploy_token }
          end

          context 'when actor is a deploy token with read access' do
            it_behaves_like 'an inaccessible'
            it_behaves_like 'not a container repository factory'
            it_behaves_like 'logs an auth warning', %w[push pull]
          end
        end
      end
    end
  end

  context 'in maintenance mode' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:project) { create(:project) }

    let(:log_data) do
      {
        message: 'Write access denied in maintenance mode',
        write_access_denied_in_maintenance_mode: true
      }
    end

    before_all do
      project.add_developer(current_user)
    end

    before do
      stub_maintenance_mode_setting(true)
    end

    context 'allows developer to pull images' do
      let(:current_params) do
        { scopes: ["repository:#{project.full_path}:pull"] }
      end

      it_behaves_like 'a pullable'
    end

    context 'does not allow developer to push images' do
      let(:current_params) do
        { scopes: ["repository:#{project.full_path}:push"] }
      end

      it_behaves_like 'not a container repository factory'
      it_behaves_like 'logs an auth warning', ['push']
    end

    context 'does not allow developer to delete images' do
      let(:current_params) do
        { scopes: ["repository:#{project.full_path}:delete"] }
      end

      it_behaves_like 'not a container repository factory'
      it_behaves_like 'logs an auth warning', ['delete']
    end
  end

  context 'when not in maintenance mode' do
    it_behaves_like 'a container registry auth service'

    describe 'container repository factory auditing' do
      let_it_be(:project) { create(:project) }

      let(:current_params) do
        { scopes: ["repository:#{project.full_path}:push"] }
      end

      let(:operation) { subject }
      let(:event_type) { 'container_repository_created' }
      let(:repository) { project.container_repositories.last }
      let(:fail_condition!) do
        create(:container_repository, project: project, name: '')
      end

      let(:author) { current_user }

      let(:attributes) do
        {
          author_id: author.id,
          entity_id: project.id,
          entity_type: 'Project',
          details: {
            event_name: event_type,
            author_class: author.class.to_s,
            author_name: author.name,
            custom_message: "Container repository #{repository.path} created",
            target_details: repository.path,
            target_id: repository.id,
            target_type: repository.class.to_s
          }
        }
      end

      context 'with current user' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          project.add_developer(current_user)
        end

        include_examples 'audit event logging' do
          let(:author) { current_user }
        end
      end

      context 'with deploy token' do
        let_it_be(:user) { create(:user) }
        let(:deploy_token) do
          create(:deploy_token, projects: [project], read_registry: true, write_registry: true, user: user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"], deploy_token: deploy_token }
        end

        include_examples 'audit event logging' do
          let(:author) { deploy_token.user }
        end
      end

      context 'with anonymous deploy token' do
        let(:deploy_token) { create(:deploy_token, projects: [project], read_registry: true, write_registry: true) }

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"], deploy_token: deploy_token }
        end

        include_examples 'audit event logging' do
          let(:author) { ::Gitlab::Audit::DeployTokenAuthor.new }
        end
      end
    end
  end

  context 'when over storage limit' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    before do
      allow_next_found_instance_of(Project) do |instance|
        allow(instance).to receive(:root_ancestor).and_return namespace
      end

      allow(namespace).to receive(:over_storage_limit?).and_return true
    end

    context 'when there is a project' do
      let_it_be(:project) { create(:project, namespace: namespace) }

      before_all do
        project.add_developer(current_user)
      end

      shared_examples 'storage error' do
        it 'returns an appropriate response' do
          expect(subject[:errors].first).to include(
            code: 'DENIED',
            message: format(
              _("Your action has been rejected because the namespace storage limit has been reached. " \
              "For more information, " \
              "visit %{doc_url}."),
              doc_url: Rails.application.routes.url_helpers.help_page_url('user/storage_usage_quotas.md')
            )
          )
        end
      end

      context 'does not allow developer to push images' do
        context 'when only pushing an image' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push"] }
          end

          it_behaves_like 'not a container repository factory' do
            it_behaves_like 'storage error'
          end
        end

        context 'when performing multiple actions including push' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push,pull"] }
          end

          it_behaves_like 'not a container repository factory' do
            it_behaves_like 'storage error'
          end
        end
      end

      context 'allows developers to pull images' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull"] }
        end

        it_behaves_like 'a pullable'
      end

      context 'allows maintainers to delete images' do
        before_all do
          project.add_maintainer(current_user)
        end

        it_behaves_like 'allowed to delete container repository images'
      end
    end

    context 'when there is no project' do
      let(:project) { nil }

      it 'does not return a storage error' do
        expect(subject[:errors]).to be_nil
      end
    end
  end

  describe '.push_pull_nested_repositories_access_token' do
    let_it_be(:project) { create(:project) }

    let(:name) { project.full_path }
    let(:token) { described_class.push_pull_nested_repositories_access_token(name, project:) }

    let(:access) do
      [
        {
          'type' => 'repository',
          'name' => project.full_path,
          'actions' => %w[pull push],
          'meta' => { 'project_path' => project.full_path }.merge(push_delete_patterns_meta)
        },
        {
          'type' => 'repository',
          'name' => "#{project.full_path}/*",
          'actions' => %w[pull],
          'meta' => { 'project_path' => project.full_path }
        }
      ]
    end

    subject { { token: } }

    it_behaves_like 'returning tag name patterns when tag rules exist'
  end

  describe '.push_pull_move_repositories_access_token' do
    let_it_be(:project) { create(:project, :in_group) }

    let(:group_full_path) { project.group.full_path }
    let(:name) { project.full_path }
    let(:token) { described_class.push_pull_move_repositories_access_token(name, group_full_path, project:) }

    let(:access) do
      [
        {
          'type' => 'repository',
          'name' => project.full_path,
          'actions' => %w[pull push],
          'meta' => { 'project_path' => project.full_path }.merge(push_delete_patterns_meta)
        },
        {
          'type' => 'repository',
          'name' => "#{project.full_path}/*",
          'actions' => %w[pull],
          'meta' => { 'project_path' => project.full_path }
        },
        {
          'type' => 'repository',
          'name' => "#{group_full_path}/*",
          'actions' => %w[push],
          'meta' => { 'project_path' => group_full_path }.merge(push_delete_patterns_meta)
        }
      ]
    end

    subject { { token: } }

    it_behaves_like 'returning tag name patterns when tag rules exist'
  end

  describe '.tag_immutable_patterns' do
    let_it_be(:current_project) { create(:project) }
    let_it_be(:current_user) { create(:user, developer_of: current_project) }

    let(:container_repository_path) { current_project.full_path }
    let(:current_params) { { scopes: ["repository:#{container_repository_path}:push"] } }

    shared_examples 'not including tag_immutable_patterns' do
      it 'does not include tag_immutable_patterns' do
        is_expected.to include(:token)
        expect(payload['access']).not_to be_empty
        expect(payload['access'].first['meta']).not_to include('tag_immutable_patterns')
      end
    end

    shared_examples 'including tag_immutable_patterns' do
      it 'includes tag_immutable_patterns' do
        is_expected.to include(:token)
        expect(payload['access']).not_to be_empty

        expect(payload['access'].first['meta']).to include('tag_immutable_patterns')

        actual_patterns = payload['access'].first['meta']['tag_immutable_patterns']
        expect(actual_patterns).to match_array(%w[immutable1 immutable2])
      end
    end

    shared_examples 'returning an empty access field' do
      it 'returns an empty access field' do
        is_expected.to include(:token)
        expect(payload['access']).to be_empty
      end
    end

    context 'when there are no tag rules for immutability' do
      it_behaves_like 'not including tag_immutable_patterns'
    end

    context 'when there are tag rules for immutability' do
      using RSpec::Parameterized::TableSyntax

      before_all do
        create(:container_registry_protection_tag_rule,
          project: current_project,
          tag_name_pattern: 'not-included',
          minimum_access_level_for_push: ::Gitlab::Access::MAINTAINER,
          minimum_access_level_for_delete: ::Gitlab::Access::MAINTAINER
        )
        create(:container_registry_protection_tag_rule,
          :immutable,
          project: current_project,
          tag_name_pattern: 'immutable1'
        )
        create(:container_registry_protection_tag_rule,
          :immutable,
          project: current_project,
          tag_name_pattern: 'immutable2'
        )
      end

      context 'when the feature is not licensed' do
        let(:current_params) { { scopes: ["repository:#{container_repository_path}:push"] } }

        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it_behaves_like 'not including tag_immutable_patterns'
      end

      context 'when the actions do not include push, delete, or *' do
        let(:current_params) { { scopes: ["repository:#{container_repository_path}:pull"] } }

        it_behaves_like 'not including tag_immutable_patterns'
      end

      # rubocop:disable Layout/LineLength -- Avoid formatting to keep one-line table layout
      where(:user_role, :requested_scopes, :shared_example_name) do
        :developer  | lazy { ["repository:#{container_repository_path}:pull"] }             | 'not including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:push"] }             | 'including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:delete"] }           | 'returning an empty access field' # developers can't obtain delete access
        :developer  | lazy { ["repository:#{container_repository_path}:pull,push"] }        | 'including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:pull,delete"] }      | 'not including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:push,delete"] }      | 'including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:pull,push,delete"] } | 'including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:*"] }                | 'returning an empty access field' # developers can't obtain full access
        :developer  | lazy { ["repository:#{container_repository_path}:push,push"] }        | 'including tag_immutable_patterns'
        :developer  | lazy { ["repository:#{container_repository_path}:push,foo"] }         | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:pull"] }             | 'not including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:push"] }             | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:delete"] }           | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:pull,push"] }        | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:pull,delete"] }      | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:push,delete"] }      | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:pull,push,delete"] } | 'including tag_immutable_patterns'
        :maintainer | lazy { ["repository:#{container_repository_path}:*"] }                | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:pull"] }             | 'not including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:push"] }             | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:delete"] }           | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:pull,push"] }        | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:pull,delete"] }      | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:push,delete"] }      | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:pull,push,delete"] } | 'including tag_immutable_patterns'
        :owner      | lazy { ["repository:#{container_repository_path}:*"] }                | 'including tag_immutable_patterns'
      end
      # rubocop:enable Layout/LineLength

      with_them do
        let(:current_params) { { scopes: requested_scopes } }

        before do
          current_project.send(:"add_#{user_role}", current_user)
          stub_licensed_features(container_registry_immutable_tag_rules: true)
        end

        it_behaves_like params[:shared_example_name]
      end

      context 'when user is admin', :enable_admin_mode do
        let(:current_user) { build_stubbed(:admin) }

        where(:requested_scopes, :shared_example_name) do
          lazy { ["repository:#{container_repository_path}:push"] }             | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:delete"] }           | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:pull,push"] }        | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:pull,delete"] }      | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:push,delete"] }      | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:pull,push,delete"] } | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:*"] }                | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:push,push"] }        | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:push,foo"] }         | 'including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:pull"] }             | 'not including tag_immutable_patterns'
          lazy { ["repository:#{container_repository_path}:pull,foo"] }         | 'not including tag_immutable_patterns'
        end

        with_them do
          let(:current_params) { { scopes: requested_scopes } }

          before do
            stub_licensed_features(container_registry_immutable_tag_rules: true)
          end

          it_behaves_like params[:shared_example_name]
        end
      end
    end
  end
end
