# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::MemberRoles::AssignService, feature_category: :permissions do
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:current_user) { create(:admin) }

  let(:member_role_param) { admin_role_1 }
  let(:params) { { user: user, member_role: member_role_param } }

  subject(:assign_member_role) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  shared_examples 'assigns roles correctly' do
    context 'when current user is not an admin', :enable_admin_mode do
      before do
        current_user.update!(admin: false)
      end

      it 'returns an error' do
        expect(assign_member_role).to be_error
        expect(assign_member_role.message).to include('Forbidden')
      end
    end

    context 'when current user is an admin', :enable_admin_mode do
      context 'when custom_roles feature is not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'returns an error' do
          expect(assign_member_role).to be_error
          expect(assign_member_role.message).to include('custom_roles licensed feature must be available')
        end
      end

      context 'when member_role param is present' do
        context 'when no admin role is assigned to the user' do
          it 'creates a new record' do
            expect { assign_member_role }.to change { join_record_klass.count }.by(1)
          end

          it 'creates the correct associations' do
            expect { assign_member_role }.to change {
              join_record_klass.exists?(user: user, member_role: admin_role_1)
            }.from(false).to(true)
          end

          it 'returns success' do
            response = assign_member_role

            expect(response).to be_success
            expect(response.payload[:user_member_role]).to eq(join_record_klass.last)
          end

          context 'when the user is an admin' do
            let_it_be(:user) { create(:admin) }

            it 'does not create a new record' do
              expect { assign_member_role }.not_to change { join_record_klass.where(user: user).count }
            end
          end

          include_examples 'audit event logging' do
            let(:licensed_features_to_stub) { { custom_roles: true } }
            let(:operation) { assign_member_role }

            let(:fail_condition!) do
              allow_next_instance_of(join_record_klass) do |record|
                allow(record).to receive(:valid?).and_return(false)
              end
            end

            let(:attributes) do
              {
                author_id: current_user.id,
                entity_id: user.id,
                entity_type: 'User',
                details: {
                  event_name: 'custom_admin_role_assigned_to_user',
                  author_name: current_user.name,
                  author_class: 'User',
                  target_id: admin_role_1.id,
                  target_type: admin_role_1.class.name,
                  target_details: admin_role_1.name,
                  custom_message: 'Custom admin role assigned to user'
                }
              }
            end
          end
        end

        context 'when the user has another admin role assigned' do
          let!(:user_member_role) { create(join_factory_klass_name, member_role: admin_role_1, user: user) }

          let(:member_role_param) { admin_role_2 }

          it 'updates the record' do
            expect { assign_member_role }.to change { user_member_role.reload.member_role }
              .from(admin_role_1).to(admin_role_2)
          end

          context 'when the user is an admin' do
            let_it_be(:user) { create(:admin) }

            it 'deletes the existing record' do
              expect { assign_member_role }.to change { join_record_klass.where(user: user).count }.to(0)
            end
          end

          it 'returns success' do
            response = assign_member_role

            expect(response).to be_success
            expect(response.payload[:user_member_role]).to eq(user_member_role)
          end

          include_examples 'audit event logging' do
            let(:licensed_features_to_stub) { { custom_roles: true } }
            let(:operation) { assign_member_role }

            let(:fail_condition!) do
              allow_next_found_instance_of(join_record_klass) do |record|
                allow(record).to receive(:valid?).and_return(false)
              end
            end

            let(:attributes) do
              {
                author_id: current_user.id,
                entity_id: user.id,
                entity_type: 'User',
                details: {
                  event_name: 'custom_admin_role_assigned_to_user',
                  author_name: current_user.name,
                  author_class: 'User',
                  target_id: admin_role_2.id,
                  target_type: admin_role_2.class.name,
                  target_details: admin_role_2.name,
                  custom_message: 'Custom admin role assigned to user'
                }
              }
            end
          end
        end
      end

      context 'when member_role param is not provided' do
        let(:member_role_param) { nil }

        context 'when a user member role already exists' do
          let!(:user_member_role) { create(join_factory_klass_name, member_role: admin_role_1, user: user) }

          it 'deletes the existing record' do
            expect { assign_member_role }.to change { join_record_klass.count }.by(-1)
          end

          it 'assigns the correct value' do
            expect { assign_member_role }.to change { join_record_klass.where(user: user) }.to([])
          end

          it 'returns success' do
            response = assign_member_role

            expect(response).to be_success
            expect(response.payload[:user_member_role]).to be_nil
          end

          include_examples 'audit event logging' do
            let(:licensed_features_to_stub) { { custom_roles: true } }
            let(:operation) { assign_member_role }

            let(:fail_condition!) do
              allow_next_found_instance_of(join_record_klass) do |record|
                allow(record).to receive(:destroy).and_return(false)
              end
            end

            let(:attributes) do
              {
                author_id: current_user.id,
                entity_id: user.id,
                entity_type: 'User',
                details: {
                  event_name: 'custom_admin_role_unassigned_from_user',
                  author_name: current_user.name,
                  author_class: 'User',
                  target_id: admin_role_1.id,
                  target_type: admin_role_1.class.name,
                  target_details: admin_role_1.name,
                  custom_message: 'Custom admin role unassigned from user'
                }
              }
            end
          end
        end

        context 'when a user member role does not exist' do
          it 'does not delete any records' do
            expect { assign_member_role }.not_to change { join_record_klass.count }
          end

          it 'returns success' do
            response = assign_member_role

            expect(response).to be_success
            expect(response.payload[:user_member_role]).to be_nil
          end

          it 'does not log an audit event' do
            expect(Gitlab::Audit::Auditor).not_to receive(:audit)
          end
        end
      end

      context 'when the provided member role is not an admin role' do
        let_it_be(:member_role) { create(:member_role, name: 'Standard role') }

        let(:member_role_param) { member_role }

        it 'does not create a new user member role relation' do
          expect { assign_member_role }.not_to change { join_record_klass.count }
        end

        it 'returns error' do
          expect(assign_member_role).to be_error
          expect(assign_member_role.message).to include('Only admin custom roles can be assigned directly to a user.')
        end
      end
    end
  end

  context 'with member admin roles' do
    let_it_be(:join_record_klass) { ::Users::UserMemberRole }
    let_it_be(:join_factory_klass_name) { :user_member_role }
    let_it_be(:admin_role_1) { create(:member_role, :admin, name: 'Admin role 1') }
    let_it_be(:admin_role_2) { create(:member_role, :admin, name: 'Admin role 2') }

    before do
      stub_feature_flags(extract_admin_roles_from_member_roles: false)
    end

    it_behaves_like 'assigns roles correctly'
  end

  context 'with admin roles' do
    let_it_be(:join_record_klass) { ::Authz::UserAdminRole }
    let_it_be(:join_factory_klass_name) { :user_admin_role }
    let_it_be(:admin_role_1) { create(:admin_role, name: 'Admin role 1') }
    let_it_be(:admin_role_2) { create(:admin_role, name: 'Admin role 2') }

    before do
      stub_feature_flags(extract_admin_roles_from_member_roles: true)
    end

    it_behaves_like 'assigns roles correctly'
  end
end
