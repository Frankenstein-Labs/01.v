# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SshCertificates::FindService, feature_category: :source_code_management do
  let_it_be(:ssh_certificate) { create(:group_ssh_certificate) }
  let_it_be(:group) { ssh_certificate.group }
  let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group, developer_of: group) }

  let(:ca_fingerprint) { ssh_certificate.fingerprint }
  let(:user_identifier) { user.username }
  let(:service) { described_class.new(ca_fingerprint, user_identifier) }

  before do
    stub_licensed_features(ssh_certificates: true)
  end

  describe '#execute' do
    it 'returns successful response with payload' do
      response = service.execute

      expect(response).to be_success
      expect(response.payload).to eq({ user: user, group: group })
    end

    context 'when a certificate not found' do
      let(:ca_fingerprint) { 'does not exist' }

      it 'returns not found error' do
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('Certificate Not Found')
        expect(response.reason).to eq(:not_found)
      end
    end

    context 'when ssh_certificates feature is not available' do
      it 'returns forbidden error' do
        stub_licensed_features(ssh_certificates: false)

        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('Feature is not available')
        expect(response.reason).to eq(:forbidden)
      end
    end

    context 'when a user is not found' do
      let(:user_identifier) { 'does not exist' }

      it 'returns not found error' do
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('User Not Found')
        expect(response.reason).to eq(:not_found)
      end
    end

    context 'when a user is not a member' do
      let_it_be_with_reload(:user) { create(:user) }

      it 'returns not found error' do
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('User Not Found')
        expect(response.reason).to eq(:not_found)
      end
    end

    context 'when a user is not an enterprise user' do
      let_it_be_with_reload(:user) { create(:user) }

      it 'returns not found error' do
        group.add_developer(user)

        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('Not an Enterprise User of the group')
        expect(response.reason).to eq(:forbidden)
      end
    end

    context 'when user is an invited member of a group' do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be(:invited_member) { create(:group_member, :invited, group: group, user: user) }

      it 'returns not found error' do
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('User Not Found')
        expect(response.reason).to eq(:not_found)
      end
    end

    context 'when user has minimal group access and developer project access' do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:group_member) { create(:group_member, :minimal_access, group: group, user: user) }

      before_all do
        project.add_developer(user)
        user.user_detail.update!(enterprise_group: group)
      end

      it 'returns successful response with payload' do
        response = service.execute

        # verify context is correct
        expect(user.project_members.find_by(source: project).access_level).to eq(Gitlab::Access::DEVELOPER)
        expect(group.all_group_members.with_user(user)).to be_one
        expect(group.all_group_members.with_user(user).first.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)

        expect(response).to be_success
        expect(response.payload).to eq({ user: user, group: group })
      end
    end

    context 'when namespace_id is provided' do
      let(:service) { described_class.new(ca_fingerprint, user_identifier, namespace_id: group.id) }

      it 'returns successful response with payload' do
        response = service.execute

        expect(response).to be_success
        expect(response.payload).to eq({ user: user, group: group })
      end

      context 'when namespace_id does not match any certificate' do
        let(:service) { described_class.new(ca_fingerprint, user_identifier, namespace_id: non_existing_record_id) }

        it 'returns not found error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Certificate Not Found')
          expect(response.reason).to eq(:not_found)
        end
      end
    end

    context 'when multiple groups share the same CA fingerprint' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_user) { create(:enterprise_user, enterprise_group: other_group, developer_of: other_group) }
      let_it_be(:other_certificate) { create(:group_ssh_certificate, group: other_group, key: ssh_certificate.key) }

      context 'without namespace_id' do
        let(:user_identifier) { other_user.username }

        it 'finds the correct certificate by matching the user to the group' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: other_user, group: other_group })
        end
      end

      context 'with namespace_id' do
        let(:service) { described_class.new(ca_fingerprint, other_user.username, namespace_id: other_group.id) }

        it 'finds the certificate scoped to the namespace' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: other_user, group: other_group })
        end
      end
    end
  end
end
