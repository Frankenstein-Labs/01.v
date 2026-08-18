# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SnippetRepository, type: :model, feature_category: :source_code_management do
  describe '.search' do
    let_it_be_with_reload(:snippet_repository1) { create(:snippet_repository) }
    let_it_be(:snippet_repository2) { create(:snippet_repository) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(snippet_repository1, snippet_repository2)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all records' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        where(:searchable_attribute) { described_class::EE_SEARCHABLE_ATTRIBUTES }

        before do
          # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
          snippet_repository1.update_column(searchable_attribute, 'any_keyword')
        end

        with_them do
          it do
            result = described_class.search('any_keyword')

            expect(result).to contain_exactly(snippet_repository1)
          end
        end
      end
    end
  end

  describe 'Geo', feature_category: :geo_replication do
    describe 'associations' do
      it do
        is_expected
            .to have_one(:snippet_repository_state)
            .class_name('Geo::SnippetRepositoryState')
            .with_foreign_key(:snippet_repository_id)
            .inverse_of(:snippet_repository)
            .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let_it_be(:project) { create(:project, group: create(:group)) }
      let_it_be(:project_snippet) { create(:project_snippet, project: project) }

      let(:verifiable_model_record) do
        build(:snippet_repository, snippet: project_snippet)
      end

      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, :broken_storage, group: group_2) }

      let_it_be(:project_snippet_1) { create(:project_snippet, project: project_1) }
      let_it_be(:project_snippet_2) { create(:project_snippet, project: project_2) }
      let_it_be(:project_snippet_3) { create(:project_snippet, project: project_3) }

      # Snippet repository for the root group
      let_it_be(:first_replicable_and_in_selective_sync) { create(:snippet_repository, snippet: project_snippet_1) }

      # Snippet repository for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) { create(:snippet_repository, snippet: project_snippet_2) }

      # Snippet repository in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:snippet_repository, snippet: project_snippet_3, shard_name: 'broken')
      end

      include_examples 'Geo Framework selective sync behavior' do
        context 'with personal snippets' do
          # Personal snippets for the seleted organization
          let_it_be(:first_personal_snippet_in_org) { create(:personal_snippet, organization: group_1.organization) }
          let_it_be(:second_personal_snippet_in_org) { create(:personal_snippet, organization: group_1.organization) }

          # Personal snippets for the other organization
          let_it_be(:personal_snippet_other_org) { create(:personal_snippet, organization: group_2.organization) }

          # Project snippets for the selected organization
          let_it_be(:first_project_snippet) { create(:project_snippet, project: project_1) }
          let_it_be(:second_project_snippet) { create(:project_snippet, project: project_1) }

          # Project snippets for the other organization
          let_it_be(:project_snippet_other_org) { create(:project_snippet, project: project_3) }

          # Personal snippet repositories for the selected organization
          let_it_be(:first_personal_snippet_repository_in_org) do
            create(:snippet_repository, snippet: first_personal_snippet_in_org)
          end

          let_it_be(:second_personal_snippet_repository_in_org) do
            create(:snippet_repository, snippet: second_personal_snippet_in_org)
          end

          # Personal snippet repositories for the other organization
          let_it_be(:personal_snippet_repository_other_org) do
            create(:snippet_repository, snippet: personal_snippet_other_org, shard_name: 'broken')
          end

          # Project snippet repositories for the selected organization
          let_it_be(:first_project_snippet_repository_in_org) do
            create(:snippet_repository, snippet: first_project_snippet)
          end

          let_it_be(:second_project_snippet_repository_in_org) do
            create(:snippet_repository, snippet: second_project_snippet)
          end

          # Project snippet repositories for the other organization
          let_it_be(:project_snippet_repository_other_org) do
            create(:snippet_repository, snippet: project_snippet_other_org, shard_name: 'broken')
          end

          shared_examples 'selective sync scope tests with personal snippets' do |sync_type, setup_block|
            before do
              instance_exec(&setup_block)
            end

            it "returns snippet repositories that belong to the #{sync_type}" do
              skip_if_requires_primary_key_range

              replicables = find_snippet_repositories_to_sync

              expect(replicables).to include(first_personal_snippet_repository_in_org.id)
              expect(replicables).to include(second_personal_snippet_repository_in_org.id)
              expect(replicables).to include(first_project_snippet_repository_in_org.id)
              expect(replicables).to include(second_project_snippet_repository_in_org.id)
              expect(replicables).not_to include(project_snippet_repository_other_org.id)

              if sync_type == :namespaces
                expect(replicables).to include(personal_snippet_repository_other_org.id)
              else
                expect(replicables).not_to include(personal_snippet_repository_other_org.id)
              end
            end

            it "returns snippet repositories inside the primary key range that belong to the #{sync_type}" do
              primary_key_in = (first_personal_snippet_repository_in_org.id + 1)..end_id

              replicables = find_snippet_repositories_to_sync(primary_key_in)

              expect(replicables).not_to include(first_personal_snippet_repository_in_org.id)
              expect(replicables).to include(second_personal_snippet_repository_in_org.id)
              expect(replicables).to include(first_project_snippet_repository_in_org.id)
              expect(replicables).to include(second_project_snippet_repository_in_org.id)
              expect(replicables).not_to include(project_snippet_repository_other_org.id)

              if sync_type == :namespaces
                expect(replicables).to include(personal_snippet_repository_other_org.id)
              else
                expect(replicables).not_to include(personal_snippet_repository_other_org.id)
              end
            end
          end

          shared_examples 'selective sync scopes with personal snippets' do |method_name|
            let(:method_name) { method_name }

            context 'with selective sync by namespace' do
              include_examples 'selective sync scope tests with personal snippets', :namespaces, -> {
                secondary.update!(selective_sync_type: 'namespaces', namespaces: [group_1])
              }
            end

            context 'with selective sync by organizations' do
              include_examples 'selective sync scope tests with personal snippets', :organizations, -> {
                secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])
              }
            end

            context 'with selective sync by shard' do
              include_examples 'selective sync scope tests with personal snippets', :shards, -> {
                secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['default'])
              }
            end

            context 'with selective sync disabled' do
              it 'returns all snippet repositories' do
                skip_if_requires_primary_key_range

                replicables = find_snippet_repositories_to_sync

                expect(replicables).to include(first_personal_snippet_repository_in_org.id)
                expect(replicables).to include(second_personal_snippet_repository_in_org.id)
                expect(replicables).to include(personal_snippet_repository_other_org.id)
                expect(replicables).to include(first_project_snippet_repository_in_org.id)
                expect(replicables).to include(second_project_snippet_repository_in_org.id)
                expect(replicables).to include(project_snippet_repository_other_org.id)
              end

              it 'returns all snippet repositories inside the primary key range' do
                primary_key_in = (first_personal_snippet_repository_in_org.id + 1)..end_id

                replicables = find_snippet_repositories_to_sync(primary_key_in)

                expect(replicables).not_to include(first_personal_snippet_repository_in_org.id)
                expect(replicables).to include(second_personal_snippet_repository_in_org.id)
                expect(replicables).to include(personal_snippet_repository_other_org.id)
                expect(replicables).to include(first_project_snippet_repository_in_org.id)
                expect(replicables).to include(second_project_snippet_repository_in_org.id)
                expect(replicables).to include(project_snippet_repository_other_org.id)
              end
            end
          end

          describe '.replicables_for_current_secondary' do
            include_examples 'selective sync scopes with personal snippets', :replicables_for_current_secondary
          end

          describe '.selective_sync_scope' do
            include_examples 'selective sync scopes with personal snippets', :selective_sync_scope
          end

          describe '.verifiables' do
            include_examples 'selective sync scopes with personal snippets', :verifiables
          end

          describe '.pluck_verifiable_ids_in_range' do
            include_examples 'selective sync scopes with personal snippets', :pluck_verifiable_ids_in_range
          end
        end

        private

        def find_snippet_repositories_to_sync(primary_key_in = nil)
          replicables =
            if method_name != :selective_sync_scope
              described_class.public_send(method_name, primary_key_in)
            else
              described_class.public_send(method_name, secondary, primary_key_in: primary_key_in)
            end

          method_name != :pluck_verifiable_ids_in_range ? replicables.map(&:id) : replicables
        end
      end
    end
  end
end
