# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Autocomplete::ProjectInvitedGroupsFinder, feature_category: :groups_and_projects do
  describe '#execute' do
    let_it_be(:maintainer_user) { create(:user) }
    let_it_be(:guest_user) { create(:user) }
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:private_group_with_membership) { create(:group, :private) }
    let_it_be(:private_group_without_membership) { create(:group, :private) }
    let_it_be(:non_invited_group) { create(:group, :public) }
    let(:current_user) { user }

    before_all do
      [maintainer_user, user, guest_user].each do |u|
        private_group_with_membership.add_guest(u)
      end

      [project, private_project].each do |p|
        p.add_maintainer(maintainer_user)
        p.add_guest(guest_user)
        p.invited_groups = [private_group_with_membership, private_group_without_membership, public_group]
      end
    end

    subject(:finder) { described_class.new(current_user, params) }

    context 'when the project does not exist' do
      let(:params) { { project_id: non_existing_record_id } }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { finder.execute }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the user is not authorized to see the project' do
      let(:params) { { project_id: private_project.id } }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { finder.execute }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when a project id is not provided' do
      let(:params) { {} }

      it 'returns an empty relation' do
        expect(described_class.new(user).execute).to be_empty
      end
    end

    context 'when the user is not a member of the project' do
      let(:params) { { project_id: project.id } }

      it 'returns groups invited to the project that the user can see' do
        expect(finder.execute).to contain_exactly(public_group, private_group_with_membership)
      end
    end

    context 'when the user is member with insufficient access to the project' do
      let(:current) { guest_user }
      let(:params) { { project_id: project.id } }

      it 'returns groups invited to the project that the user can see' do
        expect(finder.execute).to contain_exactly(public_group, private_group_with_membership)
      end
    end

    shared_examples_for 'private group visibility through project membership' do
      it 'returns groups invited to the project that the user can see' do
        expect(finder.execute).to contain_exactly(public_group, private_group_with_membership)
      end

      context 'when search param is provided' do
        let(:params) { super().merge(search: private_group_with_membership.name) }

        it 'returns only matching groups' do
          expect(finder.execute).to contain_exactly(private_group_with_membership)
        end
      end

      context 'and the with_project_access param is present' do
        subject(:finder) { described_class.new(current_user, params.merge(with_project_access: true)) }

        it 'returns all invited groups' do
          expect(finder.execute).to contain_exactly(
            private_group_with_membership,
            private_group_without_membership,
            public_group
          )
        end
      end
    end

    context 'and the user is a maintainer of the project' do
      let(:current_user) { maintainer_user }
      let(:params) { { project_id: project.id } }

      it_behaves_like 'private group visibility through project membership'

      context 'when the project is private' do
        let(:params) { { project_id: private_project.id } }

        it_behaves_like 'private group visibility through project membership'
      end
    end
  end
end
