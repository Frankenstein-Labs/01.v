# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ExternalAuditEventDestination, feature_category: :audit_events do
  subject(:destination) { build(:external_audit_event_destination) }

  let_it_be(:group) { create(:group) }
  let_it_be(:audit_operation) { 'event_type_filters_created' }
  let_it_be(:audit_event) { create(:audit_event, :group_event, target_group: group) }

  describe 'Associations' do
    it 'belongs to a group' do
      expect(subject.group).not_to be_nil
    end

    it { is_expected.to have_one(:namespace_filter) }
  end

  describe 'Validations' do
    it { is_expected.to have_db_column(:verification_token).of_type(:text) }
    it { is_expected.to have_many(:headers).class_name('AuditEvents::Streaming::Header') }

    context 'with headers limit' do
      before do
        stub_const('AuditEvents::CustomHttpExternallyDestinationable::MAXIMUM_HEADER_COUNT', 3)
        create_list(:audit_events_streaming_header, 3, external_audit_event_destination: subject)
      end

      it 'can have the maximum number of headers' do
        expect(subject).to be_valid
      end

      it 'can have no more than the maximum number of headers' do
        create(:audit_events_streaming_header, external_audit_event_destination: subject)

        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to contain_exactly('Headers are limited to 3 per destination')
      end
    end

    context 'for verification_token uniqueness' do
      let(:group_2) { create(:group) }

      it 'validates uniqueness scoped to namespace' do
        create(:external_audit_event_destination, group: group, verification_token: 'token123456789012345')
        destination2 = build(:external_audit_event_destination, group: group,
          verification_token: 'token123456789012345')

        expect(destination2).not_to be_valid
        expect(destination2.errors[:verification_token]).to include('has already been taken')
      end

      it 'allows same token in different namespaces' do
        create(:external_audit_event_destination, group: group, verification_token: 'token123456789012345')
        destination = build(:external_audit_event_destination, group: group_2,
          verification_token: 'token123456789012345')

        expect(destination).to be_valid
      end
    end

    context 'for destination_url' do
      let_it_be(:group_2) { create(:group) }

      it 'does not create destination with same url for a group' do
        create(:external_audit_event_destination, destination_url: 'http://example.com', group: group)
        destination = build(:external_audit_event_destination, destination_url: 'http://example.com', group: group)

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages).to include('Destination url has already been taken')
      end

      it 'creates destination with same url for different groups' do
        create(:external_audit_event_destination, destination_url: 'http://example.com', group: group)
        destination = build(:external_audit_event_destination, destination_url: 'http://example.com', group: group_2)

        expect(destination).to be_valid
      end
    end

    it 'validates uniqueness of name scoped to namespace' do
      create(:external_audit_event_destination, name: 'Test Destination', group: group)
      destination = build(:external_audit_event_destination, name: 'Test Destination', group: group)

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Name has already been taken')
    end
  end

  describe '#headers_hash' do
    subject { destination.headers_hash }

    context "when destination has 2 headers" do
      before do
        create(:audit_events_streaming_header, external_audit_event_destination: destination, key: 'X-GitLab-Hello')
        create(:audit_events_streaming_header, external_audit_event_destination: destination, key: 'X-GitLab-World')
        create(:audit_events_streaming_header, external_audit_event_destination: destination, key: 'X-GitLab-Inactive',
          active: false)
      end

      it 'return active headers' do
        is_expected.to eq({ 'X-GitLab-Hello' => 'bar',
                            'X-GitLab-World' => 'bar',
                            'X-Gitlab-Event-Streaming-Token' => destination.verification_token })
      end
    end

    it 'must have a unique destination_url', :aggregate_failures do
      create(:external_audit_event_destination, destination_url: 'http://example.com/1', group: group)
      dup = build(:external_audit_event_destination, destination_url: 'http://example.com/1', group: group)

      expect(dup).to be_invalid
      expect(dup.errors.full_messages).to include('Destination url has already been taken')
    end

    it 'must not have any parents', :aggregate_failures do
      destination = build(:external_audit_event_destination, group: create(:group, :nested))

      expect(destination).to be_invalid
      expect(destination.errors.full_messages).to include('Group must not be a subgroup')
    end
  end

  it_behaves_like 'includes Limitable concern' do
    subject { build(:external_audit_event_destination, group: create(:group)) }
  end

  it_behaves_like 'includes CustomHttpExternallyDestinationable concern' do
    subject(:destination) { build(:external_audit_event_destination, group: create(:group)) }

    subject(:destination_without_verification_token) do
      create(:external_audit_event_destination, verification_token: nil)
    end

    let_it_be(:destination_with_filters_of_given_type) { create(:external_audit_event_destination) }
    let_it_be(:filter1) do
      create(:audit_events_streaming_event_type_filter,
        external_audit_event_destination: destination_with_filters_of_given_type,
        audit_event_type: 'event_type_filters_created')
    end

    let_it_be(:filter2) do
      create(:audit_events_streaming_event_type_filter,
        external_audit_event_destination: destination_with_filters_of_given_type,
        audit_event_type: 'event_type_filters_deleted')
    end

    let_it_be(:destination_with_filters) { create(:external_audit_event_destination) }
    let!(:filter3) do
      create(:audit_events_streaming_event_type_filter,
        external_audit_event_destination: destination_with_filters,
        audit_event_type: 'event_type_filters_deleted')
    end
  end

  it_behaves_like 'includes ExternallyCommonDestinationable concern' do
    let(:model_factory_name) { :external_audit_event_destination }
  end

  it_behaves_like 'includes GroupStreamDestinationMappable concern',
    let(:model_factory_name) { :external_audit_event_destination }

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :external_audit_event_destination }
  end

  describe '#allowed_to_stream?' do
    context 'with namespace filter' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:sibling_subgroup) { create(:group, parent: group) }
      let_it_be(:sub_subgroup) { create(:group, parent: subgroup) }
      let_it_be(:project) { create(:project, group: subgroup) }

      let(:destination_with_group_filter) { build(:external_audit_event_destination, group: group) }
      let(:destination_with_project_filter) { build(:external_audit_event_destination, group: group) }
      let(:destination_without_namespace_filter) { build(:external_audit_event_destination, group: group) }

      let!(:group_filter) do
        build(:audit_events_streaming_http_namespace_filter, namespace: subgroup,
          external_audit_event_destination: destination_with_group_filter)
      end

      let!(:project_filter) do
        build(:audit_events_streaming_http_namespace_filter, namespace: project.project_namespace,
          external_audit_event_destination: destination_with_project_filter)
      end

      let(:top_level_group_audit_event) { build(:audit_event, :group_event, target_group: group) }
      let(:group_audit_event) { build(:audit_event, :group_event, target_group: subgroup) }
      let(:sibling_group_audit_event) { build(:audit_event, :group_event, target_group: sibling_subgroup) }
      let(:sub_subgroup_audit_event) { build(:audit_event, :group_event, target_group: sub_subgroup) }
      let(:project_audit_event) { build(:audit_event, :project_event, target_project: project) }
      let(:other_project_audit_event) do
        create(:audit_event, :project_event,
          target_project: create(:project, group: sibling_subgroup))
      end

      where(:destination_object, :audit_event, :result) do
        ref(:destination_with_group_filter)          | ref(:top_level_group_audit_event) | false
        ref(:destination_with_group_filter)          | ref(:sibling_group_audit_event)   | false
        ref(:destination_with_group_filter)          | ref(:group_audit_event)           | true
        ref(:destination_with_group_filter)          | ref(:sub_subgroup_audit_event)    | true
        ref(:destination_with_group_filter)          | ref(:project_audit_event)         | true

        ref(:destination_with_project_filter)          | ref(:top_level_group_audit_event) | false
        ref(:destination_with_project_filter)          | ref(:group_audit_event) | false
        ref(:destination_with_project_filter)          | ref(:other_project_audit_event) | false
        ref(:destination_with_project_filter)          | ref(:project_audit_event) | true
      end

      with_them do
        it { expect(destination_object.allowed_to_stream?(nil, audit_event)).to eq(result) }
      end

      context 'when event type filter with given event type exists' do
        before do
          create(:audit_events_streaming_event_type_filter,
            external_audit_event_destination: destination_with_group_filter,
            audit_event_type: 'event_type_filters_created')
        end

        it do
          expect(destination_with_group_filter
                      .allowed_to_stream?('event_type_filters_created', group_audit_event)).to be(true)
        end
      end

      context 'with event filters' do
        it_behaves_like 'allowed_to_stream?' do
          let_it_be(:destination_with_filters_of_given_type) { create(:external_audit_event_destination, group: group) }

          let_it_be(:filter1) do
            create(:audit_events_streaming_event_type_filter,
              external_audit_event_destination: destination_with_filters_of_given_type,
              audit_event_type: 'event_type_filters_created')
          end

          let_it_be(:filter2) do
            create(:audit_events_streaming_event_type_filter,
              external_audit_event_destination: destination_with_filters_of_given_type,
              audit_event_type: 'event_type_filters_deleted')
          end

          let_it_be(:destination_with_filters) { create(:external_audit_event_destination, group: group) }
          let!(:filter3) do
            create(:audit_events_streaming_event_type_filter,
              external_audit_event_destination: destination_with_filters,
              audit_event_type: 'event_type_filters_deleted')
          end

          let!(:group_filter1) do
            build(:audit_events_streaming_http_namespace_filter, namespace: group,
              external_audit_event_destination: destination_with_filters_of_given_type)
          end

          let!(:group_filter2) do
            build(:audit_events_streaming_http_namespace_filter, namespace: group,
              external_audit_event_destination: destination_with_filters)
          end
        end
      end
    end
  end

  describe '#audit_details' do
    it "equals to the destination url" do
      expect(destination.audit_details).to eq(destination.destination_url)
    end
  end
end
