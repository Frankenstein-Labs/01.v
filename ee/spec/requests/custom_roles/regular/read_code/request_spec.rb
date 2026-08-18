# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_code custom role', :with_current_organization, feature_category: :permissions do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :small_repo, :private, :in_group) }

  let_it_be(:role) { create(:member_role, :guest, :read_code, namespace: project.group) }
  let_it_be(:member) do
    create(:group_member, :guest, member_role: role, user: user, source: project.group)
  end

  let(:current_user) { user }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(current_user)
  end

  describe SearchController do
    describe '#show' do
      context 'with elasticsearch', :elastic, :sidekiq_inline do
        before do
          stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_search: true)
          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!
        end

        context 'when searching a group' do
          it 'allows access via a custom role' do
            get search_path, params: { group_id: project.group.id, scope: 'blobs', search: 'test' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to include('test.txt#L1')
          end

          context 'when saas', :saas do
            let_it_be(:subscription) do
              create(:gitlab_subscription, namespace: project.group, hosted_plan: create(:ultimate_plan))
            end

            before do
              stub_ee_application_setting(
                elasticsearch_indexing: true,
                elasticsearch_search: true,
                should_check_namespace_plan: true
              )
            end

            it 'avoids N+1 queries' do
              get search_path, params: { group_id: project.group.id, scope: 'blobs', search: 'test' } # warmup

              expect(response.body).to include('test.txt#L1')

              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                get search_path, params: { group_id: project.group.id, scope: 'blobs', search: 'test' }

                expect(response.body).to include('test.txt#L1')
              end

              create(:project, :private, :repository, group: create(:group, parent: project.group))

              expect do
                get search_path, params: { group_id: project.group.id, scope: 'blobs', search: 'test' }

                expect(response.body).to include('test.txt#L1')
              end.to issue_same_number_of_queries_as(control).or_fewer
            end
          end
        end

        context 'when searching a project' do
          it 'allows access via a custom role' do
            get search_path, params: { project_id: project.id, search_code: true, scope: 'blobs', search: 'test' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to include('test.txt#L1')
          end
        end
      end
    end
  end

  describe Projects::TreeController do
    describe '#show' do
      subject(:get_project_tree) { get project_tree_path(project) }

      it 'user has access via a custom role' do
        get_project_tree

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end
  end
end
