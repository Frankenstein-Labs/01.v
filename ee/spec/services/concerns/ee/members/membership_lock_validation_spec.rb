# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Members::MembershipLockValidation, feature_category: :groups_and_projects do
  include described_class

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let(:project_without_group) { build(:project, group: nil, namespace: create(:namespace)) }

  describe '#membership_locked?' do
    context 'when source is a Group' do
      it 'returns false regardless of membership_lock setting' do
        expect(membership_locked?(group)).to be false

        group.update!(membership_lock: true)
        expect(membership_locked?(group)).to be false
      end
    end

    context 'when source is a Project' do
      context 'when project has no group' do
        it 'returns false' do
          expect(membership_locked?(project_without_group)).to be false
        end
      end

      context 'when project has a group' do
        it 'delegates to project.membership_locked?' do
          allow(project).to receive(:membership_locked?).and_return(true)
          expect(membership_locked?(project)).to be true

          allow(project).to receive(:membership_locked?).and_return(false)
          expect(membership_locked?(project)).to be false
        end
      end
    end
  end
end
