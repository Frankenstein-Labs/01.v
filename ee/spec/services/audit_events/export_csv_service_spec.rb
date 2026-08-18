# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ExportCsvService, feature_category: :audit_events do
  let_it_be(:author) { create(:user, name: "Ru'by McRüb\"Face") }
  let_it_be(:audit_event) do
    create(:audit_events_project_audit_event,
      project_id: 678,
      entity_path: 'gitlab-org/awesome-rails',
      target_details: "special package ¯\\_(ツ)_/¯",
      user: author,
      ip_address: IPAddr.new('192.168.0.1'),
      details: {
        custom_message: "Removed package ,./;'[]\-=",
        target_id: 3, target_type: 'Package'
      },
      created_at: Time.zone.parse('2020-02-20T12:00:00Z'))
  end

  let(:params) do
    {
      entity_type: 'Project',
      entity_id: 678,
      created_before: '2020-03-01',
      created_after: '2020-01-01',
      author_id: author.id
    }
  end

  let(:export_csv_service) { described_class.new(params) }

  subject(:csv) { CSV.parse(export_csv_service.csv_data.to_a.join, headers: true) }

  it 'includes the appropriate headers' do
    expect(csv.headers).to eq([
      'ID', 'Author ID', 'Author Name', 'Author Email',
      'Entity ID', 'Entity Type', 'Entity Path',
      'Target ID', 'Target Type', 'Target Details',
      'Action', 'IP Address', 'Created At (UTC)'
    ])
  end

  context 'data verification' do
    specify 'ID' do
      expect(csv[0]['ID']).to eq(audit_event.id.to_s)
    end

    specify 'Author ID' do
      expect(csv[0]['Author ID']).to eq(author.id.to_s)
    end

    specify 'Author Name' do
      expect(csv[0]['Author Name']).to eq("Ru'by McRüb\"Face")
    end

    specify 'Author Email' do
      expect(csv[0]['Author Email']).to eq(author.email)
    end

    specify 'Entity ID' do
      expect(csv[0]['Entity ID']).to eq('678')
    end

    specify 'Entity Type' do
      expect(csv[0]['Entity Type']).to eq('Project')
    end

    specify 'Entity Path' do
      expect(csv[0]['Entity Path']).to eq('gitlab-org/awesome-rails')
    end

    specify 'Target ID' do
      expect(csv[0]['Target ID']).to eq('3')
    end

    specify 'Target Type' do
      expect(csv[0]['Target Type']).to eq('Package')
    end

    specify 'Target Details' do
      expect(csv[0]['Target Details']).to eq("special package ¯\\_(ツ)_/¯")
    end

    specify 'Action' do
      expect(csv[0]['Action']).to eq("Removed package ,./;'[]\-=")
    end

    specify 'IP Address' do
      expect(csv[0]['IP Address']).to eq('192.168.0.1')
    end

    specify 'Created At (UTC)' do
      expect(csv[0]['Created At (UTC)']).to eq('2020-02-20T12:00:00Z')
    end
  end

  context 'when the events span more than one page' do
    let(:params) { super().tap { |params| params.delete(:author_id) } }

    let_it_be(:later_event) do
      create(:audit_events_project_audit_event,
        project_id: 678,
        user: author,
        created_at: Time.zone.parse('2020-02-21T12:00:00Z'))
    end

    let_it_be(:earlier_event) do
      create(:audit_events_project_audit_event,
        project_id: 678,
        user: author,
        created_at: Time.zone.parse('2020-02-19T12:00:00Z'))
    end

    before do
      # Force the keyset cursor loop to make several round trips.
      stub_const("#{described_class}::BATCH_SIZE", 1)
    end

    it 'exports every event exactly once, newest first' do
      expect(csv.map { |row| row['ID'] })
        .to eq([earlier_event, later_event, audit_event].sort_by(&:id).reverse.map { |event| event.id.to_s })
    end
  end

  context 'when events belong to different scopes' do
    let_it_be(:group_event) do
      create(:audit_events_group_audit_event, user: author, created_at: Time.zone.parse('2020-02-20T12:00:00Z'))
    end

    # This factory keeps the author in a transient, because `user` is the audited
    # user on AuditEvents::UserAuditEvent rather than the author.
    let_it_be(:user_event) do
      create(:audit_events_user_audit_event, author: author, created_at: Time.zone.parse('2020-02-20T12:00:00Z'))
    end

    let(:params) { { created_before: '2020-03-01', created_after: '2020-01-01' } }

    it 'includes events from every scoped table' do
      expect(csv.map { |row| row['ID'] })
        .to include(audit_event.id.to_s, group_event.id.to_s, user_event.id.to_s)
    end

    it 'reports the scope of each event' do
      entity_types = csv.filter_map { |row| row['Entity Type'] }

      expect(entity_types).to include('Project', 'Group', 'User')
    end
  end

  context 'when the author user has been deleted' do
    subject(:csv) { CSV.parse(export_csv_service.csv_data.to_a.join, headers: true) }

    let(:params) { super().tap { |params| params.delete(:author_id) } }

    before do
      user = create(:user, name: "foo")
      create(:audit_events_project_audit_event,
        project_id: 678,
        author_id: user.id,
        created_at: Time.zone.parse('2020-02-20T12:00:00Z'))

      user.delete
    end

    it "returns CSV without error" do
      expect { csv.headers }.not_to raise_error
    end
  end

  context 'with preloads' do
    let(:params) { super().tap { |params| params.delete(:author_id) } }

    it 'preloads fields to avoid N+1 queries' do
      described_class.new(params).csv_data.to_a # warm-up
      control = ActiveRecord::QueryRecorder.new { described_class.new(params).csv_data.to_a }

      create(:audit_events_project_audit_event,
        project_id: 678,
        author_id: create(:user).id,
        created_at: Time.zone.parse('2020-02-20T12:00:00Z'))

      expect { described_class.new(params).csv_data.to_a }.not_to exceed_query_limit(control)
    end
  end
end
