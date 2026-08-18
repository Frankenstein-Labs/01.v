# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::SeedVisibilityDefaultsService, feature_category: :team_planning do
  let_it_be(:root) { create(:group) }
  let_it_be(:child) { create(:group, parent: root) }

  let_it_be(:issue_type_id) { create(:work_item_system_defined_type, :issue).id }
  let_it_be(:task_type_id) { create(:work_item_system_defined_type, :task).id }
  let_it_be(:incident_type_id) { create(:work_item_system_defined_type, :incident).id }

  let(:namespace) { child }

  subject(:execute) { described_class.new(namespace).execute }

  before do
    stub_saas_features(namespace_scoped_work_item_types: true)
  end

  context 'when no settings record exists' do
    it 'does not create any visibility rows' do
      expect { execute }.not_to change { WorkItems::TypesFramework::Visibility.count }
    end
  end

  context 'when customizable_type_visibility is false' do
    before do
      create(:work_item_settings, namespace: root, customizable_type_visibility: false)
    end

    it 'does not create any visibility rows' do
      expect { execute }.not_to change { WorkItems::TypesFramework::Visibility.count }
    end
  end

  context 'when customizable_type_visibility is true' do
    before do
      create(:work_item_settings, namespace: root, customizable_type_visibility: true)
    end

    context 'when no defaults rows exist' do
      it 'does not create any visibility rows' do
        expect { execute }.not_to change { WorkItems::TypesFramework::Visibility.count }
      end
    end

    context 'when default=false and SIWAR resolves true (no ancestor override)' do
      before do
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: issue_type_id, enabled: false)
      end

      it 'writes a visibility row with enabled: false' do
        expect { execute }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        row = WorkItems::TypesFramework::Visibility.find_by(namespace: child, work_item_type_id: issue_type_id)
        expect(row.enabled).to be false
        expect(row.propagate).to be false
      end
    end

    context 'when default=true and SIWAR resolves false (propagating ancestor disables it)' do
      before do
        create(:work_item_type_visibility, namespace: root,
          work_item_type_id: task_type_id, enabled: false, propagate: true)
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: task_type_id, enabled: true)
      end

      it 'writes a visibility row with enabled: true to override the ancestor' do
        expect { execute }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        row = WorkItems::TypesFramework::Visibility.find_by(namespace: child, work_item_type_id: task_type_id)
        expect(row.enabled).to be true
        expect(row.propagate).to be false
      end
    end

    context 'when default agrees with SIWAR resolution' do
      before do
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: issue_type_id, enabled: true)
      end

      it 'does not write a visibility row (both true)' do
        expect { execute }.not_to change { WorkItems::TypesFramework::Visibility.count }
      end

      context 'when both are false (propagating ancestor already disables it)' do
        before do
          create(:work_item_type_visibility, namespace: root,
            work_item_type_id: task_type_id, enabled: false, propagate: true)
          create(:work_item_type_visibility_default, namespace: root,
            work_item_type_id: task_type_id, enabled: false)
        end

        it 'does not write a visibility row' do
          expect { execute }.not_to change { WorkItems::TypesFramework::Visibility.count }
        end
      end
    end

    context 'with multiple defaults, mixed results' do
      before do
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: issue_type_id, enabled: false)
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: task_type_id, enabled: true)
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: incident_type_id, enabled: true)
      end

      it 'writes only for mismatches' do
        expect { execute }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        expect(WorkItems::TypesFramework::Visibility.find_by(namespace: child,
          work_item_type_id: issue_type_id)).to be_present
        expect(WorkItems::TypesFramework::Visibility.find_by(namespace: child,
          work_item_type_id: task_type_id)).to be_nil
        expect(WorkItems::TypesFramework::Visibility.find_by(namespace: child,
          work_item_type_id: incident_type_id)).to be_nil
      end
    end

    context 'when a propagating ancestor disables a type with no defaults row' do
      before do
        create(:work_item_type_visibility, namespace: root,
          work_item_type_id: issue_type_id, enabled: false, propagate: true)
      end

      it 'writes enabled: true to restore the implicit default' do
        expect { execute }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        row = WorkItems::TypesFramework::Visibility.find_by(namespace: child, work_item_type_id: issue_type_id)
        expect(row.enabled).to be true
        expect(row.propagate).to be false
      end
    end
  end
end
