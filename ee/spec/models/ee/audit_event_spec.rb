# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvent, feature_category: :audit_events do
  describe 'relationships' do
    it { is_expected.to belong_to(:user).with_foreign_key('author_id') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:author_id) }
    it { is_expected.to validate_presence_of(:entity_id) }
    it { is_expected.to validate_presence_of(:entity_type) }
  end

  describe 'callbacks' do
    context 'truncate_fields' do
      shared_examples 'a truncated field' do
        context 'when values are provided' do
          using RSpec::Parameterized::TableSyntax

          where(:database_column, :details_value, :expected_value) do
            :long  | nil    | :truncated
            :short | nil    | :short
            nil    | :long  | :truncated
            nil    | :short | :short
            :long  | :short | :truncated
          end

          with_them do
            let(:values) do
              {
                long: 'a' * (field_limit + 1),
                short: 'a' * field_limit,
                truncated: ('a' * (field_limit - 3)) + '...'
              }
            end

            let(:audit_event) do
              create(:audit_event,
                field_name => values[database_column],
                details: { field_name => values[details_value] }
              )
            end

            it 'sets both values to be the same', :aggregate_failures do
              expect(audit_event.send(field_name)).to eq(values[expected_value])
              expect(audit_event.details[field_name]).to eq(values[expected_value])
            end
          end
        end

        context 'when values are not provided' do
          let(:audit_event) do
            create(:audit_event, field_name => nil, details: {})
          end

          it 'does not set', :aggregate_failures do
            expect(audit_event.send(field_name)).to be_nil
            expect(audit_event.details).not_to have_key(field_name)
          end
        end
      end

      context 'entity_path' do
        let(:field_name) { :entity_path }
        let(:field_limit) { 5_500 }

        it_behaves_like 'a truncated field'
      end

      context 'target_details' do
        let(:field_name) { :target_details }
        let(:field_limit) { 5_500 }

        it_behaves_like 'a truncated field'
      end
    end
  end

  describe '#stream_to_external_destinations' do
    context 'feature is licensed' do
      shared_examples 'successful audit event stream' do
        context 'when the group has no destinations' do
          it 'enqueues no workers' do
            expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

            event.stream_to_external_destinations
          end
        end

        context 'when the group has destination' do
          before do
            create(:audit_events_group_external_streaming_destination, group: group)
          end

          it 'enqueues one worker' do
            expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).once

            event.stream_to_external_destinations
          end
        end
      end

      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'entity is a group' do
        let_it_be(:group) { create(:group) }
        let_it_be(:event) { create(:audit_event, :group_event, target_group: group) }

        it_behaves_like 'successful audit event stream'
      end

      context 'entity is a project' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:event) { create(:audit_event, :project_event, target_project: project) }

        it_behaves_like 'successful audit event stream'
      end

      context 'when entity is not a group or project' do
        let_it_be(:event) { create(:user_audit_event) }

        it 'enqueues no workers' do
          expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

          event.stream_to_external_destinations
        end
      end

      context 'when silent mode is enabled' do
        let_it_be(:event) { create(:user_audit_event) }

        before do
          stub_application_setting(silent_mode_enabled: true)
        end

        it 'does not enqueue worker' do
          expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)
          expect(Gitlab::HTTP).not_to receive(:post)

          event.stream_to_external_destinations
        end
      end
    end

    context 'feature is unlicensed' do
      let_it_be(:event) { create(:audit_event, :group_event) }

      before do
        stub_licensed_features(external_audit_events: false)
      end

      it 'enqueues no workers' do
        expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

        event.stream_to_external_destinations
      end
    end

    context 'when instance level external destination is present' do
      let_it_be(:event) { create(:audit_event, :group_event) }

      before do
        create(:audit_events_instance_external_streaming_destination)
      end

      shared_examples 'no stream event gets created' do
        it 'enqueues no workers' do
          expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

          event.stream_to_external_destinations
        end
      end

      context 'when feature is licensed for instance' do
        before do
          stub_licensed_features(external_audit_events: true)
        end

        it 'enqueues one worker' do
          expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).once

          event.stream_to_external_destinations
        end
      end

      context 'when feature is not licensed for instance' do
        it_behaves_like 'no stream event gets created'
      end
    end

    context 'namespace logging context' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      def captured_root_namespace
        captured = nil
        allow(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async) do
          captured = ::Gitlab::ApplicationContext.current_context_attribute(:root_namespace)
        end

        event.stream_to_external_destinations

        captured
      end

      context 'for a group-scoped event' do
        let_it_be(:group) { create(:group) }
        let_it_be(:event) { create(:audit_event, :group_event, target_group: group) }

        before do
          create(:audit_events_group_external_streaming_destination, group: group)
        end

        it 'enqueues the worker within the event namespace context' do
          expect(captured_root_namespace).to eq(group.full_path)
        end
      end

      context 'for a personal-namespace project event' do
        let_it_be(:project) { create(:project, :in_user_namespace) }
        let_it_be(:event) { create(:audit_event, :project_event, target_project: project) }

        before do
          create(:audit_events_instance_external_streaming_destination)
        end

        it 'falls back to the project namespace even though root_group_entity is nil' do
          expect(event.root_group_entity).to be_nil
          expect(captured_root_namespace).to eq(project.namespace.full_path)
        end
      end

      context 'for a user-scoped event' do
        let_it_be(:event) { create(:user_audit_event) }

        before do
          create(:audit_events_instance_external_streaming_destination)
        end

        it 'sets no namespace because user events have none' do
          expect(event.streamable_namespace).to be_nil
          expect(captured_root_namespace).to be_nil
        end
      end
    end
  end

  describe '.by_entity' do
    let_it_be(:project_event_1) { create(:project_audit_event) }
    let_it_be(:project_event_2) { create(:project_audit_event) }
    let_it_be(:user_event) { create(:user_audit_event) }

    let(:entity_type) { 'Project' }
    let(:entity_id) { project_event_1.entity_id }

    subject(:event) { described_class.by_entity(entity_type, entity_id) }

    it 'returns the correct audit events' do
      expect(event).to contain_exactly(project_event_1)
    end
  end

  describe '.order_by' do
    let_it_be(:event_1) { create(:audit_event) }
    let_it_be(:event_2) { create(:audit_event) }
    let_it_be(:event_3) { create(:audit_event) }

    subject(:event) { described_class.order_by(method) }

    context 'when sort by created_at in ascending order' do
      let(:method) { 'created_asc' }

      it 'sorts results by id in ascending order' do
        expect(event).to eq([event_1, event_2, event_3])
      end
    end

    context 'when it is default' do
      let(:method) { nil }

      it 'sorts results by id in descending order' do
        expect(event).to eq([event_3, event_2, event_1])
      end
    end
  end

  describe '#author_name' do
    context 'when user exists' do
      let(:user) { create(:user, name: 'John Doe') }

      subject(:event) { described_class.new(user: user) }

      it 'returns user name' do
        expect(event.author_name).to eq 'John Doe'
      end
    end

    context 'when user does not exist anymore' do
      context 'when database contains author_name' do
        subject(:event) { described_class.new(author_id: non_existing_record_id, author_name: 'Jane Doe') }

        it 'returns author_name' do
          expect(event.author_name).to eq 'Jane Doe'
        end
      end

      context 'when details contains author_name' do
        subject(:event) { described_class.new(author_id: non_existing_record_id, details: { author_name: 'John Doe' }) }

        it 'returns author_name' do
          expect(event.author_name).to eq 'John Doe'
        end
      end

      context 'when details does not contains author_name' do
        it 'returns nil' do
          subject.details = {}

          expect(subject.author_name).to be_nil
        end
      end
    end

    context 'when authored by an unauthenticated user' do
      subject(:event) { described_class.new(author_id: -1) }

      it 'returns `An unauthenticated user`' do
        expect(subject.author_name).to eq('An unauthenticated user')
      end
    end
  end

  describe '#entity' do
    context 'when entity exists' do
      let(:user) { create(:user, name: 'John Doe') }

      subject(:event) { described_class.new(entity_id: user.id, entity_type: user.class.name) }

      it 'returns the entity object' do
        expect(event.entity).to eq user
      end
    end

    context 'when entity does not exist' do
      subject(:event) { described_class.new(entity_id: non_existing_record_id, entity_type: 'User') }

      it 'returns a NullEntity' do
        expect(event.entity).to be_a(Gitlab::Audit::NullEntity)
      end
    end

    context 'when entity is the instance' do
      let_it_be(:instance_scope) { Gitlab::Audit::InstanceScope.new }

      subject(:event) { described_class.new(entity_id: instance_scope.id, entity_type: instance_scope.class.name) }

      it 'returns a InstanceScope object' do
        expect(event.entity).to be_a(Gitlab::Audit::InstanceScope)
      end
    end
  end

  describe '#root_group_entity' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, group: group) }

    context 'when root_group_entity_id is set' do
      subject(:event) { described_class.new(root_group_entity_id: root_group.id) }

      it "return root_group_entity through root_group_entity_id" do
        expect(event.root_group_entity).to eq(root_group)
      end
    end

    context "when entity is nil" do
      subject(:event) { described_class.new(entity: nil) }

      it "return nil" do
        expect(event.root_group_entity).to be_nil
      end
    end

    context "when entity is a group" do
      subject(:event) { described_class.new(entity_id: group.id, entity_type: "Group") }

      it "return root_group and set root_group_entity_id" do
        expect(event.entity).to eq(group)
        expect(event.root_group_entity).to eq(root_group)
        expect(event.root_group_entity_id).to eq(root_group.id)
      end
    end

    context "when entity is a project" do
      subject(:event) { described_class.new(entity_id: project.id, entity_type: "Project") }

      it "return root_group and set root_group_entity_id" do
        expect(event.root_group_entity).to eq(root_group)
        expect(event.root_group_entity_id).to eq(root_group.id)
      end
    end
  end

  describe '#ip_address' do
    context 'when ip_address exists in both details hash and ip_address column' do
      subject(:event) do
        described_class.new(ip_address: '10.2.1.1', details: { ip_address: '192.168.0.1' })
      end

      it 'returns the value from ip_address column' do
        expect(event.ip_address).to eq('10.2.1.1')
      end
    end

    context 'when ip_address exists in details hash but not in ip_address column' do
      subject(:event) { described_class.new(details: { ip_address: '192.168.0.1' }) }

      it 'returns the value from details hash' do
        expect(event.ip_address).to eq('192.168.0.1')
      end
    end
  end

  describe '#entity_path' do
    context 'when entity_path exists in both details hash and entity_path column' do
      subject(:event) do
        described_class.new(entity_path: 'gitlab-org/gitlab', details: { entity_path: 'gitlab-org/gitlab-foss' })
      end

      it 'returns the value from entity_path column' do
        expect(event.entity_path).to eq('gitlab-org/gitlab')
      end
    end

    context 'when entity_path exists in details hash but not in entity_path column' do
      subject(:event) { described_class.new(details: { entity_path: 'gitlab-org/gitlab-foss' }) }

      it 'returns the value from details hash' do
        expect(event.entity_path).to eq('gitlab-org/gitlab-foss')
      end
    end
  end

  describe '#target_type' do
    context 'when target_type exists in both details hash and target_type column' do
      subject(:event) do
        described_class.new(target_type: 'Group', details: { target_type: 'Project' })
      end

      it 'returns the value from target_type column' do
        expect(event.target_type).to eq('Group')
      end
    end

    context 'when target_type exists in details hash but not in target_type column' do
      subject(:event) { described_class.new(details: { target_type: 'Project' }) }

      it 'returns the value from details hash' do
        expect(event.target_type).to eq('Project')
      end
    end
  end

  describe '#present' do
    it 'returns a presenter' do
      expect(subject.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  describe '#formatted_details' do
    subject(:event) { create(:group_audit_event, details: { change: 'membership_lock', from: false, to: true, ip_address: '127.0.0.1' }) }

    it 'includes the author\'s email' do
      expect(event.formatted_details[:author_email]).to eq(event.author.email)
    end

    it 'converts value of `to` and `from` in `details` to string' do
      expect(event.formatted_details[:to]).to eq('true')
      expect(event.formatted_details[:from]).to eq('false')
    end
  end

  describe 'author' do
    subject { event.author }

    context 'when author exists' do
      let_it_be(:event) { create(:project_audit_event) }

      it 'returns the author object' do
        expect(subject).to eq(User.find(event.author_id))
      end
    end

    context 'when author is unauthenticated' do
      let_it_be(:event) { create(:project_audit_event, :unauthenticated) }

      it 'is an unauthenticated user' do
        expect(subject).to be_a(Gitlab::Audit::UnauthenticatedAuthor)
      end
    end

    context 'when author no longer exists' do
      let_it_be(:event) { create(:project_audit_event, author_id: non_existing_record_id) }

      it 'is a deleted user' do
        expect(subject).to be_a(Gitlab::Audit::DeletedAuthor)
      end
    end
  end

  describe 'entity_is_group_or_project?' do
    subject { event.entity_is_group_or_project? }

    context 'when entity is a Group' do
      let_it_be(:event) { create(:group_audit_event) }

      it { is_expected.to be true }
    end

    context 'when entity is a Project' do
      let_it_be(:event) { create(:project_audit_event) }

      it { is_expected.to be true }
    end

    context 'when entity is an Epic' do
      let_it_be(:event) { create(:audit_event, target_type: 'Epic') }

      it { is_expected.to be false }
    end
  end

  describe '#streamable_namespace' do
    let(:audit_event) { build(:audit_event) }

    context 'when entity_type is Group' do
      let(:group) { create(:group) }
      let(:audit_event) { build(:group_audit_event, target_group: group) }

      it 'returns the entity' do
        expect(audit_event.streamable_namespace).to eq(group)
      end
    end

    context 'when entity_type is Namespaces::ProjectNamespace' do
      let(:project) { create(:project) }
      let(:project_namespace) { project.project_namespace }
      let(:audit_event) do
        build(:audit_event,
          entity_type: 'Namespaces::ProjectNamespace',
          entity_id: project_namespace.id)
      end

      before do
        allow(audit_event).to receive(:entity).and_return(project_namespace)
      end

      it 'returns the entity' do
        expect(audit_event.streamable_namespace).to eq(project_namespace)
      end
    end

    context 'when entity_type is Project' do
      let(:project) { create(:project) }
      let(:audit_event) { build(:project_audit_event, target_project: project) }

      it 'returns the project namespace when it exists' do
        expect(audit_event.streamable_namespace).to eq(project.project_namespace)
      end
    end

    context 'when entity_type is User' do
      let(:user) { create(:user) }
      let(:audit_event) { build(:user_audit_event, target_user: user) }

      it 'returns nil' do
        expect(audit_event.streamable_namespace).to be_nil
      end
    end

    context 'when entity_type is Gitlab::Audit::InstanceScope' do
      let(:audit_event) { build(:instance_audit_event) }

      context 'when target_type or target_id is missing' do
        it 'returns nil when target_type is nil' do
          audit_event.target_type = nil
          audit_event.details[:target_type] = nil
          audit_event.details[:target_id] = 1

          expect(audit_event.streamable_namespace).to be_nil
        end

        it 'returns nil when target_id is nil' do
          audit_event.target_type = 'Project'
          audit_event.details[:target_type] = 'Project'
          audit_event.details[:target_id] = nil

          expect(audit_event.streamable_namespace).to be_nil
        end
      end

      context 'when target_type is Project' do
        let(:project) { create(:project) }

        before do
          audit_event.target_type = 'Project'
          audit_event.details[:target_type] = 'Project'
          audit_event.details[:target_id] = project.id
        end

        it 'returns the project namespace' do
          expect(audit_event.streamable_namespace).to eq(project.project_namespace)
        end

        it 'returns nil when project does not exist' do
          audit_event.details[:target_id] = non_existing_record_id

          expect(audit_event.streamable_namespace).to be_nil
        end
      end

      context 'when target_type is Group' do
        let(:group) { create(:group) }

        before do
          audit_event.target_type = 'Group'
          audit_event.details[:target_type] = 'Group'
          audit_event.details[:target_id] = group.id
        end

        it 'returns the group' do
          expect(audit_event.streamable_namespace).to eq(group)
        end

        it 'returns nil when group does not exist' do
          audit_event.details[:target_id] = non_existing_record_id

          expect(audit_event.streamable_namespace).to be_nil
        end
      end

      context 'when target_type is Namespaces::ProjectNamespace' do
        let(:project) { create(:project) }
        let(:project_namespace) { project.project_namespace }

        before do
          audit_event.target_type = 'Namespaces::ProjectNamespace'
          audit_event.details[:target_type] = 'Namespaces::ProjectNamespace'
          audit_event.details[:target_id] = project_namespace.id
        end

        it 'returns the project namespace' do
          expect(audit_event.streamable_namespace).to eq(project_namespace)
        end

        it 'returns nil when project namespace does not exist' do
          audit_event.details[:target_id] = non_existing_record_id

          expect(audit_event.streamable_namespace).to be_nil
        end
      end

      context 'when target_type is unsupported' do
        before do
          audit_event.target_type = 'UnknownType'
          audit_event.details[:target_type] = 'UnknownType'
          audit_event.details[:target_id] = 1
        end

        it 'returns nil' do
          expect(audit_event.streamable_namespace).to be_nil
        end
      end
    end

    context 'when entity_type is another Namespace type' do
      let(:namespace) { create(:namespace) }
      let(:audit_event) do
        build(:audit_event,
          entity_type: 'SomeNamespaceType',
          entity_id: namespace.id)
      end

      context 'when entity is a Namespace' do
        before do
          allow(audit_event).to receive(:entity).and_return(namespace)
        end

        it 'returns entity' do
          expect(audit_event.streamable_namespace).to eq(namespace)
        end
      end

      context 'when entity is not a Namespace' do
        let(:non_namespace_entity) { build(:user) }

        before do
          allow(audit_event).to receive(:entity).and_return(non_namespace_entity)
        end

        it 'returns nil' do
          expect(audit_event.streamable_namespace).to be_nil
        end
      end
    end
  end
end
