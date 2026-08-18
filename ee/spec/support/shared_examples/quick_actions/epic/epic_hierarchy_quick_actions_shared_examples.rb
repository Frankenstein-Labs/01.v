# frozen_string_literal: true

RSpec.shared_context 'for epic hierarchy commands' do
  include LegacyEpicsHelper
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:private_group, freeze: false) { create(:group, :private, guests: guest) }
  let_it_be(:public_group, freeze: false) { create(:group, :public, guests: guest) }
  let_it_be_with_reload(:epic) { create(:epic, group: public_group) }
  let_it_be_with_reload(:epic2) { create(:epic, group: private_group) }
end

RSpec.shared_examples 'execute epic hierarchy commands' do
  include_context 'for epic hierarchy commands'

  let_it_be(:subgroup, freeze: false) { create(:group, parent: public_group, guests: guest) }
  let_it_be(:public_project, freeze: false) { create(:project, :public, group: public_group) }
  let_it_be_with_reload(:subgroup_epic) { create(:epic, group: subgroup) }
  let_it_be_with_reload(:child_epic) { create(:epic, group: private_group) }
  let_it_be_with_reload(:parent_epic) { create(:epic, group: private_group) }

  shared_examples 'adds quick action parameter' do |parameter_key, quick_action|
    let(:content) { "/#{quick_action} #{referenced_epic&.to_reference(target)}" }

    it 'adds parameter to updates array' do
      _, updates = service.execute(content, target)

      expect(updates[parameter_key]).to eq(referenced_epic)
    end
  end

  shared_examples 'does not add quick action parameter' do |parameter_key, quick_action|
    let(:content) { "/#{quick_action} #{referenced_epic&.to_reference(target)}" }

    it 'does not add parameter to updates array' do
      _, updates = service.execute(content, target)

      expect(updates[parameter_key]).to eq(nil)
    end
  end

  shared_examples 'epic relation is not removed' do
    it { expect { service.execute(content, target) }.not_to change { child_epic.reload.parent } }
  end

  shared_examples 'epic relation is removed' do
    it { expect { service.execute(content, target) }.to change { child_epic.reload.parent }.from(parent_epic).to(nil) }
  end

  shared_examples 'hierarchy quick actions unavailable' do
    it 'does not include commands' do
      expect(service.available_commands(target).pluck(:name))
        .not_to include([:child_epic, :parent_epic, :remove_child_epic, :remove_parent_epic])
    end
  end

  context 'when subepics are not enabled' do
    let(:current_user) { guest }
    let(:target) { epic }

    before do
      stub_licensed_features(epics: true, subepics: false)
    end

    it_behaves_like 'hierarchy quick actions unavailable'
  end

  context 'when target is an issue' do
    let_it_be(:target, freeze: false) { create(:issue, project: public_project) }

    it_behaves_like 'hierarchy quick actions unavailable'
  end

  context 'when target is a merge request' do
    let_it_be(:target, freeze: false) { create(:merge_request, source_project: public_project) }

    it_behaves_like 'hierarchy quick actions unavailable'
  end

  context 'when subepics are enabled' do
    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    context 'with child_epic command' do
      let(:target) { epic }
      let(:referenced_epic) { child_epic }

      context 'when user does not have guest access to the child epic' do
        it_behaves_like 'does not add quick action parameter', :quick_action_assign_child_epic, :child_epic
      end

      context 'when user has guest access to the child epic but not to parent epic group' do
        before do
          private_group.add_guest(current_user)
        end

        it_behaves_like 'quick action is unavailable', :child_epic

        context 'when passed child epic is nil' do
          let(:child_epic) { nil }

          it_behaves_like 'does not add quick action parameter', :quick_action_assign_child_epic, :child_epic

          it 'does not raise error' do
            content = "/child_epic "

            expect { service.execute(content, epic) }.not_to raise_error
          end
        end
      end

      context 'when user has guest access to both child epic and parent epic groups' do
        before do
          private_group.add_guest(current_user)
          public_group.add_guest(current_user)
        end

        it_behaves_like 'adds quick action parameter', :quick_action_assign_child_epic, :child_epic
        it_behaves_like 'quick action is available', :child_epic

        context 'when target epic is not persisted yet' do
          let(:target) { build(:epic, group: public_group) }

          it_behaves_like 'adds quick action parameter', :quick_action_assign_child_epic, :child_epic
        end

        context 'when child_epic is already linked to the epic' do
          let(:referenced_epic) { epic2 }

          before do
            assign_epic_parent(child_epic, referenced_epic)
          end

          it_behaves_like 'quick action is available', :child_epic
        end

        context 'when child epic is in a subgroup of parent epic' do
          let(:referenced_epic) { subgroup_epic }

          it_behaves_like 'quick action is available', :child_epic
        end

        context 'when child epic is in a ancestor group of the parent epic' do
          let(:target) { subgroup_epic }
          let(:referenced_epic) { epic2 }

          it_behaves_like 'quick action is available', :child_epic
        end
      end
    end

    context 'with parent_epic command' do
      let(:referenced_epic) { parent_epic }
      let(:target) { child_epic }

      context 'when user has guest access to child epic' do
        let(:current_user) { guest }

        it_behaves_like 'quick action is available', :parent_epic
        it_behaves_like 'adds quick action parameter', :quick_action_assign_to_parent_epic, :parent_epic

        context 'when target epic is not persisted yet' do
          let(:target) { build(:epic, group: private_group) }

          it_behaves_like 'quick action is available', :parent_epic
          it_behaves_like 'adds quick action parameter', :quick_action_assign_to_parent_epic, :parent_epic
        end
      end

      context 'when user has no guest access to child epic' do
        it_behaves_like 'quick action is unavailable', :parent_epic
        it_behaves_like 'does not add quick action parameter', :quick_action_assign_to_parent_epic, :parent_epic
      end
    end

    context 'with remove_child_epic command' do
      let_it_be_with_reload(:child_epic) { create(:epic, group: private_group, parent: epic) }
      let(:parent_epic) { epic }
      let(:target) { parent_epic }
      let(:content) { "/remove_child_epic #{child_epic.to_reference(parent_epic)}" }

      context 'when user does not have guest access to child epic' do
        it_behaves_like 'epic relation is not removed'
      end

      context 'when user has have guest access to child epic' do
        let(:current_user) { guest }

        it_behaves_like 'quick action is available', :remove_child_epic
        it_behaves_like 'epic relation is removed'

        context 'when target epic is not persisted yet' do
          let(:target) { build(:epic, group: private_group) }

          it_behaves_like 'quick action is unavailable', :remove_child_epic
        end

        context 'when trying to remove child epic from a different epic' do
          let(:parent_epic) { epic2 }

          it_behaves_like 'epic relation is not removed'
        end

        context 'when child epic is in a subgroup of parent epic' do
          let_it_be_with_reload(:child_epic) { create(:epic, group: subgroup, parent: epic) }

          it_behaves_like 'epic relation is removed'
          it_behaves_like 'quick action is available', :remove_child_epic
        end

        context 'when child epic is in a ancestor group of the parent epic' do
          let_it_be_with_reload(:child_epic) { create(:epic, group: private_group, parent: subgroup_epic) }
          let(:parent_epic) { subgroup_epic }

          it_behaves_like 'epic relation is removed'
          it_behaves_like 'quick action is available', :remove_child_epic
        end
      end
    end

    context 'with remove_parent_epic command' do
      let_it_be_with_reload(:child_epic) { create(:epic, group: private_group, parent: epic) }
      let(:target) { child_epic }
      let(:parent_epic) { epic }

      let(:content) { "/remove_parent_epic" }

      context 'when user does not have guest access to child epic' do
        it_behaves_like 'epic relation is not removed'
        it_behaves_like 'quick action is unavailable', :remove_parent_epic
      end

      context 'when user has guest access' do
        let(:current_user) { guest }

        it_behaves_like 'epic relation is removed'
        it_behaves_like 'quick action is available', :remove_parent_epic

        context 'when target epic is not persisted yet' do
          let(:target) { build(:epic, group: private_group) }

          it_behaves_like 'epic relation is not removed'
          it_behaves_like 'quick action is unavailable', :remove_parent_epic
        end
      end
    end
  end
