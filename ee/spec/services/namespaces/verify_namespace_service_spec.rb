# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::VerifyNamespaceService, feature_category: :pipeline_composition do
  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }

  let_it_be(:group_project) { create(:project, group: group) }
  let_it_be(:group_project_resource) { create(:ci_catalog_resource, :published, project: group_project) }

  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be(:subgroup_project_published_resource) do
    create(:ci_catalog_resource, :published, project: subgroup_project)
  end

  let_it_be(:subgroup_public_project) { create(:project, :public, group: subgroup) }
  let_it_be(:subgroup_public_project_resource) do
    create(:ci_catalog_resource, :published, project: subgroup_public_project)
  end

  let_it_be(:another_group) { create(:group) }
  let_it_be(:another_group_private_project) { create(:project, group: another_group) }
  let_it_be(:another_group_private_project_resource) do
    create(:ci_catalog_resource, project: another_group_private_project)
  end

  let_it_be(:another_group_published_project) { create(:project, group: another_group) }
  let_it_be(:another_group_published_project_resource) do
    create(:ci_catalog_resource, :published, project: another_group_published_project)
  end

  describe '#execute' do
    context 'when namespace is not a root namespace' do
      it 'returns error' do
        response = described_class.new(subgroup, 'gitlab_maintained').execute

        expect(response.message).to eq('Input the root namespace.')
      end

      context 'when unknown verification level is being set' do
        context 'when on self-managed' do
          before do
            allow(Gitlab).to receive(:com?).and_return(false)
          end

          it 'is not valid and returns an error' do
            response = described_class.new(subgroup, 'unknown').execute

            expected_string =
              'Input the root namespace., Input a valid verification level: verified_creator_self_managed.'

            expect(response.message).to eq(expected_string)
          end
        end

        context 'when on gitlab.com' do
          before do
            allow(Gitlab).to receive(:com?).and_return(true)
          end

          it 'is not valid and returns an error' do
            response = described_class.new(subgroup, 'unknown').execute

            expected_string =
              'Input the root namespace., ' \
                'Input a valid verification level: gitlab_maintained, ' \
                'gitlab_partner_maintained, verified_creator_maintained, unverified.'

            expect(response.message).to eq(expected_string)
          end
        end
      end
    end

    context 'when a root namespace is given' do
      context 'when an unknown verification level is given' do
        context 'when on self-managed' do
          before do
            allow(Gitlab).to receive(:com?).and_return(false)
          end

          it 'returns an error' do
            response = described_class.new(group, 'unknown').execute

            expect(response.message).to eq('Input a valid verification level: verified_creator_self_managed.')
          end
        end

        context 'when on gitlab.com' do
          before do
            allow(Gitlab).to receive(:com?).and_return(true)
          end

          it 'returns an error' do
            response = described_class.new(group, 'unknown').execute

            expect(response.message).to eq('Input a valid verification level: gitlab_maintained, ' \
              'gitlab_partner_maintained, verified_creator_maintained, unverified.')
          end
        end
      end

      ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS.each_key do |level|
        context "when #{level} verification level is being set" do
          let(:verification_level) { level.to_s }

          it 'creates an instance of ::Namespaces::VerifiedNamespace' do
            expect do
              described_class.new(group, verification_level).execute
            end.to change { ::Namespaces::VerifiedNamespace.count }.by(1)
          end

          it 'updates the verification level for all catalog resources under the given namespace' do
            response = described_class.new(group, verification_level).execute

            expect(response).to be_success

            expect(group_project_resource.reload.verification_level).to eq(verification_level)
            expect(subgroup_project_published_resource.reload.verification_level).to eq(verification_level)
            expect(subgroup_public_project_resource.reload.verification_level).to eq(verification_level)

            expect(another_group_published_project_resource.reload.verification_level).to eq('unverified')
          end
        end
      end
    end

    context 'when updating an existing verified namespace' do
      context 'when on self-managed' do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        let(:verification_level) { 'verified_creator_self_managed' }

        it 'does not change the verified namespace' do
          ::Namespaces::VerifiedNamespace.find_or_create_by!(namespace: group,
            verification_level: 'verified_creator_self_managed')

          expect do
            described_class.new(group, verification_level).execute
          end.not_to change { ::Namespaces::VerifiedNamespace.count }
        end

        it 'cascades the verification level to the catalog resources' do
          ::Namespaces::VerifiedNamespace.find_or_create_by!(namespace: group,
            verification_level: 'verified_creator_self_managed')

          response = described_class.new(group, verification_level).execute

          expect(response).to be_success

          expect(group_project_resource.reload.verification_level).to eq(verification_level)
          expect(subgroup_project_published_resource.reload.verification_level).to eq(verification_level)
          expect(subgroup_public_project_resource.reload.verification_level).to eq(verification_level)

          expect(another_group_published_project_resource.reload.verification_level).to eq('unverified')
        end
      end

      context 'when on gitlab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        let(:new_verification_level) { 'gitlab_partner_maintained' }

        it 'does not change the verified namespace' do
          ::Namespaces::VerifiedNamespace.find_or_create_by!(namespace: group,
            verification_level: 'gitlab_maintained')

          expect do
            described_class.new(group, new_verification_level).execute
          end.not_to change { ::Namespaces::VerifiedNamespace.count }
        end

        it 'updates verification level on the existing verified namespace' do
          verified_namespace =
            ::Namespaces::VerifiedNamespace.find_or_create_by!(namespace: group,
              verification_level: 'gitlab_maintained')

          described_class.new(group, new_verification_level).execute

          expect(verified_namespace.reload.verification_level).to eq(new_verification_level)
        end

        it 'cascades the verification level to the catalog resources' do
          ::Namespaces::VerifiedNamespace.find_or_create_by!(namespace: group,
            verification_level: 'gitlab_maintained')

          response = described_class.new(group, new_verification_level).execute

          expect(response).to be_success

          expect(group_project_resource.reload.verification_level).to eq(new_verification_level)
          expect(subgroup_project_published_resource.reload.verification_level).to eq(new_verification_level)
          expect(subgroup_public_project_resource.reload.verification_level).to eq(new_verification_level)

          expect(another_group_published_project_resource.reload.verification_level).to eq('unverified')
        end
      end
    end
  end
end
