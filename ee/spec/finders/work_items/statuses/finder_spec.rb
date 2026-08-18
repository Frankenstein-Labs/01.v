# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Finder, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_custom_status) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: other_group) }
  let_it_be(:current_user) { create(:user, guest_of: [group, other_group]) }

  let(:namespace) { group }

  describe '#execute' do
    subject(:finder) { described_class.new(namespace, params, current_user).execute }

    shared_examples 'returns system-defined status' do
      it 'returns system-defined status' do
        expect(finder).to contain_exactly(
          have_attributes(
            class: WorkItems::Statuses::SystemDefined::Status,
            id: 1
          )
        )
      end
    end

    shared_examples 'returns custom status' do
      it 'returns custom status' do
        expect(finder).to contain_exactly(custom_status)
      end
    end

    shared_examples 'returns empty collection' do
      it 'returns empty collection' do
        expect(finder).to be_empty
      end
    end

    context 'with status_id param' do
      context 'when namespace uses system-defined statuses' do
        let(:params) { { 'status_id' => 1 } }

        it_behaves_like 'returns system-defined status'

        context 'when status is not found' do
          let(:params) { { 'status_id' => 999 } }

          it_behaves_like 'returns empty collection'
        end
      end

      context 'when namespace uses custom statuses' do
        let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }

        let(:params) { { 'status_id' => custom_status.id } }

        it_behaves_like 'returns custom status'

        context 'when status belongs to a different namespace' do
          let(:params) { { 'status_id' => other_custom_status.id } }

          it_behaves_like 'returns empty collection'
        end

        context 'when status is not found' do
          let(:params) { { 'status_id' => 0 } }

          it_behaves_like 'returns empty collection'
        end

        context 'when called with a descendant namespace' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:project) { create(:project, group: subgroup) }

          context 'with a subgroup' do
            let(:namespace) { subgroup }

            it_behaves_like 'returns custom status'
          end

          context 'with a project namespace' do
            let(:namespace) { project.project_namespace }

            it_behaves_like 'returns custom status'
          end
        end
      end
    end

    context 'with name param' do
      let(:params) { { 'name' => 'To do' } }

      context 'when namespace has custom statuses' do
        let_it_be(:custom_status) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group) }

        it_behaves_like 'returns custom status'

        context 'when name has surrounding quotes' do
          let(:params) { { 'name' => '"To do"' } }

          it_behaves_like 'returns custom status'
        end

        context 'when status contains emojis' do
          let_it_be(:custom_status_with_emoji) do
            create(:work_item_custom_status, :to_do, name: '🐞🧨', namespace: group)
          end

          let(:params) { { 'name' => '🐞🧨' } }

          it 'returns the emoji status' do
            expect(finder).to contain_exactly(custom_status_with_emoji)
          end

          context 'when name has surrounding quotes' do
            let(:params) { { 'name' => '"🐞🧨"' } }

            it 'returns the emoji status' do
              expect(finder).to contain_exactly(custom_status_with_emoji)
            end
          end
        end

        context 'when name has double surrounding quotes' do
          let(:params) { { 'name' => '""To do""' } }

          it_behaves_like 'returns empty collection' # because "To do" doesn't exist
        end

        context 'when status only exists as system-defined' do
          let(:params) { { 'name' => 'Done' } }

          it_behaves_like 'returns empty collection'
        end

        context 'when status is not found' do
          let(:params) { { 'name' => 'Invalid' } }

          it_behaves_like 'returns empty collection'
        end

        context 'when status name is blank' do
          let(:params) { { 'name' => '' } }

          it_behaves_like 'returns empty collection'
        end

        context 'when called with a descendant namespace' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:project) { create(:project, group: subgroup) }

          context 'with a subgroup' do
            let(:namespace) { subgroup }

            it_behaves_like 'returns custom status'
          end

          context 'with a project namespace' do
            let(:namespace) { project.project_namespace }

            it_behaves_like 'returns custom status'
          end
        end
      end

      context 'when namespace has no custom statuses' do
        it_behaves_like 'returns system-defined status'

        context 'when status is not found' do
          let(:params) { { 'name' => 'Invalid' } }

          it_behaves_like 'returns empty collection'
        end

        context 'when status name is blank' do
          let(:params) { { 'name' => '' } }

          it_behaves_like 'returns empty collection'
        end
      end

      context 'with multiple namespaces' do
        let_it_be(:system_defined_status) { build(:work_item_system_defined_status, :to_do) }
        let_it_be(:custom_status) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group) }
        let(:namespace) { nil }

        it 'returns matching statuses across authorized namespaces' do
          expect(finder).to contain_exactly(system_defined_status, custom_status, other_custom_status)
        end

        context 'when no matching statuses are found' do
          let(:params) { { 'name' => 'Invalid' } }

          it 'returns empty collection' do
            expect(finder).to be_empty
          end
        end
      end
    end

    context 'with no status params' do
      let(:params) { {} }

      it_behaves_like 'returns empty collection'
    end
  end

  describe '#find_single_status' do
    subject(:find_single_status) { described_class.new(namespace, params).find_single_status }

    context 'when execute returns results' do
      let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }
      let(:params) { { 'status_id' => custom_status.id } }

      it 'returns the first status' do
        expect(find_single_status).to eq(custom_status)
      end
    end

    context 'when execute returns empty array' do
      let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }
      let(:params) { { 'status_id' => 0 } }

      it 'returns nil' do
        expect(find_single_status).to be_nil
      end
    end
  end
end
