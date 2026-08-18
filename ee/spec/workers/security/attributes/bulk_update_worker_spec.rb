# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::BulkUpdateWorker, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:root_namespace) { namespace.root_ancestor }
  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:project_ids) { [project1.id, project2.id] }
  let(:attribute_ids) { [attribute1.id, attribute2.id] }
  let(:mode) { 'ADD' }
  let(:user_id) { user.id }

  subject(:worker) { described_class.new }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#perform' do
    before_all do
      namespace.add_maintainer(user)
    end

    context 'when user exists' do
      it 'processes all projects' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new).twice.and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end

      it 'calls UpdateProjectAttributesService with correct parameters for ADD mode' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project1,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project2,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end

      context 'with REMOVE mode' do
        let(:mode) { 'REMOVE' }

        it 'calls UpdateProjectAttributesService with correct parameters for REMOVE mode' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project1,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project2,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with REPLACE mode' do
        let(:mode) { 'REPLACE' }

        before do
          # Add some existing attributes to the projects using proper associations
          create(:project_to_security_attribute,
            project: project1,
            security_attribute: attribute1,
            traversal_ids: project1.namespace.traversal_ids)
          create(:project_to_security_attribute,
            project: project2,
            security_attribute: attribute2,
            traversal_ids: project2.namespace.traversal_ids)
        end

        it 'calls UpdateProjectAttributesService with correct parameters for REPLACE mode' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project1,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: attribute_ids,
                  remove_attribute_ids: [attribute1.id]
                }
              }
            )
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project2,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: attribute_ids,
                  remove_attribute_ids: [attribute2.id]
                }
              }
            )
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end

        context 'when project has soft deleted attributes' do
          let(:deleted_attribute) do
            create(:security_attribute, security_category: category, name: 'Deleted',
              namespace: root_namespace, deleted_at: Time.current)
          end

          before do
            # Add a soft-deleted attribute association to project1
            create(:project_to_security_attribute,
              project: project1,
              security_attribute: deleted_attribute,
              traversal_ids: project1.namespace.traversal_ids)
          end

          it 'excludes soft deleted attributes from removal list' do
            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project1,
                current_user: user,
                params: {
                  attributes: {
                    add_attribute_ids: attribute_ids,
                    remove_attribute_ids: [attribute1.id]
                  }
                }
              )
              .and_call_original

            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project2,
                current_user: user,
                params: {
                  attributes: {
                    add_attribute_ids: attribute_ids,
                    remove_attribute_ids: [attribute2.id]
                  }
                }
              )
              .and_call_original

            worker.perform(project_ids, attribute_ids, mode, user_id)
          end
        end
      end

      context 'when user lacks permissions for a project' do
        let_it_be(:unauthorized_project) { create(:project) }
        let(:project_ids) { [project1.id, unauthorized_project.id] }

        it 'skips unauthorized projects' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(hash_including(project: project1))
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)
            .with(hash_including(project: unauthorized_project))

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when service raises an error' do
        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_raise(StandardError, 'Service error')
          end
        end

        it 'tracks the exception and continues processing' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              {
                project_id: project1.id,
                attribute_ids: attribute_ids,
                mode: mode,
                user_id: user_id
              }
            )

          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              {
                project_id: project2.id,
                attribute_ids: attribute_ids,
                mode: mode,
                user_id: user_id
              }
            )

          expect { worker.perform(project_ids, attribute_ids, mode, user_id) }.not_to raise_error
        end
      end

      context 'when project does not exist' do
        let(:project_ids) { [project1.id, non_existing_record_id] }

        it 'processes only existing projects' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(hash_including(project: project1))
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end
    end

    context 'when user does not exist' do
      let(:user_id) { non_existing_record_id }

      it 'returns early without processing' do
        expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end
    end
  end
end
