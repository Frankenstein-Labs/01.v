# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::QueueNonBillableToBillableService, :aggregate_failures, feature_category: :seat_cost_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:non_billable_member_role) { create(:member_role, :instance, :non_billable) }
  let_it_be(:billable_member_role) { create(:member_role, :instance, :billable) }
  let_it_be(:users_with_membership) { create_list(:user, 2) }
  let(:existing_members) { source.members_and_requesters.where(user_id: users_with_membership).to_a }

  let(:params) { { access_level: Gitlab::Access::MAINTAINER } }
  let(:source) { group }
  let(:users) { users_with_membership }
  let(:members) { existing_members }
  let(:emails) { [] }
  let(:users_by_emails) { {} }
  let(:membership_source) { source }

  subject(:create_service) do
    params.merge!(
      source: source,
      members: members,
      users: users,
      emails: emails,
      users_by_emails: users_by_emails
    )

    described_class.new(current_user: current_user, params: params).execute
  end

  shared_examples 'returns success without queuing' do
    it 'returns success' do
      response = create_service

      expect(response.success?).to eq(true)
      expect(response.payload[:billable_members].count).to eq(2) if members.present?
      expect(response.payload[:billable_users].count).to eq(2) if users.present?
    end
  end

  shared_examples 'when no promotion to billable it does not queue users' do |with_membership_scenarios|
    using RSpec::Parameterized::TableSyntax
    where(:user_type, :new_access_level, :member_role_id, :custom_role_feature_enabled?) do
      :non_admin | nil                         | nil           | true
      :non_admin | nil                         | :non_billable | true
      :non_admin | nil                         | :billable     | false
      :non_admin | ::Gitlab::Access::GUEST     | :billable     | false
      :non_admin | nil                         | :invalid      | true
      :non_admin | ::Gitlab::Access::GUEST     | nil           | true
      :non_admin | ::Gitlab::Access::GUEST     | :non_billable | true
      :non_admin | ::Gitlab::Access::GUEST     | :invalid      | true
      # all scenarios that passed for nonadmin but with admin
      :admin     | nil                         | :billable     | true
      :admin     | ::Gitlab::Access::DEVELOPER | nil           | true
      :admin     | ::Gitlab::Access::GUEST     | :billable     | true
      :admin     | ::Gitlab::Access::DEVELOPER | :non_billable | true
      :admin     | ::Gitlab::Access::DEVELOPER | :billable     | true
    end

    with_them do
      before do
        allow(current_user).to receive(:can_admin_all_resources?).and_return(true) if user_type == :admin
        allow(License).to receive(:feature_available?).and_call_original
        allow(License).to receive(:feature_available?).with(:custom_roles).and_return(custom_role_feature_enabled?)
        params.merge!(
          access_level: new_access_level,
          member_role_id: get_member_role
        )
      end

      if with_membership_scenarios
        context 'with two non-billable members' do
          before do
            add_non_billable_members(users_with_membership, membership_source)
          end

          it_behaves_like 'returns success without queuing'
        end

        context 'with one billable and one non-billable member' do
          before do
            membership_source.add_guest(users_with_membership.first)
            membership_source.add_developer(users_with_membership.second)
          end

          it_behaves_like 'returns success without queuing'
        end

        context 'with two billable members' do
          before do
            add_billable_members(users_with_membership, membership_source)
          end

          it_behaves_like 'returns success without queuing'
        end
      else
        context 'with new users to the system' do
          it_behaves_like 'returns success without queuing'
        end
      end
    end
  end

  shared_examples 'when promotion to billable it queues non-billable users' do |with_membership_scenarios|
    using RSpec::Parameterized::TableSyntax
    where(:new_access_level, :member_role_id) do
      nil                         | :billable
      ::Gitlab::Access::DEVELOPER | nil
      ::Gitlab::Access::GUEST     | :billable
      ::Gitlab::Access::DEVELOPER | :non_billable
      ::Gitlab::Access::DEVELOPER | :billable
    end

    with_them do
      before do
        params.merge!(
          access_level: new_access_level,
          member_role_id: get_member_role
        )
      end

      if with_membership_scenarios
        context 'with two non-billable members' do
          before do
            add_non_billable_members(users_with_membership, membership_source)
          end

          it 'queues both users' do
            response = nil
            expect do
              response = create_service
            end.to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }.by(2)

            expect(response.payload[:non_billable_to_billable_members].count).to eq(2)
            expect(response.payload[:queued_member_approvals].count).to eq(2)
            expect(response.payload[:billable_members]).to be_empty
            expect(response.payload[:billable_users]).to be_empty
            expect(response.success?).to eq(true)
          end
        end

        context 'with one billable and one non-billable member' do
          before do
            membership_source.add_guest(users_with_membership.first)
            membership_source.add_developer(users_with_membership.second)
          end

          it 'queues one and returns one' do
            response = nil
            expect do
              response = create_service
            end.to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }.by(1)

            expect(response.payload[:non_billable_to_billable_members].count).to eq(1)
            expect(response.payload[:queued_member_approvals].count).to eq(1)
            expect(response.payload[:billable_members].count).to eq(1) if members.present?
            expect(response.payload[:billable_users].count).to eq(1) if users.present?
            expect(response.success?).to eq(true)
          end
        end

        context 'with two billable members' do
          before do
            add_billable_members(users_with_membership, membership_source)
          end

          it_behaves_like 'returns success without queuing'
        end
      else
        context 'with new users to the system' do
          it 'queues both users' do
            response = nil
            expect do
              response = create_service
            end.to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }.by(2)

            expect(response.payload[:non_billable_to_billable_members].count).to eq(2)
            expect(response.payload[:queued_member_approvals].count).to eq(2)
            expect(response.payload[:billable_members]).to be_empty
            expect(response.payload[:billable_users]).to be_empty
            expect(response.success?).to eq(true)
          end
        end
      end
    end
  end

  shared_examples 'promotion management feature for various membership scenarios' do
    before do
      source.add_owner(current_user)
    end

    context 'when feature is disabled' do
      it_behaves_like 'returns success without queuing'
    end

    context 'when feature is enabled' do
      context 'when setting is disabled' do
        it_behaves_like 'returns success without queuing'
      end

      context 'when setting is enabled' do
        before do
          stub_application_setting(enable_member_promotion_management: true)
          allow(License).to receive(:current).and_return(license)
        end

        context 'when subscription plan is not Ultimate' do
          let(:existing_members) { nil }
          let(:license) { create(:license, plan: License::STARTER_PLAN) }

          before do
            add_non_billable_members(users_with_membership, membership_source)
          end

          it_behaves_like 'returns success without queuing'
        end

        context 'when subscription plan is Ultimate' do
          let(:license) { ultimate_license }

          context 'when existing member of the source is promoted' do
            context 'when only members list is passed (update flow)' do
              let(:users) { nil }

              it_behaves_like 'when promotion to billable it queues non-billable users', true
              it_behaves_like 'when no promotion to billable it does not queue users', true
            end

            context 'when only users list is passed (invite flow)' do
              before do
                params[:existing_members] = existing_members.index_by(&:user_id) || {}
              end

              let(:members) { nil }

              it_behaves_like 'when promotion to billable it queues non-billable users', true
              it_behaves_like 'when no promotion to billable it does not queue users', true
            end
          end

          context 'when new users are invited' do
            let(:users) { create_list(:user, 2) }
            let(:existing_members) { nil }

            context 'when user with no membership in the system is invited' do
              it_behaves_like 'when promotion to billable it queues non-billable users', false
              it_behaves_like 'when no promotion to billable it does not queue users', false
            end

            context 'when user already a member in other source is invited to a new source' do
              let(:membership_source) { another_source }
              let(:users_with_membership) { users }

              it_behaves_like 'when promotion to billable it queues non-billable users', true
              it_behaves_like 'when no promotion to billable it does not queue users', true
            end
          end

          context 'when MemberApproval raises ActiveRecord::RecordInvalid' do
            before do
              add_non_billable_members(users_with_membership, source)
              allow(::GitlabSubscriptions::MemberManagement::MemberApproval)
                .to receive(:create_or_update_pending_approval)
                      .and_raise(
                        ActiveRecord::RecordInvalid
                      )
            end

            it 'returns error' do
              response = create_service
              expect(response.error?).to eq(true)
              expect(response.message).to eq('Invalid record while enqueuing users for approval')
              expect(response.payload[:users]).to match_array(users)
              expect(response.payload[:billable_users]).to be_empty
              expect(response.payload[:non_billable_to_billable_members].count).to eq(2)
            end
          end

          context 'when email is passed' do
            let(:members) { [] }
            let(:billable_users) do
              user = create(:user)
              add_billable_members([user], source)

              [user]
            end

            let(:non_billable_users) do
              user = create(:user)
              add_non_billable_members([user], source)

              [user]
            end

            let(:new_user) { [create(:user)] }

            let(:users_by_emails) do
              email_users.index_by { |user| user.email.downcase }
            end

            let(:emails) { email_users.map(&:email) }

            context 'with email of different case' do
              let(:emails) { email_users.map(&:email).map(&:upcase) }
              let(:users) { [] }

              context 'with non billable user' do
                let(:email_users) { non_billable_users }

                it 'queues all email list users' do
                  expect { create_service }.to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }.by(1)
                  expect(create_service.payload[:emails_not_queued_for_approval]).to be_empty
                end
              end

              context 'with billable user' do
                let(:email_users) { billable_users }

                it 'returns emails as emails_not_queued_for_approval' do
                  expect { create_service }.not_to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }
                  expect(create_service.payload[:emails_not_queued_for_approval]).to match_array(emails)
                end
              end

              context 'with invited user email' do
                let(:emails) { ["test@Test.com"] }
                let(:users_by_emails) { { "test@test.com": nil } }

                it 'returns email as emails_not_queued_for_approval' do
                  expect { create_service }.not_to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }
                  expect(create_service.payload[:emails_not_queued_for_approval]).to match_array(emails)
                end
              end
            end

            context 'with various billable and non-billable combinations' do
              context 'with non billable user in email list and billable user in user list' do
                let(:users) { billable_users }
                let(:email_users) { non_billable_users }

                it 'queues all email list users' do
                  expect { create_service }.to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }.by(1)

                  expect(
                    create_service.payload[:non_billable_to_billable_members].map(&:user)
                  ).to match_array(users_by_emails.values)
                  expect(create_service.payload[:emails_not_queued_for_approval]).to be_empty
                end

                it 'returns the users list users as billable' do
                  expect(create_service.payload[:billable_members]).to be_empty
                  expect(create_service.payload[:billable_users]).to match_array(users)
                end
              end

              context 'with non billable user in users list and billable user in email list' do
                let(:users) { non_billable_users }
                let(:email_users) { billable_users }

                it 'queues the user list' do
                  expect { create_service }.to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }.by(1)

                  expect(create_service.payload[:non_billable_to_billable_members].map(&:user)).to match_array(users)
                  expect(create_service.payload[:billable_members]).to be_empty
                  expect(create_service.payload[:billable_users]).to be_empty
                end

                it 'returns emails as emails_not_queued_for_approval' do
                  expect(create_service.payload[:emails_not_queued_for_approval]).to match_array(emails)
                end
              end

              context 'with non billable user in both users and email list' do
                let(:users) { [users_with_membership.first] }
                let(:email_users) { [users_with_membership.second] }

                before do
                  add_non_billable_members(users_with_membership, source)
                end

                it 'queues both users list and email list users' do
                  expect { create_service }.to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }.by(2)

                  expect(
                    create_service.payload[:non_billable_to_billable_members].map(&:user)
                  ).to match_array(users_with_membership)
                end

                it 'does not return any billable users' do
                  expect(create_service.payload[:billable_members]).to be_empty
                  expect(create_service.payload[:billable_users]).to be_empty
                end

                it 'does not return anything in emails_not_queued_for_approval' do
                  expect(create_service.payload[:emails_not_queued_for_approval]).to be_empty
                end
              end

              context 'with billable user in both users and email list' do
                let(:users) { [users_with_membership.first] }
                let(:email_users) { [users_with_membership.second] }

                before do
                  add_billable_members(users_with_membership, source)
                end

                it 'does not queue any users' do
                  expect { create_service }.not_to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }
                end

                it 'returns both users list and email list' do
                  expect(create_service.payload[:billable_members]).to be_empty
                  expect(create_service.payload[:billable_users]).to match_array(users)
                  expect(create_service.payload[:emails_not_queued_for_approval]).to match_array(emails)
                end
              end

              context 'with new user in email list' do
                let(:users) { [] }
                let(:email_users) { new_user }

                it 'queues all email list users' do
                  expect { create_service }.to change {
                    ::GitlabSubscriptions::MemberManagement::MemberApproval.count
                  }.by(1)

                  expect(
                    create_service.payload[:non_billable_to_billable_members].map(&:user)
                  ).to match_array(users_by_emails.values)
                  expect(create_service.payload[:emails_not_queued_for_approval]).to be_empty
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#initialize' do
    context 'when source is invalid' do
      it 'raises an ArgumentError' do
        params.merge!(
          source: create(:user_namespace),
          users: create_list(:user, 1)
        )

        expect do
          described_class.new(current_user: current_user, params: params)
        end.to raise_error(ArgumentError, 'Invalid source. Source should be either Group or Project.')
      end
    end

    context 'when neither users nor members nor emails are provided' do
      let(:source) { group }

      it 'raises an ArgumentError' do
        params[:source] = source

        expect do
          described_class.new(current_user: current_user, params: params)
        end.to raise_error(ArgumentError, 'Invalid argument. Either members or users or email should be passed.')
      end
    end
  end

  describe '#execute' do
    context 'when source is group' do
      let(:source) { group }
      let(:another_source) { other_group }

      it_behaves_like 'promotion management feature for various membership scenarios'
    end

    context 'when source is project' do
      let(:source) { project }
      let(:another_source) { other_project }

      it_behaves_like 'promotion management feature for various membership scenarios'
    end
  end

  private

  def get_member_role
    case member_role_id
    when :billable then billable_member_role.id
    when :non_billable then non_billable_member_role.id
    when :invalid then non_existing_record_id
    end
  end

  def add_non_billable_members(usrs, src)
    usrs.each do |user|
      src.add_guest(user)
    end
  end

  def add_billable_members(usrs, src)
    usrs.each do |user|
      src.add_developer(user)
    end
  end
end
