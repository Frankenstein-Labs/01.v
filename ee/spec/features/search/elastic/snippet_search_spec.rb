# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Snippet elastic search', :js, :elastic_delete_by_query, :aggregate_failures, :with_current_organization, feature_category: :global_search do
  let_it_be(:public_project) { create(:project, :public) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:admin_user) { create(:admin) }
  let_it_be(:authorized_project) do
    create(:project, namespace: authorized_user.namespace, maintainers: authorized_user)
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_ee_application_setting(global_search_limited_indexing_enabled: true)
    create_snippets

    sign_in(current_user) if current_user
    visit explore_snippets_path
  end

  # TODO: Reenable support for public/internal project snippets
  # https://gitlab.com/gitlab-org/gitlab/issues/35760

  shared_examples 'expected snippet search results' do
    context 'as anonymous user' do
      let(:current_user) { nil }

      context 'when global_search_block_anonymous_searches_enabled is enabled' do
        before do
          stub_application_setting(global_search_block_anonymous_searches_enabled: true)
        end

        it 'redirects to login page' do
          visit(page)
          expect(page).to have_current_path("/users/sign_in")
        end
      end

      context 'when global_search_block_anonymous_searches_enabled is disabled' do
        before do
          stub_application_setting(global_search_block_anonymous_searches_enabled: false)
        end

        it 'finds only public snippets' do
          within('.results') do
            expect(page).to have_content('public personal snippet')
            expect(page).not_to have_content('public project snippet')

            expect(page).not_to have_content('internal personal snippet')
            expect(page).not_to have_content('internal project snippet')

            expect(page).not_to have_content('authorized personal snippet')
            expect(page).not_to have_content('authorized project snippet')

            expect(page).not_to have_content('private personal snippet')
            expect(page).not_to have_content('private project snippet')
          end
        end
      end
    end

    context 'as logged in user' do
      let(:current_user) { regular_user }

      it 'finds only public and internal snippets' do
        within('.results') do
          expect(page).to have_content('public personal snippet')
          expect(page).not_to have_content('public project snippet')

          expect(page).to have_content('internal personal snippet')
          expect(page).not_to have_content('internal project snippet')

          expect(page).not_to have_content('private personal snippet')
          expect(page).not_to have_content('private project snippet')

          expect(page).not_to have_content('authorized personal snippet')
          expect(page).not_to have_content('authorized project snippet')
        end
      end
    end

    context 'as authorized user' do
      let(:current_user) { authorized_user }

      it 'finds only public, internal, and authorized private snippets' do
        within('.results') do
          expect(page).to have_content('public personal snippet')
          expect(page).not_to have_content('public project snippet')

          expect(page).to have_content('internal personal snippet')
          expect(page).not_to have_content('internal project snippet')

          expect(page).not_to have_content('private personal snippet')
          expect(page).not_to have_content('private project snippet')

          expect(page).to have_content('authorized personal snippet')
          expect(page).to have_content('authorized project snippet')
        end
      end
    end

    context 'as administrator' do
      let(:current_user) { admin_user }

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'finds all snippets' do
          within('.results') do
            expect(page).to have_content('public personal snippet')
            expect(page).to have_content('public project snippet')

            expect(page).to have_content('internal personal snippet')
            expect(page).to have_content('internal project snippet')

            expect(page).to have_content('private personal snippet')
            expect(page).to have_content('private project snippet')

            expect(page).to have_content('authorized personal snippet')
            expect(page).to have_content('authorized project snippet')
          end
        end
      end

      context 'when admin mode is disabled' do
        it 'finds only public and internal snippets' do
          within('.results') do
            expect(page).to have_content('public personal snippet')
            expect(page).not_to have_content('public project snippet')

            expect(page).to have_content('internal personal snippet')
            expect(page).not_to have_content('internal project snippet')

            expect(page).not_to have_content('private personal snippet')
            expect(page).not_to have_content('private project snippet')

            expect(page).not_to have_content('authorized personal snippet')
            expect(page).not_to have_content('authorized project snippet')
          end
        end
      end
    end
  end

  context 'when header search' do
    context 'when searching titles' do
      before do
        submit_search('snippet')
      end

      it_behaves_like 'expected snippet search results'
    end

    context 'when searching descriptions' do
      before do
        submit_search('snippet description')
      end

      it_behaves_like 'expected snippet search results'
    end
  end

  private

  def create_snippets
    Sidekiq::Testing.inline! do
      create(:personal_snippet, :public, title: 'public personal snippet',
        description: 'a public personal snippet description')
      create(:project_snippet, :public, title: 'public project snippet',
        description: 'a public project snippet description', project: public_project)

      create(:personal_snippet, :internal, title: 'internal personal snippet',
        description: 'a internal personal snippet description')
      create(:project_snippet, :internal, title: 'internal project snippet',
        description: 'a internal project snippet description', project: public_project)

      create(:personal_snippet, :private, title: 'private personal snippet',
        description: 'a private personal snippet description')
      create(:project_snippet, :private, title: 'private project snippet',
        description: 'a private project snippet description', project: public_project)

      create(:personal_snippet, :private, title: 'authorized personal snippet',
        description: 'an authorized personal snippet description', author: authorized_user)
      create(:project_snippet, :private, title: 'authorized project snippet',
        description: 'an authorized project snippet description', project: authorized_project)

      ensure_elasticsearch_index!
    end
  end
end
