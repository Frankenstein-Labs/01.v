# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::SeatAssignments::SyncService, feature_category: :seat_cost_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:root_namespace) { create(:group) }

    context 'when on saas', :saas do
      it 'returns success response' do
        result = described_class.new([user.id], root_namespace).execute

        expect(result).to be_success
      end

      context 'when the user has a membership in the namespace hierarchy' do
        before_all do
          root_namespace.add_developer(user)
        end

        context 'when the user has an existing seat assignment' do
          let!(:existing_seat_assignment) do
            create(:gitlab_subscription_seat_assignment,
              user: user,
              namespace: root_namespace,
              organization_id: root_namespace.organization_id
            )
          end

          it 'does not create a new seat assignment' do
            expect { described_class.new([user.id], root_namespace).execute }
              .not_to change { GitlabSubscriptions::SeatAssignment.count }
          end

          it 'updates the existing seat assignment' do
            existing_seat_assignment.update!(seat_type: nil)

            described_class.new([user.id], root_namespace).execute

            expect(existing_seat_assignment.reload).to have_attributes(
              user: user,
              seat_type: 'base',
              namespace: root_namespace,
              organization_id: root_namespace.organization_id
            )
          end
        end

        context 'when the user does not have a seat assignment' do
          it 'creates a seat assignment' do
            expect { described_class.new([user.id], root_namespace).execute }
              .to change { GitlabSubscriptions::SeatAssignment.count }.by(1)
          end
        end
      end

      context 'when the user has no memberships in the namespace hierarchy' do
        context 'with an existing seat' do
          before do
            create(:gitlab_subscription_seat_assignment,
              user: user,
              namespace: root_namespace,
              organization_id: root_namespace.organization_id
            )
          end

          it 'removes the seat' do
            expect { described_class.new([user.id], root_namespace).execute }
              .to change { GitlabSubscriptions::SeatAssignment.count }.by(-1)
          end

          it 'returns success response' do
            expect(described_class.new([user.id], root_namespace).execute).to be_success
          end
        end

        context 'with seats in different namespace hierarchies' do
          let(:other_root_namespace) { create(:group) }
          let!(:other_seat_assignment) do
            create(:gitlab_subscription_seat_assignment,
              user: user,
              namespace: other_root_namespace,
              organization_id: other_root_namespace.organization_id
            )
          end

          before do
            create(:gitlab_subscription_seat_assignment,
              user: user,
              namespace: root_namespace,
              organization_id: root_namespace.organization_id
            )
          end

          it 'only removes the seat within the provided namespace hierarchy' do
            described_class.new([user.id], root_namespace).execute

            expect(GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(root_namespace, user)).to be_nil
            expect(GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(other_root_namespace, user))
              .to eq(other_seat_assignment)
          end
        end

        it 'does not create a seat' do
          expect { described_class.new([user.id], root_namespace).execute }
            .not_to change { GitlabSubscriptions::SeatAssignment.count }
        end
      end

      context 'with multiple users' do
        let_it_be(:user_2) { create(:user) }

        it 'returns success response' do
          result = described_class.new([user.id, user_2.id], root_namespace).execute

          expect(result).to be_success
        end

        it 'handles seat assignments' do
          root_namespace.add_developer(user)
          create(:gitlab_subscription_seat_assignment, user: user, namespace: root_namespace)

          create(:gitlab_subscription_seat_assignment, user: user_2, namespace: root_namespace)

          user_3 = create(:user, organization: root_namespace.organization)
          subgroup = create(:group, parent: root_namespace)

          subgroup.add_maintainer(user_3)

          user_4 = create(:user)

          described_class.new([user.id, user_2.id, user_3.id, user_4.id], root_namespace).execute

          expect(GitlabSubscriptions::SeatAssignment.all.pluck(:user_id)).to contain_exactly(
            user.id,
            user_3.id
          )
        end
      end

      context 'when user_ids contains nil values' do
        it 'handles seat assignments for valid user ids only' do
          root_namespace.add_developer(user)

          expect { described_class.new([user.id, nil], root_namespace).execute }
            .to change { GitlabSubscriptions::SeatAssignment.count }.by(1)
        end
      end

      context 'when duplicate user ids are provided' do
        it 'handles seat assignment for the deduplicated user once' do
          root_namespace.add_developer(user)
          service = described_class.new([user.id, user.id], root_namespace)

          expect(service).to receive(:upsert_seat_assignments).with({ user.id => :base }).once
          expect(service).not_to receive(:remove_seat_assignments)

          service.execute
        end
      end

      context 'when user_ids is empty' do
        it 'returns success response' do
          expect(described_class.new([], root_namespace).execute).to be_success
        end
      end

      context 'when the root namespace is not a group namespace' do
        let(:user_namespace) { create(:user_namespace) }

        it 'returns error response' do
          result = described_class.new([user.id], user_namespace).execute

          expect(result).to be_error
          expect(result.message).to eq(
            'Seat assignments unavailable for user namespaces on GitLab.com'
          )
        end
      end
    end

    context 'when on self-managed' do
      it 'returns nil' do
        expect(described_class.new([user.id], root_namespace).execute).to be_nil
      end
    end
  end
end
