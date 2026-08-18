# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::UpdateProjectAttributesService, feature_category: :security_asset_inventories do
  let_it_be(:root_namespace) { create(:group, name: 'Root Namespace Group') }
  let_it_be(:other_namespace) { create(:group, name: 'Other Namespace Group') }
  let_it_be(:user) { create(:user) }

  let_it_be(:single_selection_category) do
    create(:security_category, namespace: root_namespace, name: 'Single Selection Category', multiple_selection: false)
  end

  let_it_be(:multiple_selection_category) do
    create(:security_category, namespace: root_namespace, name: 'Multiple Selection Category', multiple_selection: true)
  end

  let_it_be(:attribute1) do
    create(:security_attribute, namespace: root_namespace, name: 'Single Attribute 1',
      security_category: single_selection_category)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, namespace: root_namespace, name: 'Single Attribute 2',
      security_category: single_selection_category)
  end

  let_it_be(:multiple_selection_attribute1) do
    create(:security_attribute, namespace: root_namespace, name: 'Multiple Attribute 1',
      security_category: multiple_selection_category)
  end

  let_it_be(:multiple_selection_attribute2) do
    create(:security_attribute, namespace: root_namespace, name: 'Multiple Attribute 2',
      security_category: multiple_selection_category)
  end

  let_it_be(:other_category) do
    create(:security_category, namespace: root_namespace, name: 'Other Category')
  end

  let_it_be(:other_attribute) do
    create(:security_attribute, namespace: root_namespace, name: 'Other Attribute', security_category: other_category)
  end

  let_it_be_with_reload(:project) { create(:project, namespace: root_namespace) }

  let(:add_attribute_ids) { [attribute1.id, other_attribute.id] }
  let(:remove_attribute_ids) { [] }
  let(:params) do
    {
      attributes: {
        add_attribute_ids: add_attribute_ids,
        remove_attribute_ids: remove_attribute_ids
      }
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }
  let(:execute) { service.execute }

  before do
    stub_licensed_features(security_attributes: true)
  end

  def expect_error_with_payload_errors(*errors)
    expect(execute).to be_error
    expect(execute.message).to eq('Invalid attributes')
    expect(execute.payload[:errors]).to match_array(errors)
  end

  shared_examples 'does not change project security attributes count' do
    it 'does not add any attributes' do
      expect { execute }.not_to change { project.security_attributes.count }
    end
  end

  context 'when user does not have permissions' do
    it 'returns unauthorized error' do
      expect(execute).to be_error
      expect(execute).to eq(described_class::UnauthorizedError)
    end
  end

  shared_examples 'update project security attributes' do
    context 'when exceeding processing attribute limit' do
      let(:add_attribute_ids) { (1..described_class::MAX_ATTRIBUTES).to_a }
      let(:remove_attribute_ids) { (described_class::MAX_ATTRIBUTES..described_class::MAX_ATTRIBUTES + 5).to_a }

      it 'returns error' do
        expect(execute).to be_error
        expect(execute.message).to eq('Too many attributes')
        expect(execute.payload[:errors])
          .to include("Cannot process more than #{described_class::MAX_ATTRIBUTES} attributes at once")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when exceeding project attribute limit' do
      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      before do
        stub_const("#{described_class}::MAX_PROJECT_ATTRIBUTES", 1)
        create(:project_to_security_attribute, project: project, security_attribute: attribute2)
      end

      it 'returns error' do
        expect(execute).to be_error
        expect(execute.message).to eq('Too many attributes')
        expect(execute.payload[:errors])
          .to include("Cannot exceed #{described_class::MAX_PROJECT_ATTRIBUTES} attributes per project")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when exceeding both processing and project limits' do
      let(:add_attribute_ids) { [attribute1.id, other_attribute.id] }
      let(:remove_attribute_ids) { [attribute1.id + 1] }

      before do
        stub_const("#{described_class}::MAX_PROJECT_ATTRIBUTES", 1)
        stub_const("#{described_class}::MAX_ATTRIBUTES", 2)
        create(:project_to_security_attribute, project: project, security_attribute: attribute2)
      end

      it 'returns error with both limit violations' do
        expect(execute).to be_error
        expect(execute.message).to eq('Too many attributes')
        expect(execute.payload[:errors]).to include(
          "Cannot process more than 2 attributes at once",
          "Cannot exceed 1 attributes per project"
        )
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when trying to add multiple attributes that would exceed project limit' do
      let(:add_attribute_ids) { [attribute1.id, other_attribute.id] }
      let(:remove_attribute_ids) { [] }

      before do
        stub_const("#{described_class}::MAX_PROJECT_ATTRIBUTES", 1)
      end

      it 'returns error before processing attributes' do
        expect(execute).to be_error
        expect(execute.message).to eq('Too many attributes')
        expect(execute.payload[:errors]).to include("Cannot exceed 1 attributes per project")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when adding valid attributes' do
      it 'adds attributes to the project' do
        expect { execute }.to change { project.security_attributes.count }.by(2)
        expect(project.security_attributes).to include(attribute1, other_attribute)
      end

      it 'returns success with counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(2)
        expect(execute.payload[:removed_count]).to eq(0)
      end

      it 'creates audit events for attached attributes', :request_store do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          author: user,
          scope: project,
          target: project,
          name: 'security_attribute_attached_to_project'
        }).and_call_original

        expect(::Gitlab::Audit::EventQueue).to receive(:push).twice.with(
          satisfy { |event| security_attribute_attached_event?(event) }
        ).and_call_original

        expect { execute }.to change { AuditEventReader.count }.by(2)

        audit_events = AuditEventReader.last(2)
        audit_events.each do |audit_event|
          expect(audit_event.details).to include(
            event_name: 'security_attribute_attached_to_project',
            author_name: user.name,
            project_name: project.name,
            project_path: project.full_path
          )
        end

        expect(audit_events.first.details).to include(
          custom_message: "Attached security attribute #{attribute1.name} to project #{project.name}",
          attribute_name: attribute1.name,
          category_name: single_selection_category.name
        )

        expect(audit_events.second.details).to include(
          custom_message: "Attached security attribute #{other_attribute.name} to project #{project.name}",
          attribute_name: other_attribute.name,
          category_name: other_category.name
        )
      end
    end

    context 'when removing attributes' do
      let(:add_attribute_ids) { [] }
      let(:remove_attribute_ids) { [other_attribute.id] }

      before do
        create(:project_to_security_attribute, project: project, security_attribute: other_attribute)
      end

      it 'removes attributes from the project' do
        expect { execute }.to change { project.security_attributes.count }.by(-1)
        expect(project.security_attributes).not_to include(other_attribute)
      end

      it 'returns success with counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(0)
        expect(execute.payload[:removed_count]).to eq(1)
      end

      it 'creates audit event for detached attribute', :request_store do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          author: user,
          scope: project,
          target: project,
          name: 'security_attribute_detached_from_project'
        }).and_call_original

        expect(::Gitlab::Audit::EventQueue).to receive(:push).once.with(
          satisfy { |event| security_attribute_detached_event?(event) }
        ).and_call_original

        expect { execute }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_attribute_detached_from_project',
          author_name: user.name,
          custom_message: "Detached security attribute #{other_attribute.name} from project #{project.name}",
          attribute_name: other_attribute.name,
          category_name: other_category.name,
          project_name: project.name,
          project_path: project.full_path
        )
      end
    end

    context 'when attribute does not exist' do
      let(:add_attribute_ids) { [non_existing_record_id] }
      let(:remove_attribute_ids) { [] }

      it 'returns error with id' do
        expect_error_with_payload_errors("Security attribute not found: #{non_existing_record_id}")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when attribute is soft deleted' do
      let(:deleted_attribute) do
        create(:security_attribute, namespace: root_namespace, name: 'Deleted Attribute',
          security_category: other_category, deleted_at: Time.current)
      end

      let(:add_attribute_ids) { [deleted_attribute.id] }
      let(:remove_attribute_ids) { [] }

      it 'returns error indicating attribute not found' do
        expect_error_with_payload_errors("Security attribute not found: #{deleted_attribute.id}")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when project has soft deleted attribute associations' do
      let(:deleted_attribute) do
        create(:security_attribute, namespace: root_namespace, name: 'Deleted Attribute',
          security_category: other_category, deleted_at: Time.current)
      end

      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      before do
        # Create association with soft-deleted attribute
        create(:project_to_security_attribute, project: project, security_attribute: deleted_attribute)
      end

      it 'does not count soft deleted attributes towards project limit' do
        stub_const("#{described_class}::MAX_PROJECT_ATTRIBUTES", 1)

        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(1)
      end

      it 'does not include soft deleted attributes in existing attributes' do
        execute
        expect(project.security_attributes.not_deleted).to include(attribute1)
        expect(project.security_attributes.not_deleted).not_to include(deleted_attribute)
      end
    end

    context 'when multiple attributes are missing' do
      let(:add_attribute_ids) { [non_existing_record_id, non_existing_record_id + 1] }
      let(:remove_attribute_ids) { [] }

      it 'returns error with all missing ids' do
        expect_error_with_payload_errors(*add_attribute_ids.map { |id| "Security attribute not found: #{id}" })
      end
    end

    context 'when removing non-existent attribute' do
      let(:add_attribute_ids) { [] }
      let(:remove_attribute_ids) { [non_existing_record_id] }

      it 'returns success with no deleted relations' do
        expect(execute).to be_success
        expect(execute.payload[:removed_count]).to eq(0)
      end
    end

    context 'with single selection category' do
      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      it 'allows one attribute from the category' do
        expect(execute).to be_success
        expect(project.security_attributes).to include(attribute1)
      end

      context 'when project already has attribute from category' do
        let(:add_attribute_ids) { [attribute2.id] }

        before do
          create(:project_to_security_attribute, project: project, security_attribute: attribute1)
        end

        it 'returns error with category id' do
          expect_error_with_payload_errors(
            "Cannot add multiple attributes from the same category #{single_selection_category.id}")
        end
      end

      context 'when adding multiple attributes from same category in one request' do
        let(:add_attribute_ids) { [attribute1.id, attribute2.id] }

        it 'returns error for second attribute with category id' do
          expect_error_with_payload_errors(
            "Cannot add multiple attributes from the same category #{single_selection_category.id}")
        end

        it_behaves_like 'does not change project security attributes count'
      end
    end

    context 'with multiple selection category' do
      let(:add_attribute_ids) { [multiple_selection_attribute1.id, multiple_selection_attribute2.id] }
      let(:remove_attribute_ids) { [] }

      it 'allows multiple attributes from the same category' do
        expect { execute }.to change { project.security_attributes.count }.by(2)
        expect(project.security_attributes).to include(multiple_selection_attribute1, multiple_selection_attribute2)
      end
    end

    context 'when attribute is from different namespace' do
      let(:wrong_namespace_attribute) do
        create(:security_attribute, namespace: other_namespace, name: 'Wrong Namespace Attribute',
          security_category: other_category)
      end

      let(:add_attribute_ids) { [wrong_namespace_attribute.id] }
      let(:remove_attribute_ids) { [] }

      it 'returns error' do
        expect(execute).to be_error
        expect(execute.message).to eq("Failed to update security attributes")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'with mixed valid and invalid attributes' do
      let(:add_attribute_ids) { [attribute1.id, non_existing_record_id] }
      let(:remove_attribute_ids) { [] }

      it 'returns error with missing ids' do
        expect_error_with_payload_errors("Security attribute not found: #{non_existing_record_id}")
      end

      it_behaves_like 'does not change project security attributes count'
    end

    context 'when attribute is already associated' do
      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      before do
        create(:project_to_security_attribute,
          project: project,
          security_attribute: attribute1)
      end

      it 'silently skips already associated attributes' do
        expect { execute }.not_to change { project.security_attributes.count }
        expect(execute).to be_success
      end
    end

    context 'when mixing add and remove operations' do
      let(:existing_attribute) do
        create(:security_attribute, namespace: root_namespace, name: 'Existing Attribute',
          security_category: other_category)
      end

      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [existing_attribute.id] }

      before do
        create(:project_to_security_attribute, project: project, security_attribute: existing_attribute)
      end

      it 'performs both operations' do
        execute
        expect(project.security_attributes).to include(attribute1)
        expect(project.security_attributes).not_to include(existing_attribute)
      end

      it 'returns correct counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(1)
        expect(execute.payload[:removed_count]).to eq(1)
      end
    end

    context 'when same attribute appears in both add and remove lists' do
      let(:add_attribute_ids) { [attribute1.id, other_attribute.id] }
      let(:remove_attribute_ids) { [attribute1.id] }

      before do
        create(:project_to_security_attribute, project: project, security_attribute: attribute1)
      end

      it 'keeps existing attributes and adds new ones' do
        expect { execute }.to change { project.security_attributes.count }.by(1)
        expect(project.security_attributes).to include(attribute1, other_attribute)
      end

      it 'returns success with correct counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(1)
        expect(execute.payload[:removed_count]).to eq(0)
      end
    end

    context 'when multiple attributes appear in both add and remove lists' do
      let(:add_attribute_ids) { [attribute1.id, other_attribute.id, multiple_selection_attribute1.id] }
      let(:remove_attribute_ids) { [attribute1.id, other_attribute.id] }

      before do
        create(:project_to_security_attribute, project: project, security_attribute: attribute1)
        create(:project_to_security_attribute, project: project, security_attribute: other_attribute)
      end

      it 'keeps existing attributes and adds new ones' do
        expect { execute }.to change { project.security_attributes.count }.by(1)
        expect(project.security_attributes).to include(attribute1, other_attribute, multiple_selection_attribute1)
      end

      it 'returns success with correct counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(1)
        expect(execute.payload[:removed_count]).to eq(0)
      end
    end

    context 'when validation fails' do
      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      before do
        allow_next_instance_of(Security::ProjectToSecurityAttribute) do |instance|
          allow(instance).to receive(:valid?).and_return(false)
        end
      end

      it 'returns error with attribute id' do
        expect(execute).to be_error
        expect(execute.message).to eq("Failed to update security attributes")
      end
    end

    context 'when no attributes are specified for adding or removing' do
      let(:add_attribute_ids) { [] }
      let(:remove_attribute_ids) { [] }

      it 'returns success with zero counts' do
        expect(execute).to be_success
        expect(execute.payload[:added_count]).to eq(0)
        expect(execute.payload[:removed_count]).to eq(0)
      end

      it 'does not change project attributes' do
        expect { execute }.not_to change { project.security_attributes.count }
      end
    end

    context 'when database validation fails during transaction' do
      let(:add_attribute_ids) { [attribute1.id] }
      let(:remove_attribute_ids) { [] }

      before do
        allow(Security::ProjectToSecurityAttribute).to receive(:bulk_insert!)
          .and_raise(ActiveRecord::RecordInvalid.new(Security::ProjectToSecurityAttribute.new))
      end

      it 'returns error about failed update' do
        expect(execute).to be_error
        expect(execute.message).to eq('Failed to update security attributes')
      end

      it_behaves_like 'does not change project security attributes count'
    end
  end

  context 'when user is an owner' do
    before_all do
      root_namespace.add_owner(user)
    end

    it_behaves_like 'update project security attributes'
  end

  context 'when user is a maintainer' do
    before_all do
      root_namespace.add_maintainer(user)
    end

    it_behaves_like 'update project security attributes'
  end

  context 'when user is a security manager' do
    before_all do
      root_namespace.add_security_manager(user)
    end

    it_behaves_like 'update project security attributes'
  end

  def security_attribute_attached_event?(event)
    event.is_a?(AuditEvent) && event.details[:event_name] == 'security_attribute_attached_to_project'
  end

  def security_attribute_detached_event?(event)
    event.is_a?(AuditEvent) && event.details[:event_name] == 'security_attribute_detached_from_project'
  end
end
