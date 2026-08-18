# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Needed in specs

RSpec.describe Gitlab::BackgroundMigration::CreateMissingExternalLinksForVulnerabilities, feature_category: :vulnerability_management do
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:project_settings) { table(:project_settings) }
  let(:users) { table(:users) }
  let(:scanners) { table(:vulnerability_scanners, database: :sec) }
  let(:vulnerability_external_issue_links) { table(:vulnerability_external_issue_links, database: :sec) }
  let(:vulnerabilities) { table(:vulnerabilities, database: :sec) }
  let(:vulnerability_findings) { table(:vulnerability_occurrences, database: :sec) }
  let(:vulnerability_identifiers) { table(:vulnerability_identifiers, database: :sec) }
  let(:integrations) { table(:integrations) }
  let(:jira_tracker_data_table) { table(:jira_tracker_data) }

  let!(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }
  let!(:namespace) do
    namespaces.create!(name: "test-1", path: "test-1", owner_id: user.id, organization_id: organization.id)
  end

  let!(:project_setting) { project_settings.create!(project_id: project.id, has_vulnerabilities: true) }
  let!(:scanner) { scanners.create!(project_id: project.id, external_id: 'external_id', name: 'Test Scanner') }

  let(:vulnerability_1) { create_vulnerability(title: 'vulnerability 1', finding_id: create_finding.id) }
  let(:vulnerability_2) { create_vulnerability(title: 'vulnerability 2', finding_id: create_finding.id) }
  let(:vulnerability_3) { create_vulnerability(title: 'vulnerability 3', finding_id: create_finding.id) }

  let!(:vulnerability_external_issue_link) do
    vulnerability_external_issue_links.create!({
      author_id: user.id,
      vulnerability_id: vulnerability_3.id,
      project_id: project.id,
      link_type: 1, # created
      external_type: 1, # jira
      external_project_key: "TEST",
      external_issue_key: 10001
    })
  end

  let!(:jira_integration) do
    integrations.create!(id: 1, type_new: 'Integrations::Jira', active: true, project_id: project.id)
  end

  let!(:migration_attrs) do
    {
      start_id: project_settings.minimum(:project_id),
      end_id: project_settings.maximum(:project_id),
      batch_table: :project_settings,
      batch_column: :project_id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let(:server_info_results) { { 'deploymentType' => 'Cloud' } }
  let(:client_info_results) { { 'accountType' => 'atlassian' } }

  before do
    jira_tracker_data = Class.new(ApplicationRecord) do
      include Gitlab::EncryptedAttribute

      self.table_name = 'jira_tracker_data'

      def self.encryption_options
        {
          key: :db_key_base_32,
          encode: true,
          mode: :per_attribute_iv,
          algorithm: 'aes-256-gcm'
        }
      end

      attr_encrypted :url, encryption_options
      attr_encrypted :api_url, encryption_options
      attr_encrypted :username, encryption_options
      attr_encrypted :password, encryption_options
    end

    stub_const('JiraTrackerData', jira_tracker_data)

    WebMock.stub_request(:get, /serverInfo/).to_return(body: server_info_results.to_json)
    WebMock.stub_request(:get, /myself/).to_return(body: client_info_results.to_json)
  end

  describe "#perform" do
    subject(:migration) { described_class.new(**migration_attrs).perform }

    let!(:jira_tracker_data) do
      JiraTrackerData.create!(
        id: 1,
        integration_id: jira_integration.id,
        url: "https://test-domain.atlassian.net",
        username: "test",
        password: "test",
        jira_auth_type: 1
      )
    end

    context "when there are missing external links" do
      # Create one jira issue each for vuilnerability_1 and vulnerability_2
      let!(:jira_issues) do
        [
          create_jira_issue({
            "id" => "1",
            "fields" => {
              "description" => "Issue created from vulnerability https://gitlab.com/-/security/vulnerabilities/#{vulnerability_1.id}",
              "project" => {
                "key" => "TEST"
              }
            }
          }),
          create_jira_issue({
            "id" => "2",
            "fields" => {
              "description" => "Issue created from vulnerability https://gitlab.com/-/security/vulnerabilities/#{vulnerability_2.id}",
              "project" => {
                "key" => "TEST"
              }
            }
          })
        ]
      end

      let!(:service_response) do
        ServiceResponse.success(payload: {
          issues: jira_issues,
          is_last: true
        })
      end

      it "creates missing external issue links" do
        expect_next_instance_of(described_class::JiraIssuesFinder) do |instance|
          expect(instance).to receive(:execute).and_return(service_response)
        end

        expect { migration }.to change { vulnerability_external_issue_links.count }.by(2)
        expect(vulnerability_external_issue_links.where(vulnerability_id: vulnerability_1.id).count).to be 1
        expect(vulnerability_external_issue_links.where(vulnerability_id: vulnerability_2.id).count).to be 1
      end
    end

    context "when there are no missing external links" do
      let!(:jira_issues) do
        [
          # jira issue for already existing external link
          create_jira_issue({
            "id" => "3",
            "fields" => {
              "description" => "Issue created from vulnerability https://gitlab.com/-/security/vulnerabilities/#{vulnerability_3.id}",
              "project" => {
                "key" => "TEST"
              }
            }
          }),
          # non vulnerability related issues on the project
          create_jira_issue({
            "id" => "4",
            "fields" => {
              "description" => "Issue not created from a vulnerability",
              "project" => {
                "key" => "TEST"
              }
            }
          }),
          create_jira_issue({
            "id" => "5",
            "fields" => {
              "description" => "Issue created from a vulnerability but without a vulnerability id",
              "project" => {
                "key" => "TEST"
              }
            }
          })
        ]
      end

      let!(:service_response) do
        ServiceResponse.success(payload: {
          issues: jira_issues,
          is_last: true
        })
      end

      it "does not create any external issue links" do
        expect_next_instance_of(described_class::JiraIssuesFinder) do |instance|
          expect(instance).to receive(:execute).and_return(service_response)
        end

        expect { migration }.not_to change { vulnerability_external_issue_links.count }
      end
    end
  end

  describe "JiraIssuesFinder" do
    let(:client) do
      JIRA::Client.new(
        site: "https://test-domain.atlassian.net",
        context_path: "",
        username: "test",
        password: "test"
      )
    end

    let(:mock_jira_integration) do
      instance_double(described_class::JiraIntegration, client: client, project_keys: ["key1, key2"])
    end

    let(:jira_issues) do
      [
        {
          "id" => "1",
          "fields" => {
            "description" => "Issue created from vulnerability https://gitlab.com/-/security/vulnerabilities/#{vulnerability_1.id}",
            "project" => {
              "key" => "key1"
            }
          }
        },
        {
          "id" => "2",
          "fields" => {
            "description" => "Issue created from vulnerability https://gitlab.com/-/security/vulnerabilities/#{vulnerability_2.id}",
            "project" => {
              "key" => "key2"
            }
          }
        }
      ]
    end

    let(:finder) { described_class::JiraIssuesFinder.new(mock_jira_integration) }

    it "makes a call to the correct jira url" do
      expect(finder).to receive(:request)
                          .with("/rest/api/2/search?jql=project+in+%28key1%2C+key2%29+AND+description+~+%" \
                            "22Issue+created+from+vulnerability%22+order+by+created+DESC&startAt=0&" \
                            "maxResults=100&fields=description,project")
      finder.execute(1, 100)
    end

    it "returns payload with is_last as true if we are on the last page" do
      expect(client).to receive(:get).and_return({
        "issues" => jira_issues,
        "total" => 2,
        "start_at" => 0
      })
      response = finder.execute(1, 100)
      expect(response.payload[:is_last]).to be true
    end

    it "returns an empty payload if response is empty" do
      expect(client).to receive(:get).and_return({})
      response = finder.execute(1, 100)

      expect(response.payload[:issues]).to eq([])
      expect(response.payload[:is_last]).to be true
    end

    context 'when calls to jira instance fail' do
      let(:max_retries) { described_class::MAX_RETRIES }

      before do
        stub_const("EE::#{described_class.name}::DELAY", 0.seconds)
      end

      it "raises error if the call fails MAX_RETRIES times" do
        allow(client).to receive(:get).and_raise(JIRA::HTTPError, "Bad Request")

        expect do
          finder.execute(1, 100)
        end.to raise_error(JIRA::HTTPError)

        expect(client).to have_received(:get).exactly(max_retries).times
      end
    end
  end

  describe "JiraIntegration" do
    let!(:jira_tracker_data) do
      JiraTrackerData.create!(
        id: 1,
        integration_id: 1,
        url: "https://test-domain.atlassian.net",
        username: "test",
        password: "test",
        jira_auth_type: 0,
        project_keys: ["key1, key2"]
      )
    end

    describe "#valid?" do
      context "with valid jira integration and valid jira data" do
        it "returns true" do
          jira_integration = described_class::JiraIntegration.find(1)

          expect(jira_integration.valid?).to be true
        end
      end

      context "with valid jira integration but invalid jira data" do
        before do
          WebMock.stub_request(:get, /serverInfo/).to_raise(JIRA::HTTPError)
          WebMock.stub_request(:get, /myself/).to_raise(JIRA::HTTPError)
        end

        it "returns false" do
          jira_integration = described_class::JiraIntegration.find(1)

          expect(jira_integration.valid?).to be false
        end
      end

      context "with invalid jira integration" do
        it "returns false" do
          jira_integration = described_class::JiraIntegration.new(id: 2)

          expect(jira_integration.valid?).to be false
        end
      end
    end
  end

  private

  def project
    @project ||= projects.create!(id: 9999, namespace_id: namespace.id, project_namespace_id: namespace.id,
      creator_id: user.id, organization_id: organization.id)
  end

  def user
    @user ||= create_user(email: "test1@example.com", username: "test1")
  end

  def create_user(overrides = {})
    attrs = {
      email: "test@example.com",
      notification_email: "test@example.com",
      name: "test",
      username: "test",
      state: "active",
      projects_limit: 10,
      organization_id: organization.id
    }.merge(overrides)

    users.create!(attrs)
  end

  def create_vulnerability(overrides = {})
    vulnerabilities.create!({
      project_id: project.id,
      author_id: user.id,
      title: 'test',
      severity: 1,
      report_type: 1
    }.merge(overrides))
  end

  def create_finding(overrides = {})
    vulnerability_findings.create!({
      project_id: project.id,
      scanner_id: scanner.id,
      severity: 5, # medium
      report_type: 99, # generic
      primary_identifier_id: create_identifier.id,
      location_fingerprint: SecureRandom.hex(20),
      uuid: SecureRandom.uuid,
      name: "CVE-2018-1234",
      raw_metadata: "{}",
      metadata_version: "test:1.0"
    }.merge(overrides))
  end

  def create_identifier(overrides = {})
    vulnerability_identifiers.create!({
      project_id: project.id,
      external_id: "CVE-2018-1234",
      external_type: "CVE",
      name: "CVE-2018-1234",
      fingerprint: SecureRandom.hex(20)
    }.merge(overrides))
  end

  def create_jira_issue(issue_json)
    JIRA::Resource::Issue.build(JIRA::Client.new, issue_json)
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
