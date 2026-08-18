#  frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::UpdateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { WorkItems::Statuses::SystemDefined::Lifecycle.all.first }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:params) do
    {
      id: system_defined_lifecycle.to_gid,
      statuses: [
        status_params_for(system_defined_lifecycle.default_open_status),
        status_params_for(system_defined_in_progress_status),
        status_params_for(system_defined_lifecycle.default_closed_status),
        status_params_for(system_defined_wont_do_status),
        status_params_for(system_defined_lifecycle.default_duplicate_status)
      ],
      default_open_status_index: 0,
      default_closed_status_index: 2,
      default_duplicate_status_index: 4
    }
  end

  let(:lifecycle_name) { 'Default' }

  subject(:result) do
    described_class.new(container: group, current_user: user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true, board_status_lists: true)
  end

  RSpec.shared_examples 'accepts lifecycle attributes' do
    let(:lifecycle_name) { 'Changed lifecycle name' }
    let(:params) do
      super().merge(name: lifecycle_name)
    end

    it 'assigns attributes to lifecycle' do
      expect(result).not_to be_error
      expect(lifecycle.name).to eq(lifecycle_name)
    end

    context 'when name is invalid' do
      let(:expected_error_message) { "Validation failed: Name can't be blank" }
      let(:params) do
        super().merge(name: '')
      end

      it_behaves_like 'lifecycle service returns validation error'
    end
  end

  RSpec.shared_examples 'sets default statuses correctly' do
    it 'sets default statuses correctly' do
      expect(lifecycle.default_open_status.name).to eq(system_defined_lifecycle.default_open_status.name)
      expect(lifecycle.default_closed_status.name).to eq(system_defined_lifecycle.default_closed_status.name)
      expect(lifecycle.default_duplicate_status.name).to eq(system_defined_lifecycle.default_duplicate_status.name)
    end
  end

  RSpec.shared_examples 'removes custom statuses' do
    it 'removes custom statuses' do
      expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(-1)
      expect(lifecycle.statuses.pluck(:name)).not_to include(custom_status.name)
      expect(lifecycle.statuses.count).to eq(3)
    end
  end

  RSpec.shared_examples 'reorders custom statuses' do
    it 'reorders custom statuses' do
      expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
        custom_lifecycle.default_open_status.name,
        custom_lifecycle.default_closed_status.name,
        custom_lifecycle.default_duplicate_status.name
      ])
    end
  end

  RSpec.shared_examples 'tracks lifecycle update event' do
    it 'tracks lifecycle update event', :clean_gitlab_redis_shared_state do
      expect { result }
        .to trigger_internal_events('update_custom_lifecycle')
        .with(user: user, namespace: group)
        .and increment_usage_metrics(
          'redis_hll_counters.count_distinct_namespace_id_from_update_custom_lifecycle_monthly',
          'redis_hll_counters.count_distinct_namespace_id_from_update_custom_lifecycle_weekly',
          'counts.count_total_update_custom_lifecycle_monthly',
          'counts.count_total_update_custom_lifecycle_weekly',
          'counts.count_total_update_custom_lifecycle'
        )
    end
  end

  describe '#execute' do
    let(:lifecycle) { result.payload[:lifecycle] }

    context 'when custom lifecycle does not exist' do
      it_behaves_like 'lifecycle service creates custom lifecycle'
      it_behaves_like 'accepts lifecycle attributes'
      it_behaves_like 'sets default statuses correctly'
      it_behaves_like 'tracks lifecycle update event'

      it 'creates custom statuses from system-defined statuses' do
        expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(5)

        expect(lifecycle.statuses.pluck(:name)).to contain_exactly(
          system_defined_lifecycle.default_open_status.name,
          system_defined_in_progress_status.name,
          system_defined_lifecycle.default_closed_status.name,
          system_defined_wont_do_status.name,
          system_defined_lifecycle.default_duplicate_status.name
        )
        expect(lifecycle.statuses.count).to eq(5)
      end

      it 'preserves the status mapping' do
        expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
          .to contain_exactly(1, 2, 3, 4, 5)
      end

      context 'when only some of the system-defined statuses are provided' do
        let(:params) do
          {
            id: system_defined_lifecycle.to_gid,
            statuses: [
              status_params_for(system_defined_lifecycle.default_open_status),
              status_params_for(system_defined_lifecycle.default_closed_status),
              status_params_for(system_defined_lifecycle.default_duplicate_status)
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        shared_examples 'adds mapping when provided' do
          let(:params) do
            super().merge(
              status_mappings: [
                {
                  old_status_id: system_defined_in_progress_status.to_gid,
                  new_status_id: system_defined_lifecycle.default_open_status.to_gid
                }
              ]
            )
          end

          let(:mappings) { WorkItems::Statuses::Custom::Mapping.last(2) }
          let(:old_status_id) do
            ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(
              group, system_defined_in_progress_status.name
            ).id
          end

          let(:new_status_id) do
            ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(
              group, system_defined_lifecycle.default_open_status.name
            ).id
          end

          it 'adds mapping record' do
            expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(2)

            expect(mappings.pluck(:work_item_type_id)).to match_array(lifecycle.work_item_types.map(&:id))
            expect(mappings).to all(
              have_attributes(
                old_status_id: old_status_id,
                new_status_id: new_status_id,
                namespace_id: group.id,
                valid_from: nil,
                valid_until: nil
              )
            )
          end
        end

        it_behaves_like 'lifecycle service creates custom lifecycle'
        it_behaves_like 'sets default statuses correctly'
        it_behaves_like 'adds mapping when provided'

        it 'creates custom statuses from system-defined statuses' do
          expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(3)

          expect(lifecycle.statuses.pluck(:name)).to contain_exactly(
            system_defined_lifecycle.default_open_status.name,
            system_defined_lifecycle.default_closed_status.name,
            system_defined_lifecycle.default_duplicate_status.name
          )
          expect(lifecycle.statuses.count).to eq(3)
        end

        it 'preserves the status conversion mapping' do
          expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
            .to contain_exactly(1, 3, 5)
        end

        it 'tracks deletion events for the missing statuses' do
          expect { result }
            .to trigger_internal_events('delete_custom_status_in_group_settings')
            .with(user: user, namespace: group, additional_properties: { label: eq('in_progress').or(eq('canceled')) })
            .exactly(2).times
        end

        context 'when some system-defined status params are changed' do
          let(:updated_status_params) { params[:statuses][1] }

          shared_examples 'triggers events for converted statuses with changes' do
            it 'tracks update events for the updated statuses' do
              expect { result }
                .to trigger_internal_events('update_custom_status_in_group_settings')
                .with(user: user, namespace: group, additional_properties: {
                  label: updated_status_params[:category].to_s
                })
            end
          end

          context 'when name is changed' do
            before do
              updated_status_params[:name] = 'New name'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when color is changed' do
            before do
              updated_status_params[:color] = '#000000'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when description is changed' do
            before do
              updated_status_params[:description] = 'Some description'
            end

            it_behaves_like 'triggers events for converted statuses with changes'
          end

          context 'when description is set to empty string' do
            before do
              updated_status_params[:description] = ''
            end

            it 'does not trigger update event' do
              expect { result }
                .not_to trigger_internal_events('update_custom_status_in_group_settings')
            end
          end
        end

        context 'when there are board lists using the system-defined status' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:project) { create(:project, group: group) }

          let!(:group_list) do
            create(
              :status_list,
              board: create(:board, group: group),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:subgroup_list) do
            create(
              :status_list,
              board: create(:board, group: subgroup),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:project_list) do
            create(
              :status_list,
              board: create(:board, project: project),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          let!(:other_system_defined_list) do
            create(
              :status_list,
              board: create(:board, project: project),
              system_defined_status_identifier: build(:work_item_system_defined_status, :to_do).id
            )
          end

          let!(:other_project_list) do
            create(
              :status_list,
              board: create(:board, group: other_group),
              system_defined_status_identifier: build(:work_item_system_defined_status, :in_progress).id
            )
          end

          it 'removes board lists using the omitted statuses' do
            expect { result }.to change { List.count }.by(-3)

            expect { group_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { subgroup_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { project_list.reload }.to raise_error(ActiveRecord::RecordNotFound)

            expect(other_system_defined_list.reload).to be_present
            expect(other_project_list.reload).to be_present
          end
        end

        context 'when trying to exclude a status in use' do
          let(:work_item) { create(:work_item, namespace: group) }
          let!(:current_status) do
            create(:work_item_current_status, work_item: work_item,
              system_defined_status: system_defined_in_progress_status)
          end

          let(:expected_error_message) do
            "Cannot remove status '#{system_defined_in_progress_status.name}' " \
              "from lifecycle because it is in use and no mapping is provided"
          end

          it_behaves_like 'lifecycle service does not create custom lifecycle'
          it_behaves_like 'lifecycle service returns validation error'
          it_behaves_like 'adds mapping when provided'
        end

        context 'when trying to exclude a default status' do
          let(:params) do
            {
              id: system_defined_lifecycle.to_gid,
              statuses: [
                status_params_for(system_defined_in_progress_status),
                status_params_for(system_defined_lifecycle.default_closed_status),
                status_params_for(system_defined_lifecycle.default_duplicate_status)
              ]
            }
          end

          context 'when no mapping is provided' do
            let(:expected_error_message) do
              "Cannot remove default status '#{system_defined_lifecycle.default_open_status.name}' " \
                "without providing a mapping"
            end

            it_behaves_like 'lifecycle service does not create custom lifecycle'
            it_behaves_like 'lifecycle service returns validation error'
          end

          context 'when mapping is provided' do
            let(:params) do
              super().merge(
                status_mappings: [
                  {
                    old_status_id: system_defined_lifecycle.default_open_status.to_gid,
                    new_status_id: system_defined_in_progress_status.to_gid
                  }
                ]
              )
            end

            let(:expected_error_message) do
              "Validation failed: Default open status can't be blank"
            end

            it_behaves_like 'lifecycle service does not create custom lifecycle'
            it_behaves_like 'lifecycle service returns validation error'

            context 'and default open status index is provided' do
              let(:params) do
                super().merge(
                  default_open_status_index: 0
                )
              end

              it_behaves_like 'lifecycle service creates custom lifecycle'

              it 'sets default statuses correctly' do
                expect(lifecycle.default_open_status.name).to eq(system_defined_in_progress_status.name)
                expect(lifecycle.default_closed_status.name).to eq(system_defined_lifecycle.default_closed_status.name)
                expect(lifecycle.default_duplicate_status.name).to eq(
                  system_defined_lifecycle.default_duplicate_status.name)
              end

              it 'adds mapping record' do
                expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(2)

                mappings = WorkItems::Statuses::Custom::Mapping.last(2)

                expect(mappings.pluck(:work_item_type_id)).to match_array(lifecycle.work_item_types.map(&:id))
                expect(mappings).to all(
                  have_attributes(
                    old_status_id: WorkItems::Statuses::Custom::Status.find_by(namespace: group, name: "To do").id,
                    old_status_role: "open",
                    new_status_id: lifecycle.default_open_status.id,
                    namespace_id: group.id,
                    valid_from: nil,
                    valid_until: nil
                  )
                )
              end
            end
          end
        end
      end

      context 'when attempting to exceed status limit' do
        let(:params) do
          {
            id: system_defined_lifecycle.to_gid,
            statuses: [
              status_params_for(system_defined_lifecycle.default_open_status),
              status_params_for(system_defined_in_progress_status),
              status_params_for(system_defined_lifecycle.default_closed_status),
              status_params_for(system_defined_wont_do_status),
              status_params_for(system_defined_lifecycle.default_duplicate_status),
              {
                name: "Exceeding limit status",
                color: '#737278',
                description: nil,
                category: 'to_do'
              }
            ],
            default_open_status_index: 0,
            default_closed_status_index: 2,
            default_duplicate_status_index: 4
          }
        end

        let(:expected_error_message) { 'Lifecycle can only have a maximum of 5 statuses' }

        before do
          stub_const("WorkItems::Statuses::Custom::Lifecycle::MAX_STATUSES_PER_LIFECYCLE", 5)
        end

        it_behaves_like 'lifecycle service returns validation error'
      end

      context 'when only name param is provided' do
        let(:params) do
          {
            id: system_defined_lifecycle.to_gid
            # Shared example passes name attribute
          }
        end

        it_behaves_like 'accepts lifecycle attributes'
        it_behaves_like 'sets default statuses correctly'

        it 'uses statuses from system-defined lifecycle' do
          expect { result }.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(1)
                           .and change { WorkItems::Statuses::Custom::Status.count }.by(5)
        end
      end
    end

    context 'when custom lifecycle exists' do
      let!(:custom_lifecycle) do
        create(:work_item_custom_lifecycle, :for_issues, name: system_defined_lifecycle.name, namespace: group)
      end

      context 'when system-defined lifecycle is provided' do
        it_behaves_like 'lifecycle service does not create custom lifecycle'

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid lifecycle type. Custom lifecycle already exists.')
        end
      end

      context 'when only name param is provided' do
        let(:params) do
          {
            id: custom_lifecycle.to_gid
            # Shared example passes name attribute
          }
        end

        it_behaves_like 'accepts lifecycle attributes'
      end

      context 'when custom lifecycle is provided' do
        let(:params) do
          {
            id: custom_lifecycle.to_gid,
            statuses: [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status),
              {
                name: 'Ready for development',
                color: '#737278',
                description: nil,
                category: 'to_do'
              },
              {
                name: 'Complete',
                color: '#108548',
                description: nil,
                category: 'done'
              }
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        it_behaves_like 'accepts lifecycle attributes'
        it_behaves_like 'tracks lifecycle update event'

        context 'when statuses are added' do
          it 'adds custom statuses' do
            expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(2)

            expect(lifecycle.statuses.pluck(:name)).to include('Ready for development', 'Complete')

            expect(lifecycle.statuses.count).to eq(5)
          end

          it 'tracks creation events for the new statuses' do
            expect { result }
              .to trigger_internal_events('create_custom_status_in_group_settings')
              .with(user: user, namespace: group, additional_properties: { label: eq('to_do').or(eq('done')) })
              .exactly(2).times
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              custom_lifecycle.default_open_status.name,
              'Ready for development',
              custom_lifecycle.default_closed_status.name,
              'Complete',
              custom_lifecycle.default_duplicate_status.name
            ])
          end

          context 'when status to be added already exists' do
            let!(:custom_status) do
              create(:work_item_custom_status, :without_conversion_mapping,
                name: 'Ready for development', category: :to_do, namespace: group)
            end

            let(:params) do
              super().merge(statuses: [
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status),
                {
                  name: 'Ready for development',
                  color: '#737278',
                  description: nil,
                  category: 'to_do'
                }
              ])
            end

            shared_examples 'adds custom statuses to lifecycle' do
              it 'adds custom statuses to lifecycle' do
                expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                expect(lifecycle.statuses.pluck(:name)).to include('Ready for development')

                expect(lifecycle.statuses.count).to eq(4)
              end
            end

            it_behaves_like 'adds custom statuses to lifecycle'

            context 'and mapping exists for the existing status' do
              let!(:existing_mapping) do
                create(
                  :work_item_custom_status_mapping,
                  namespace_id: group.id,
                  work_item_type_id: custom_lifecycle.work_item_types.first.id,
                  old_status_id: custom_status.id,
                  new_status_id: custom_lifecycle.default_open_status.id
                )
              end

              it_behaves_like 'adds custom statuses to lifecycle'

              it 'sets valid_until for existing mapping', :freeze_time do
                expect { result }.to change { existing_mapping.reset.valid_until }
                  .from(nil).to(Time.current)
              end
            end

            context 'and two mappings exist for the existing status' do
              let!(:first_mapping) do
                create(
                  :work_item_custom_status_mapping,
                  namespace_id: group.id,
                  work_item_type_id: custom_lifecycle.work_item_types.first.id,
                  old_status_id: custom_status.id,
                  new_status_id: custom_lifecycle.default_open_status.id,
                  valid_until: 5.days.ago
                )
              end

              let!(:second_mapping) do
                create(
                  :work_item_custom_status_mapping,
                  namespace_id: group.id,
                  work_item_type_id: custom_lifecycle.work_item_types.first.id,
                  old_status_id: custom_status.id,
                  new_status_id: custom_lifecycle.default_open_status.id,
                  valid_from: 3.days.ago
                )
              end

              it_behaves_like 'adds custom statuses to lifecycle'

              it 'sets valid_until for second mapping', :freeze_time do
                expect { result }.to change { second_mapping.reset.valid_until }
                  .from(nil).to(Time.current)
              end
            end
          end

          context 'when other root namespace exists' do
            let!(:other_custom_lifecycle) do
              create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: other_group)
            end

            let(:params) do
              {
                id: custom_lifecycle.to_gid,
                statuses: [
                  status_params_for(custom_lifecycle.default_open_status),
                  status_params_for(custom_lifecycle.default_closed_status),
                  status_params_for(custom_lifecycle.default_duplicate_status),
                  status_params_for(other_custom_lifecycle.default_open_status)
                ],
                default_open_status_index: 0,
                default_closed_status_index: 1,
                default_duplicate_status_index: 2
              }
            end

            shared_examples 'returns error and does not change data' do
              it_behaves_like 'lifecycle service returns validation error'

              it 'does not add status from other lifecycle' do
                expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                expect(custom_lifecycle.statuses.count).to eq(3)
              end
            end

            context 'when provided lifecycle belongs to other root namespace' do
              before do
                params[:id] = other_custom_lifecycle.to_gid
              end

              let(:expected_error_message) do
                "You don't have permission to update this lifecycle."
              end

              it_behaves_like 'returns error and does not change data'
            end

            context 'when provided status belongs to other root namespace' do
              let(:expected_error_message) do
                "Status '#{other_custom_lifecycle.default_open_status.name}' doesn't belong to this namespace."
              end

              it_behaves_like 'returns error and does not change data'
            end
          end
        end

        context 'when statuses are updated' do
          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status).merge(
                  name: 'Updated To Do',
                  description: 'Updated description'
                ),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'updates custom status attributes' do
            expect(lifecycle.default_open_status).to have_attributes(
              name: 'Updated To Do',
              description: 'Updated description',
              updated_by: user
            )
          end

          it 'tracks update events for the updated statuses' do
            expect { result }
              .to trigger_internal_events('update_custom_status_in_group_settings')
              .with(user: user, namespace: group, additional_properties: { label: 'to_do' })
          end

          it 'preserves the status mapping' do
            expect(lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
              .to contain_exactly(1, 3, 5)
          end

          context 'when updating status without providing ID' do
            let(:params) do
              {
                id: custom_lifecycle.to_gid,
                statuses: [
                  {
                    name: custom_lifecycle.default_open_status.name,
                    color: custom_lifecycle.default_open_status.color,
                    description: 'Updated description',
                    category: custom_lifecycle.default_open_status.category
                  },
                  status_params_for(custom_lifecycle.default_closed_status),
                  status_params_for(custom_lifecycle.default_duplicate_status)
                ],
                default_open_status_index: 0,
                default_closed_status_index: 1,
                default_duplicate_status_index: 2
              }
            end

            it 'updates custom status attributes' do
              expect(lifecycle.default_open_status).to have_attributes(
                description: 'Updated description',
                updated_by: user
              )
            end
          end
        end

        context 'when default statuses are updated' do
          let(:new_open_status) { create(:work_item_custom_status, namespace: group) }
          let!(:new_open_lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: new_open_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(new_open_status),
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 2,
              default_duplicate_status_index: 3
            }
          end

          it 'updates the default status' do
            expect(lifecycle.default_open_status).to eq(new_open_status)
            expect(lifecycle.updated_by).to eq(user)
          end
        end

        context 'when statuses are removed' do
          let!(:custom_lifecycle_status) do
            create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: custom_status,
              namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          context 'when removing status without conversion mapping' do
            let(:custom_status) do
              create(:work_item_custom_status, :without_conversion_mapping,
                name: 'Ready for development', namespace: group)
            end

            it_behaves_like 'removes custom statuses'
            it_behaves_like 'reorders custom statuses'

            context 'when trying to remove a status also attached to another lifecycle' do
              let!(:other_lifecycle) do
                create(:work_item_custom_lifecycle, :for_tasks, namespace: group)
              end

              before do
                create(:work_item_custom_lifecycle_status, lifecycle: other_lifecycle, status: custom_status,
                  namespace: group)

                create(:work_item, :task, namespace: group, custom_status_id: custom_status.id)
              end

              it 'removes status from lifecycle but not from namespace' do
                expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                expect(result.errors).to be_empty

                expect(other_lifecycle.reset.statuses.pluck(:name)).to include(custom_status.name)

                expect(lifecycle.statuses.pluck(:name)).not_to include(custom_status.name)
                expect(lifecycle.statuses.count).to eq(3)
              end
            end

            context 'when trying to remove a status in use' do
              let(:work_item) { create(:work_item, namespace: group) }
              let!(:current_status) do
                create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
              end

              let(:expected_error_message) do
                "Cannot remove status '#{custom_status.name}' from lifecycle " \
                  "because it is in use and no mapping is provided"
              end

              it_behaves_like 'lifecycle service returns validation error'

              context 'when mapping is provided' do
                let(:params) do
                  super().merge(
                    status_mappings: [
                      {
                        old_status_id: custom_status.to_gid,
                        new_status_id: custom_lifecycle.default_open_status.to_gid
                      }
                    ]
                  )
                end

                let(:other_mapping_status) do
                  create(:work_item_custom_status, :without_conversion_mapping, namespace: group)
                end

                let(:mapping) { WorkItems::Statuses::Custom::Mapping.last }

                let(:expected_valid_from) { initial_mapping.reset.valid_until }

                shared_examples 'adds new mapping with valid_from' do
                  it 'adds new mapping with valid_from' do
                    expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

                    expect(mapping).to have_attributes(
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: custom_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      valid_from: expected_valid_from,
                      valid_until: nil
                    )
                  end
                end

                it 'adds mapping record' do
                  expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

                  expect([mapping.work_item_type_id]).to eq(custom_lifecycle.work_item_types.map(&:id))
                  expect(mapping).to have_attributes(
                    old_status_id: custom_status.id,
                    new_status_id: custom_lifecycle.default_open_status.id,
                    namespace_id: group.id,
                    valid_from: nil,
                    valid_until: nil
                  )
                end

                context 'when multiple mappings are provided' do
                  let(:params) do
                    super().merge(
                      status_mappings: [
                        {
                          old_status_id: custom_status.to_gid,
                          new_status_id: custom_lifecycle.default_open_status.to_gid
                        },
                        {
                          old_status_id: other_mapping_status.to_gid,
                          new_status_id: custom_lifecycle.default_open_status.to_gid
                        }
                      ]
                    )
                  end

                  before do
                    create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle,
                      status: other_mapping_status, namespace: group)
                  end

                  it 'adds mapping record' do
                    expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(2)

                    first_mapping, second_mapping = WorkItems::Statuses::Custom::Mapping.last(2)

                    expect([first_mapping.work_item_type_id]).to eq(custom_lifecycle.work_item_types.map(&:id))
                    expect(first_mapping).to have_attributes(
                      old_status_id: custom_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      namespace_id: group.id,
                      valid_from: nil,
                      valid_until: nil
                    )

                    expect([second_mapping.work_item_type_id]).to eq(custom_lifecycle.work_item_types.map(&:id))
                    expect(second_mapping).to have_attributes(
                      old_status_id: other_mapping_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      namespace_id: group.id,
                      valid_from: nil,
                      valid_until: nil
                    )
                  end
                end

                context 'when mapping to old status already exists' do
                  let!(:old_mapping) do
                    create(
                      :work_item_custom_status_mapping,
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: other_mapping_status.id,
                      new_status_id: custom_status.id
                    )
                  end

                  it 'prevents chained mappings by updating existing mapping to point to the new target status' do
                    expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

                    expect(mapping).to have_attributes(
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: custom_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      valid_from: nil,
                      valid_until: nil
                    )

                    expect(old_mapping.reset).to have_attributes(
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: other_mapping_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      valid_from: nil,
                      valid_until: nil
                    )
                  end

                  context 'and the mapping source is added to the lifecycle and is the target of the new mapping' do
                    let(:params) do
                      super().merge(
                        statuses: [
                          status_params_for(custom_lifecycle.default_open_status),
                          status_params_for(custom_lifecycle.default_closed_status),
                          status_params_for(custom_lifecycle.default_duplicate_status),
                          {
                            id: other_mapping_status.to_gid
                          }
                        ],
                        status_mappings: [
                          {
                            old_status_id: custom_status.to_gid,
                            new_status_id: other_mapping_status.to_gid
                          }
                        ]
                      )
                    end

                    it 'removes old mapping because it would become a self-reference and adds new mapping' do
                      expect { result }.not_to change { WorkItems::Statuses::Custom::Mapping.count }

                      expect { old_mapping.reset }.to raise_error(ActiveRecord::RecordNotFound)

                      expect(mapping).to have_attributes(
                        namespace_id: group.id,
                        work_item_type_id: custom_lifecycle.work_item_types.first.id,
                        old_status_id: custom_status.id,
                        new_status_id: other_mapping_status.id
                      )
                    end
                  end
                end

                context 'when the same mapping already exists' do
                  let!(:initial_mapping) do
                    create(
                      :work_item_custom_status_mapping,
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: custom_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id
                    )
                  end

                  it 'does not add a new mapping' do
                    expect { result }.not_to change { WorkItems::Statuses::Custom::Mapping.count }

                    expect(mapping).to eq(initial_mapping)
                  end
                end

                context 'when mapping from old status exists with different new status' do
                  let!(:initial_mapping) do
                    create(
                      :work_item_custom_status_mapping,
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: custom_status.id,
                      new_status_id: other_mapping_status.id,
                      valid_until: 5.days.ago
                    )
                  end

                  it_behaves_like 'adds new mapping with valid_from'

                  # This is an invalid case because normally the status would need to be added to the lifecycle
                  # before it can be removed again and this would set the valid_until on any existing mapping.
                  # But we should also take care of this to ensure data integrity.
                  context 'and initial mapping is invalid' do
                    let!(:initial_mapping) do
                      create(
                        :work_item_custom_status_mapping,
                        namespace_id: group.id,
                        work_item_type_id: custom_lifecycle.work_item_types.first.id,
                        old_status_id: custom_status.id,
                        new_status_id: other_mapping_status.id
                      )
                    end

                    it 'updates existing mapping with valid_until to keep data valid', :freeze_time do
                      expect { result }.to change { initial_mapping.reset.valid_until }
                        .from(nil).to(Time.current)
                    end

                    it_behaves_like 'adds new mapping with valid_from'
                  end
                end

                context 'when mapping from old status exists with valid_until' do
                  let!(:initial_mapping) do
                    create(
                      :work_item_custom_status_mapping,
                      namespace_id: group.id,
                      work_item_type_id: custom_lifecycle.work_item_types.first.id,
                      old_status_id: custom_status.id,
                      new_status_id: custom_lifecycle.default_open_status.id,
                      valid_until: 5.days.ago
                    )
                  end

                  it_behaves_like 'adds new mapping with valid_from'

                  context 'and another mapping exists with valid_until and valid_from' do
                    let!(:second_mapping) do
                      create(
                        :work_item_custom_status_mapping,
                        namespace_id: group.id,
                        work_item_type_id: custom_lifecycle.work_item_types.first.id,
                        old_status_id: custom_status.id,
                        new_status_id: custom_lifecycle.default_open_status.id,
                        valid_from: 3.days.ago,
                        valid_until: 1.day.ago
                      )
                    end

                    let(:expected_valid_from) { second_mapping.reset.valid_until }

                    it_behaves_like 'adds new mapping with valid_from'
                  end

                  context 'and another mapping to different status exists without valid_until' do
                    let!(:second_mapping) do
                      create(
                        :work_item_custom_status_mapping,
                        namespace_id: group.id,
                        work_item_type_id: custom_lifecycle.work_item_types.first.id,
                        old_status_id: custom_status.id,
                        new_status_id: other_mapping_status.id,
                        valid_from: 3.days.ago
                      )
                    end

                    let(:expected_valid_from) { second_mapping.reset.valid_until }

                    it 'updates existing mapping with valid_until to keep data valid', :freeze_time do
                      expect { result }.to change { second_mapping.reset.valid_until }
                        .from(nil).to(Time.current)
                    end

                    it_behaves_like 'adds new mapping with valid_from'
                  end
                end

                context 'when mapping statuses belong to different states' do
                  let(:params) do
                    super().merge(
                      status_mappings: [
                        {
                          old_status_id: custom_status.to_gid,
                          new_status_id: custom_lifecycle.default_closed_status.to_gid
                        }
                      ]
                    )
                  end

                  let(:expected_error_message) do
                    "Mapping statuses '#{custom_status.name}' and '#{custom_lifecycle.default_closed_status.name}' " \
                      "must be of a category of the same state (open/closed)."
                  end

                  it_behaves_like 'lifecycle service returns validation error'
                end

                context 'when new status is not present in lifecycle' do
                  let(:new_open_status) do
                    create(:work_item_custom_status, :without_conversion_mapping, namespace: group)
                  end

                  let(:params) do
                    super().merge(
                      status_mappings: [
                        {
                          old_status_id: custom_status.to_gid,
                          new_status_id: new_open_status.to_gid
                        }
                      ]
                    )
                  end

                  let(:expected_error_message) do
                    "Mapping target status '#{new_open_status.name}' does not belong to the target lifecycle"
                  end

                  it_behaves_like 'lifecycle service returns validation error'
                end
              end
            end

            context 'when trying to remove a default status' do
              let(:params) do
                {
                  id: custom_lifecycle.to_gid.to_s,
                  statuses: [
                    status_params_for(custom_lifecycle.default_closed_status),
                    status_params_for(custom_lifecycle.default_duplicate_status)
                  ]
                }
              end

              before do
                custom_lifecycle_status.destroy!
                custom_lifecycle.update!(default_open_status: custom_status)
              end

              context 'when no mapping is provided' do
                let(:expected_error_message) do
                  "Cannot remove default status '#{custom_status.name}' without providing a mapping"
                end

                it_behaves_like 'lifecycle service returns validation error'
              end

              context 'when mapping is provided' do
                let(:new_default_open_status) do
                  create(:work_item_custom_status, :without_conversion_mapping,
                    name: 'Planning breakdown', namespace: group)
                end

                let(:params) do
                  {
                    id: custom_lifecycle.to_gid,
                    statuses: [
                      status_params_for(new_default_open_status),
                      status_params_for(custom_lifecycle.default_closed_status),
                      status_params_for(custom_lifecycle.default_duplicate_status)
                    ],
                    status_mappings: [
                      {
                        old_status_id: custom_status.to_gid,
                        new_status_id: new_default_open_status.to_gid
                      }
                    ],
                    default_open_status_index: 0,
                    default_closed_status_index: 1,
                    default_duplicate_status_index: 2
                  }
                end

                it 'sets the new default status' do
                  expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                  custom_lifecycle.reset

                  expect(custom_lifecycle.default_open_status).to eq(new_default_open_status)
                end

                it 'removes the old default status from the lifecycle' do
                  expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }

                  custom_lifecycle.reset

                  expect(custom_lifecycle.statuses.pluck(:name)).not_to include(custom_status.name)
                  expect(custom_lifecycle.statuses.count).to eq(3)
                end

                it 'adds mapping record' do
                  expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

                  expect(WorkItems::Statuses::Custom::Mapping.last).to have_attributes(
                    old_status_id: custom_status.id,
                    old_status_role: "open",
                    new_status_id: new_default_open_status.id,
                    work_item_type_id: custom_lifecycle.work_item_types.first.id,
                    namespace_id: group.id,
                    valid_from: nil,
                    valid_until: nil
                  )
                end
              end
            end
          end

          context 'when removing status with conversion mapping' do
            let(:custom_status) do
              create(:work_item_custom_status, :in_progress, name: 'Ready for dev', namespace: group)
            end

            it_behaves_like 'removes custom statuses'
            it_behaves_like 'reorders custom statuses'

            context 'when there are board lists using the converted status' do
              let_it_be(:subgroup) { create(:group, parent: group) }
              let_it_be(:project) { create(:project, group: group) }

              let!(:group_list) do
                create(
                  :status_list,
                  board: create(:board, group: group),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:subgroup_list) do
                create(
                  :status_list,
                  board: create(:board, group: subgroup),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:project_list) do
                create(
                  :status_list,
                  board: create(:board, project: project),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              let!(:custom_status_list) do
                create(
                  :status_list,
                  :with_custom_status,
                  board: create(:board, project: project),
                  custom_status: create(:work_item_custom_status, :triage, namespace: group)
                )
              end

              let!(:other_project_list) do
                create(
                  :status_list,
                  board: create(:board, group: other_group),
                  system_defined_status_identifier: custom_status.converted_from_system_defined_status_identifier
                )
              end

              it 'removes the board lists with converted status' do
                expect { result }.to change { List.count }.by(-3)

                expect { group_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
                expect { subgroup_list.reload }.to raise_error(ActiveRecord::RecordNotFound)
                expect { project_list.reload }.to raise_error(ActiveRecord::RecordNotFound)

                expect(custom_status_list.reload).to be_present
                expect(other_project_list.reload).to be_present
              end
            end

            context 'when trying to remove a status in explicit use' do
              let(:work_item) { create(:work_item, namespace: group) }
              let!(:current_status) do
                create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
              end

              let(:expected_error_message) do
                "Cannot remove status '#{custom_status.name}' from lifecycle " \
                  "because it is in use and no mapping is provided"
              end

              it_behaves_like 'lifecycle service returns validation error'
            end

            context 'when trying to remove a status in implicit use' do
              let!(:work_item) { create(:work_item, namespace: group) }
              let(:new_default_status) { create(:work_item_custom_status, :triage, namespace: group) }
              let(:expected_error_message) do
                "Cannot remove status 'To do' from lifecycle " \
                  "because it is in use and no mapping is provided"
              end

              before do
                custom_lifecycle.default_open_status.update!(name: "To do")
                custom_lifecycle.update!(default_open_status: new_default_status)
              end

              it_behaves_like 'lifecycle service returns validation error'
            end

            context 'when trying to remove a default status' do
              let(:new_default_open_status) do
                create(:work_item_custom_status, :to_do, name: 'Planning breakdown', namespace: group)
              end

              let(:params) do
                {
                  id: custom_lifecycle.to_gid.to_s,
                  statuses: [
                    status_params_for(new_default_open_status),
                    status_params_for(custom_lifecycle.default_closed_status),
                    status_params_for(custom_lifecycle.default_duplicate_status)
                  ]
                }
              end

              before do
                custom_lifecycle_status.destroy!
                custom_lifecycle.update!(default_open_status: custom_status)
              end

              context 'when no mapping is provided' do
                let(:expected_error_message) do
                  "Cannot remove default status '#{custom_status.name}' without providing a mapping"
                end

                it_behaves_like 'lifecycle service returns validation error'
              end

              context 'when mapping is provided' do
                let(:params) do
                  {
                    id: custom_lifecycle.to_gid,
                    statuses: [
                      status_params_for(new_default_open_status),
                      status_params_for(custom_lifecycle.default_closed_status),
                      status_params_for(custom_lifecycle.default_duplicate_status)
                    ],
                    status_mappings: [
                      {
                        old_status_id: custom_lifecycle.default_open_status.to_gid,
                        new_status_id: new_default_open_status.to_gid
                      }
                    ],
                    default_open_status_index: 0
                  }
                end

                it 'sets the new default status' do
                  expect(lifecycle.default_open_status).to eq(new_default_open_status)
                end

                it 'removes the old default status from the lifecycle' do
                  expect { result }.not_to change { WorkItems::Statuses::Custom::Status.count }
                  expect(lifecycle.statuses.pluck(:name)).not_to include(custom_status.name)
                  expect(lifecycle.statuses.count).to eq(3)
                end

                it 'adds mapping record' do
                  expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

                  expect(WorkItems::Statuses::Custom::Mapping.last).to have_attributes(
                    old_status_id: custom_status.id,
                    old_status_role: "open",
                    new_status_id: new_default_open_status.id,
                    work_item_type_id: custom_lifecycle.work_item_types.first.id,
                    namespace_id: group.id,
                    valid_from: nil,
                    valid_until: nil
                  )
                end
              end
            end
          end
        end

        context 'when statuses are reordered' do
          let(:existing_in_progress_status) do
            create(:work_item_custom_status, name: 'In Progress', namespace: group, category: :in_progress)
          end

          let!(:lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: existing_in_progress_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                {
                  name: 'Ready for development',
                  color: '#737278',
                  description: nil,
                  category: 'to_do'
                },
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(existing_in_progress_status),
                {
                  name: 'Complete',
                  color: '#108548',
                  description: nil,
                  category: 'done'
                },
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 3,
              default_duplicate_status_index: 5
            }
          end

          before do
            custom_lifecycle.default_open_status.name = "To do"
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              'Ready for development',
              'To do',
              'In Progress',
              'Complete',
              custom_lifecycle.default_closed_status.name,
              custom_lifecycle.default_duplicate_status.name
            ])
          end
        end

        context 'when attempting to exceed status limit' do
          let(:params) do
            statuses_array = [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status)
            ]

            28.times do |i|
              statuses_array << {
                name: "Custom To Do #{i + 1}",
                color: '#737278',
                description: nil,
                category: 'to_do'
              }
            end

            {
              id: custom_lifecycle.to_gid,
              statuses: statuses_array,
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          let(:expected_error_message) { 'Lifecycle can only have a maximum of 30 statuses' }

          it_behaves_like 'lifecycle service returns validation error'
        end
      end
    end
  end

  private

  def status_params_for(status)
    {
      id: status.to_global_id,
      name: status.name,
      color: status.color,
      description: status.description,
      category: status.category
    }
  end
end
