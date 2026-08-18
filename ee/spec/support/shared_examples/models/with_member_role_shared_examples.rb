# frozen_string_literal: true

RSpec.shared_examples 'model with member role relation' do
  let(:expected_member_role_owner) { model.group }

  describe 'associations', feature_category: :permissions do
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validations', feature_category: :permissions do
    before do
      assign_member_role(model, access_level: Gitlab::Access::DEVELOPER)
      model[model.base_access_level_attr] = Gitlab::Access::DEVELOPER

      stub_licensed_features(custom_roles: true)
    end

    describe 'validate_member_role_access_level' do
      context 'when no member role is associated' do
        before do
          model.member_role = nil
        end

        it { is_expected.to be_valid }
      end

      context 'when the member role base access level matches the default membership role' do
        it { is_expected.to be_valid }
      end

      context 'when the member role base access level does not match the default membership role' do
        before do
          model[model.base_access_level_attr] = Gitlab::Access::GUEST
        end

        it 'is invalid' do
          expect(model).not_to be_valid
          expect(model.errors[:member_role_id]).to include(
            _("the custom role's base access level does not match the current access level")
          )
        end
      end
    end

    describe 'validate_access_level_locked_for_member_role' do
      before do
        model.save!
        model[model.base_access_level_attr] = Gitlab::Access::MAINTAINER
      end

      context 'when no member role is associated' do
        before do
          model.member_role = nil
        end

        it { is_expected.to be_valid }
      end

      context 'when the member role has changed' do
        before do
          assign_member_role(model, access_level: Gitlab::Access::MAINTAINER)
        end

        it { is_expected.to be_valid }
      end

      context 'when the member role has not changed' do
        it 'is invalid' do
          expect(model).not_to be_valid
          expect(model.errors[model.base_access_level_attr]).to include(
            _('cannot be changed because of an existing association with a custom role')
          )
        end
      end
    end

    describe 'validate_member_role_belongs_to_same_root_namespace' do
      context 'when no member role is associated' do
        before do
          model.member_role = nil
        end

        it { is_expected.to be_valid }
      end

      context "when the member role namespace is the same as the model's group" do
        it { is_expected.to be_valid }
      end

      context "when the member role namespace is outside the hierarchy of the model's group" do
        before do
          model.member_role = create(:member_role,
            namespace: create(:group), base_access_level: Gitlab::Access::DEVELOPER)
        end

        it 'is invalid' do
          expect(model).not_to be_valid
        end
      end
    end
  end

  describe '#set_access_level_based_on_member_role', feature_category: :permissions do
    subject { model.set_access_level_based_on_member_role }

    context 'when a member_role_id is not present' do
      before do
        model.member_role = nil
      end

      it 'does not change the access_level' do
        expect { subject }.not_to change { model[model.base_access_level_attr] }
      end
    end

    context 'when a member_role_id is present' do
      before do
        model[model.base_access_level_attr] = nil
        assign_member_role(model)
      end

      context 'when custom roles are not enabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'does not change the access_level' do
          expect { subject }.not_to change { model[model.base_access_level_attr] }
        end

        it 'clears the member_role_id' do
          expect { subject }.to change { model.member_role }.to(nil)
        end
      end

      context 'when custom roles are enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'changes the access_level to the member roles base_access_level' do
          expect { subject }.to change { model[model.base_access_level_attr] }.to(Gitlab::Access::DEVELOPER)
        end

        it 'does not clear the member_role_id' do
          expect { subject }.not_to change { model.member_role }
        end
      end
    end
  end

  describe '#member_role_owner' do
    subject { model.member_role_owner }

    it { is_expected.to eq expected_member_role_owner }
  end

  def assign_member_role(model, access_level: Gitlab::Access::DEVELOPER)
    model.member_role = create(:member_role,
      namespace: model.send(:member_role_owner), base_access_level: access_level)
  end
end