end

RSpec.shared_examples 'explain epic hierarchy commands' do
  include_context 'for epic hierarchy commands'

  let(:current_user) { guest }

  before do
    stub_licensed_features(epics: true, subepics: true)
  end

  shared_examples 'returns execution messages' do |relation|
    context 'when correct epic reference' do
      let(:content) { "/#{relation}_epic #{epic2&.to_reference(epic)}" }
      let(:explain_action) { relation == :child ? 'Adds' : 'Sets' }
      let(:execute_action) { relation == :child ? 'Added' : 'Set' }
      let(:article)        { relation == :child ? 'a' : 'the' }

      it 'returns explain message with epic reference' do
        _, explanations = service.explain(content, epic)
        expect(explanations)
          .to eq(["#{explain_action} #{epic2.group.name}&#{epic2.iid} as #{relation} epic."])
      end

      it 'returns successful execution message' do
        _, _, message = service.execute(content, epic)

        expect(message)
          .to eq("#{execute_action} #{epic2.group.name}&#{epic2.iid} as #{article} #{relation} epic.")
      end
    end

    context 'when epic reference is wrong' do |relation|
      let(:content) { "/#{relation}_epic qwe" }

      it 'returns empty explain message' do
        _, explanations = service.explain(content, epic)
        expect(explanations).to eq([])
      end
    end
  end

  shared_examples 'target epic does not exist' do |relation|
    it 'returns unsuccessful execution message' do
      _, _, message = service.execute(content, epic)

      expect(message)
        .to eq("#{relation.capitalize} epic does not exist.")
    end
  end

  shared_examples 'epics are already related' do
    it 'returns unsuccessful execution message' do
      _, _, message = service.execute(content, epic)

      expect(message)
        .to eq("Given epic is already related to this epic.")
    end
  end

  shared_examples 'without permissions for action' do |target_epic: nil, param_epic: nil|
    before do
      allow(current_user).to receive(:can?).and_call_original
      allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
      allow(current_user).to receive(:can?).with(:admin_all_resources).and_return(true)
      allow(current_user).to receive(:can?).with(:"#{target_epic}_epic_tree_relation", epic).and_return(true)
      allow(current_user).to receive(:can?).with(:"#{param_epic}_epic_tree_relation", epic2).and_return(false)
    end

    it 'returns unsuccessful execution message' do
      _, _, message = service.execute(content, epic)

      expect(message)
        .to eq("You don't have sufficient permission to perform this action.")
    end
  end

  context 'with child_epic command' do
    it_behaves_like 'returns execution messages', :child

    context 'when epic is already a child epic' do
      let(:content) { "/child_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic2, epic)
      end

      it_behaves_like 'epics are already related'
    end

    context 'when epic is the parent epic' do
      let(:content) { "/child_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic, epic2)
      end

      it_behaves_like 'epics are already related'
    end

    context 'when epic does not exist' do
      let(:content) { "/child_epic none" }

      it_behaves_like 'target epic does not exist', :child
    end

    context 'when user has no permissions to relate the child epic' do
      let(:content) { "/child_epic #{epic2&.to_reference(epic)}" }

      it_behaves_like 'without permissions for action', target_epic: :create, param_epic: :admin
    end
  end

  context 'with remove_child_epic command' do
    context 'when correct epic reference' do
      let(:content) { "/remove_child_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic2, epic)
      end

      it 'returns explain message with epic reference' do
        _, explanations = service.explain(content, epic)

        expect(explanations).to eq(["Removes #{epic2.group.name}&#{epic2.iid} from child epics."])
      end

      it 'returns successful execution message' do
        _, _, message = service.execute(content, epic)

        expect(message)
          .to eq("Removed #{epic2.group.name}&#{epic2.iid} from child epics.")
      end
    end

    context 'when epic reference is wrong' do
      let(:content) { "/remove_child_epic qwe" }

      it 'returns empty explain message' do
        _, explanations = service.explain(content, epic)
        expect(explanations).to eq([])
      end
    end

    context 'when child epic does not exist' do
      let(:content) { "/remove_child_epic #{epic2&.to_reference(epic)}" }

      before do
        epic.update!(parent: nil)
      end

      it 'returns unsuccessful execution message' do
        _, _, message = service.execute(content, epic)

        expect(message)
          .to eq("Child epic does not exist.")
      end
    end

    context 'when user has no permissions to remove child epic' do
      let(:content) { "/remove_child_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic2, epic)
      end

      it_behaves_like 'without permissions for action', target_epic: :create, param_epic: :admin
    end
  end

  context 'with parent_epic command' do
    let(:referenced_epic) { epic2 }

    it_behaves_like 'returns execution messages', :parent

    context 'when epic is already a parent epic' do
      let(:content) { "/parent_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic, epic2)
      end

      it_behaves_like 'epics are already related'
    end

    context 'when epic is a an existing child epic' do
      let(:content) { "/parent_epic #{epic2&.to_reference(epic)}" }

      before do
        assign_epic_parent(epic2, epic)
      end

      it_behaves_like 'epics are already related'
    end

    context 'when epic does not exist' do
      let(:content) { "/parent_epic none" }

      it_behaves_like 'target epic does not exist', :parent
    end

    context 'when user has no permissions to relate the parent epic' do
      let(:content) { "/parent_epic #{epic2&.to_reference(epic)}" }

      it_behaves_like 'without permissions for action', target_epic: :admin, param_epic: :create
    end
  end

  context 'with remove_parent_epic command' do
    context 'when parent is present' do
      before do
        epic.parent = epic2
      end

      it 'returns explain message with epic reference' do
        _, explanations = service.explain("/remove_parent_epic", epic)

        expect(explanations).to eq(["Removes parent epic #{epic2.group.name}&#{epic2.iid}."])
      end

      it 'returns successful execution message' do
        _, _, message = service.execute("/remove_parent_epic", epic)

        expect(message)
          .to eq("Removed parent epic #{epic2.group.name}&#{epic2.iid}.")
      end
    end

    context 'when parent is not present' do
      before do
        epic.parent = nil
      end

      it 'returns empty explain message' do
        _, explanations = service.explain("/remove_parent_epic", epic)

        expect(explanations).to eq([])
      end

      it 'returns unsuccessful execution message' do
        _, _, message = service.execute("/remove_parent_epic", epic)

        expect(message)
          .to eq("Parent epic is not present.")
      end
    end

    context 'when user has no permissions to remove parent epic' do
      let(:content) { "/remove_parent_epic" }

      before do
        epic.parent = epic2
      end

      it_behaves_like 'without permissions for action', target_epic: :admin, param_epic: :create
    end
  end
end
