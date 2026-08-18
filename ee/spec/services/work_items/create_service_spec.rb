# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::CreateService, feature_category: :team_planning do
  let_it_be(:description_template_name) { 'default' }
  let_it_be(:template_content) { "some content" }
  let_it_be(:template_project) do
    template_files = {
      ".gitlab/issue_templates/#{description_template_name}.md" => template_content
    }
    create(:project, :custom_repo, files: template_files)
  end

  RSpec.shared_examples 'creates work item in container' do |container_type|
    include_context 'with container for work items service', container_type

    describe '#execute' do
      subject(:service_result) { service.execute }

      before do
        stub_licensed_features(epics: true, subepics: true, epic_colors: true, custom_file_templates: true,
          work_item_status: true)
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      context 'when user is not allowed to create a work item in the container' do
        let(:current_user) { user_with_no_access }

        it { is_expected.to be_error }

        it 'returns an access error' do
          expect(service_result.errors).to contain_exactly('Operation not allowed')
        end
      end

      context 'when params are valid' do
        let(:type) { build(:work_item_system_defined_type, :task) }
        let(:opts) { { title: 'Awesome work_item', description: 'please fix', work_item_type: type } }

        it 'created instance is a WorkItem' do
          expect(Issuable::CommonSystemNotesService).to receive_message_chain(:new, :execute)

          work_item = service_result[:work_item]

          expect(work_item).to be_persisted
          expect(work_item).to be_a(::WorkItem)
          expect(work_item.title).to eq('Awesome work_item')
          expect(work_item.description).to eq('please fix')
          expect(work_item.work_item_type.base_type).to eq('task')
        end

        context 'when template is set on the instance level' do
          let(:opts) { { title: 'Awesome work_item', description: description, work_item_type: type } }
          let(:application_settings) { ::Gitlab::CurrentSettings.current_application_settings }

          before do
            application_settings.update!(file_template_project_id: template_project.id)
          end

          context 'when description is blank' do
            let(:description) { '' }

            it 'creates a work item with the template content' do
              work_item = service_result[:work_item]

              expect(work_item).to be_persisted
              expect(work_item).to be_a(::WorkItem)
              expect(work_item.description).to eq(template_content)
            end
          end

          context 'when description is not blank' do
            let(:description) { 'another content' }

            it 'creates a work item with the template content' do
              work_item = service_result[:work_item]

              expect(work_item).to be_persisted
              expect(work_item).to be_a(::WorkItem)
              expect(work_item.description).to eq(description)
            end
          end
        end

        it 'calls NewIssueWorker with correct arguments' do
          expect(NewIssueWorker).to receive(:perform_async)
                                      .with(Integer, current_user.id, 'WorkItem')

          service_result
        end

        describe 'with color widget params' do
          let(:widget_params) { { color_widget: { color: '#c91c00' } } }

          before do
            skip 'these examples only apply to a group container' unless container.is_a?(Group)
          end

          context 'when user can admin_work_item' do
            let(:current_user) { reporter }

            context 'when type does not support color widget' do
              it 'creates new work item without setting color' do
                expect { service_result }.to change { WorkItem.count }.by(1).and(
                  not_change { WorkItems::Color.count }
                )
                expect(service_result[:work_item].color).to be_nil
                expect(service_result[:status]).to be(:success)
              end
            end

            context 'when type supports color widget' do
              let(:type) { build(:work_item_system_defined_type, :epic) }

              it 'creates new work item and sets color' do
                expect { service_result }.to change { WorkItem.count }.by(1).and(
                  change { WorkItems::Color.count }.by(1)
                )
                expect(service_result[:work_item].color.color.to_s).to eq('#c91c00')
                expect(service_result[:status]).to be(:success)
              end
            end
          end
        end

        describe 'with custom work item types' do
          let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }
          let_it_be(:converted_type) { create(:work_item_custom_type, :converted_from_task, namespace: group) }

          before do
            skip 'custom types can only be created in projects' if container.is_a?(Group)

            stub_licensed_features(
              epics: true, subepics: true, epic_colors: true, custom_file_templates: true,
              work_item_status: true, configurable_work_item_types: true
            )
          end

          context 'with a non-converted custom type' do
            let(:opts) { { title: 'Custom typed item', work_item_type: custom_type } }

            it 'creates a work item with the custom type' do
              expect { service_result }.to change { WorkItem.count }.by(1)

              work_item = service_result[:work_item]
              expect(work_item).to be_persisted
              expect(work_item.work_item_type).to eq(custom_type)
            end
          end

          context 'with a converted custom type' do
            let(:opts) { { title: 'Converted typed item', work_item_type: converted_type } }

            it 'creates a work item and persists the system-defined type ID' do
              expect { service_result }.to change { WorkItem.count }.by(1)

              work_item = service_result[:work_item]
              expect(work_item).to be_persisted
              expect(work_item).to have_attributes(
                work_item_type: converted_type,
                work_item_type_id: converted_type.converted_from_system_defined_type_identifier
              )
            end
          end
        end

        describe 'for custom statuses widget' do
          let(:status) { build(:work_item_system_defined_status, :to_do) }

          context "with status widget params" do
            let(:widget_params) { { status_widget: { status: status } } }

            it 'creates new work item and sets current status' do
              expect { service_result }.to change { WorkItem.count }.by(1).and(
                change { WorkItems::Statuses::CurrentStatus.count }.by(1)
              )
              expect(service_result[:status]).to be(:success)
            end

            context "when state and status params are both present" do
              before do
                opts[:state_event] = "close"
              end

              it 'returns an error' do
                expect { service_result }.not_to change { WorkItems::Statuses::CurrentStatus.count }
                expect(service_result[:status]).to eq(:error)
                expect(service_result[:message])
                  .to eq('State event and status widget cannot be changed at the same time')
              end
            end
          end

          context "without status widget params" do
            let(:widget_params) { {} }

            it 'creates new work item and sets current status' do
              expect { service_result }.to change { WorkItem.count }.by(1).and(
                change { WorkItems::Statuses::CurrentStatus.count }.by(1)
              )
              expect(service_result[:status]).to be(:success)
            end
          end
        end
      end

      context 'when applying quick actions' do
        let(:current_user) { reporter }
        let(:work_item) { service_result[:work_item] }
        let(:feature_hash) { { issue_weights: true } }

        context 'with /weight action' do
          let(:opts) do
            {
              title: 'My work item',
              work_item_type: work_item_type,
              description: '/weight 2'
            }
          end

          before do
            stub_licensed_features(**feature_hash)
          end

          context 'when work item type does not support weight' do
            context 'with Incident type' do
              let(:work_item_type) { build(:work_item_system_defined_type, :incident) }

              before do
                skip "these examples don't apply to a group container" if container.is_a?(Group)
              end

              it 'saves the work item without applying the quick action' do
                expect(service_result).to be_success
                expect(work_item).to be_persisted
                expect(work_item.weight).to be_nil
              end
            end
          end

          context 'when work item type supports weight' do
            let(:work_item_type) { build(:work_item_system_defined_type, :issue) }

            before do
              skip "these examples don't apply to a group container" if container.is_a?(Group)
            end

            it 'saves the work item and applies the quick action' do
              expect(service_result).to be_success
              expect(work_item).to be_persisted
              expect(work_item.weight).to eq(2)
            end
          end
        end

        context 'when /confidential is used' do
          let(:widget_params) { { description_widget: { description: '/confidential' } } }
          let(:opts) do
            {
              title: 'My work item',
              work_item_type: work_item_type
            }
          end

          before do
            skip 'these examples only apply to a group container' unless container.is_a?(Group)
          end

          context 'with Epic type' do
            let(:work_item_type) { build(:work_item_system_defined_type, :epic) }

            let(:feature_hash) { { issue_weights: true, epics: true } }

            it 'saves the work item and applies the quick action' do
              expect(service_result).to be_success
              expect(work_item).to be_confidential
              expect(work_item.synced_epic).to be_confidential
            end
          end
        end
      end
    end
  end

  it_behaves_like 'creates work item in container', :project
  it_behaves_like 'creates work item in container', :project_namespace
  # group level work items, and epics can be created by reporter vs guest at project level
  it_behaves_like 'creates work item in container', :group do
    let(:current_user) { reporter }
  end

  context 'for legacy epics' do
    include_context 'with container for work items service', :group

    let_it_be(:parent, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be(:other_child_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be(:other_child_issue) { create(:work_item, namespace: group) }
    let_it_be(:parent_link_epic) do
      create(:parent_link, work_item_parent: parent, work_item: other_child_epic, relative_position: 500)
    end

    let_it_be(:parent_link_issue) do
      create(:parent_link, :with_epic_issue, work_item_parent: parent, work_item: other_child_issue,
        relative_position: 600)
    end

    let(:epic) { Epic.last }
    let(:type) { build(:work_item_system_defined_type, :epic) }

    let(:start_date) { (Time.current + 1.day).to_date }
    let(:due_date) { (Time.current + 2.days).to_date }

    let(:widget_params) do
      {
        description_widget: {
          description: 'new description'
        },
        color_widget: {
          color: '#FF0000'
        },
        start_and_due_date_widget: { start_date: start_date, due_date: due_date },
        hierarchy_widget: { parent: parent }
      }
    end

    let(:opts) do
      { title: 'new title', confidential: true, work_item_type: type }
    end

    let(:current_user) { reporter }

    before do
      stub_licensed_features(epics: true, subepics: true, epic_colors: true)
    end

    subject(:service_result) { service.execute }

    it_behaves_like 'syncs all data from a work_item to an epic'

    context 'when creating the epic with only title and description' do
      let(:widget_params) do
        {
          description_widget: {
            description: 'new description'
          }
        }
      end

      it_behaves_like 'syncs all data from a work_item to an epic'
    end

    context 'when creating an epic work item' do
      it 'creates the epic with correct relative_position' do
        work_item = service_result.payload[:work_item]

        expect(work_item.reload.parent_link.relative_position).to eq(work_item.synced_epic.relative_position)
      end
    end

    context 'when creating an issue with a synced epic as parent' do
      let(:type) { build(:work_item_system_defined_type, :issue) }

      it 'creates the work item and the EpicIssue with the correct relative_position' do
        expect { service_result }
          .to change { EpicIssue.count }.by(1)
          .and change { WorkItems::ParentLink.count }.by(1)

        work_item = service_result.payload[:work_item]

        expect(work_item.parent_link.relative_position).to eq(work_item.epic_issue.relative_position)
      end
    end

    context 'when not creating an epic work item' do
      let(:type) { build(:work_item_system_defined_type, :task) }

      let_it_be(:parent) { nil }

      it 'only creates a work item' do
        expect { service_result }
          .to not_change { Epic.count }
          .and change { WorkItem.count }
      end
    end

    context 'when creating the epic fails' do
      it 'does not create an epic or work item' do
        allow(Epic).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)

        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
          .with({
            message: "Not able to create epic",
            error_message: "Record invalid",
            group_id: group.id,
            work_item_id: an_instance_of(Integer)
          })

        expect { service_result }
          .to not_change { WorkItem.count }
          .and not_change { Epic.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when changes are invalid' do
      let(:widget_params) { {} }
      let(:opts) { { title: '' } }

      it 'does not create an epic or work item' do
        expect { service_result }
          .to not_change { WorkItem.count }
          .and not_change { Epic.count }
      end
    end
  end
end
