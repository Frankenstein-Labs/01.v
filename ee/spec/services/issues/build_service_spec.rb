# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::BuildService, feature_category: :team_planning do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:guest) { create(:user, guest_of: project) }

  let(:user) { developer }

  def build_issue(issue_params = {})
    described_class.new(container: project, current_user: user, params: issue_params).execute
  end

  context 'with an issue template' do
    describe '#execute' do
      let(:project) { build(:project, issues_template: 'Work hard, play hard!') }

      it 'fills in the template in the description' do
        issue = build_issue

        expect(issue.description).to eq('Work hard, play hard!')
      end

      it 'fills in the template, followed by the query parameter, in the description' do
        issue = build_issue(description: 'Travailler dur, jouer dur!')

        expect(issue.description).to eq("Work hard, play hard!\nTravailler dur, jouer dur!")
      end

      context 'when passed description in the params is nil' do
        it 'fills in the template, followed by the query parameter, in the description' do
          issue = build_issue(description: nil)

          expect(issue.description).to eq("Work hard, play hard!\n")
        end
      end
    end
  end

  context 'for a single thread' do
    describe '#execute' do
      let(:merge_request) { create(:merge_request, title: "Hello world", source_project: project) }
      let(:discussion) do
        create(:diff_note_on_merge_request, project: project, noteable: merge_request,
          note: "Almost done").to_discussion
      end

      context 'with an issue template' do
        let_it_be(:project) do
          create(:project, :repository, issues_template: 'Work hard, play hard!', developers: developer)
        end

        it 'picks the thread description over the issue template' do
          issue = build_issue(
            merge_request_to_resolve_discussions_of: merge_request.iid,
            discussion_to_resolve: discussion.id
          )

          expect(issue.description).to include('Almost done')
        end
      end
    end
  end

  describe '#execute' do
    before do
      stub_licensed_features(quality_management: true, requirements: true)
    end

    context 'as developer' do
      # ticket requires service_desk_enabled, tested separately below
      (::WorkItems::TypesFramework::Provider.unfiltered_base_types_for_issues - ['ticket']).each do |issue_type|
        it "sets the issue type to #{issue_type}" do
          issue = build_issue(issue_type: issue_type)

          expect(issue.issue_type).to eq(issue_type)
        end
      end

      context 'with service desk enabled' do
        before do
          allow(::ServiceDesk).to receive(:enabled?).with(project).and_return(true)
        end

        it 'sets the issue type to ticket' do
          issue = build_issue(issue_type: 'ticket')

          expect(issue.issue_type).to eq('ticket')
        end
      end
    end

    context 'as guest' do
      let(:user) { guest }

      context 'setting issue type' do
        [:test_case, :requirement].each do |issue_type|
          it "cannot set the issue type to #{issue_type}" do
            issue = build_issue(issue_type: issue_type)

            expect(issue.issue_type).to eq('issue')
          end
        end
      end
    end

    context 'with custom work item types' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project_in_group) { create(:project, group: group) }
      let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }

      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      before_all do
        project_in_group.add_developer(developer)
      end

      def build_issue_in_group(issue_params = {})
        described_class.new(container: project_in_group, current_user: user, params: issue_params).execute
      end

      context 'with a non-converted custom type' do
        before do
          stub_licensed_features(configurable_work_item_types: true)
        end

        it 'assigns the custom type directly' do
          issue = build_issue_in_group(work_item_type: custom_type)

          expect(issue.work_item_type).to eq(custom_type)
          expect(issue.work_item_type_id).to eq(custom_type.id)
        end
      end

      context 'with a converted custom type' do
        let_it_be(:converted_type) { create(:work_item_custom_type, :converted_from_incident, namespace: group) }

        before do
          stub_licensed_features(configurable_work_item_types: true)
        end

        it 'assigns the converted type and persists the system-defined type ID' do
          issue = build_issue_in_group(work_item_type: converted_type)

          expect(issue.work_item_type).to eq(converted_type)
          expect(issue.work_item_type_id).to eq(converted_type.converted_from_system_defined_type_identifier)
        end
      end

      context 'when creating in a group' do
        before do
          stub_licensed_features(configurable_work_item_types: true)
        end

        it 'adds an error and falls back to default issue type' do
          issue = described_class.new(container: group, current_user: user,
            params: { work_item_type: custom_type }).execute

          expect(issue.errors[:work_item_type]).to include('custom types can only be created in projects')
          expect(issue.work_item_type).to eq(::WorkItems::TypesFramework::Provider.new.default_issue_type)
        end
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(configurable_work_item_types: false)
        end

        it 'adds an error and falls back to default issue type' do
          issue = build_issue_in_group(work_item_type: custom_type)

          expect(issue.errors[:base]).to include('Configurable work item types are not available')
          expect(issue.work_item_type).to eq(::WorkItems::TypesFramework::Provider.new.default_issue_type)
        end
      end

      context 'when custom type is from a different namespace' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:other_custom_type) { create(:work_item_custom_type, namespace: other_group) }

        before do
          stub_licensed_features(configurable_work_item_types: true)
        end

        it 'adds an error when the type cannot be resolved from a different namespace' do
          issue = build_issue_in_group(work_item_type_id: other_custom_type.id)

          expect(issue.work_item_type).to eq(::WorkItems::TypesFramework::Provider.new.default_issue_type)
          expect(issue.errors[:work_item_type]).to include(
            s_('WorkItem|could not be found or is not accessible.')
          )
        end
      end
    end
  end
end
