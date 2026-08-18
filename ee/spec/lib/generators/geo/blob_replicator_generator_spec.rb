# frozen_string_literal: true

require 'spec_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/assertions'
require 'generators/geo/blob_replicator_generator'

RSpec.describe Geo::BlobReplicatorGenerator, feature_category: :geo_replication do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests described_class
  destination File.expand_path('tmp', __dir__)

  before do
    prepare_destination
  end

  after do
    rm_rf(destination_root)
  end

  def read(path)
    File.read(File.join(destination_root, path))
  end

  def read_migration(dir, name)
    file = Dir.glob(File.join(destination_root, dir, "*_#{name}.rb")).first
    expect(file).not_to(be_nil, "expected a migration matching #{dir}/*_#{name}.rb")
    File.read(file)
  end

  context 'with an upload-partition replicable' do
    before do
      run_generator %w[
        vulnerability_remediation_upload
        --table-name=vulnerability_remediation_uploads
        --sharding-key=project_id
        --milestone=19.1
        --upload-partition
      ]
    end

    it 'generates the read-only partition model overriding the primary key' do
      assert_file('ee/app/models/geo/vulnerability_remediation_upload.rb') do |content|
        expect(content).to include('class VulnerabilityRemediationUpload < ::Upload')
        expect(content).to include("self.table_name = 'vulnerability_remediation_uploads'")
        expect(content).to include('self.primary_key = :id')
        expect(content).to include('with_replicator Geo::VulnerabilityRemediationUploadReplicator')
        # project_id sharding key selects the project_id selective-sync branch
        expect(content).to include('replicables.project_id_in(::Project.selective_sync_scope(node).select(:id))')
      end
    end

    it 'generates the replicator with upload replicator behavior' do
      assert_file('ee/app/replicators/geo/vulnerability_remediation_upload_replicator.rb') do |content|
        expect(content).to include('class VulnerabilityRemediationUploadReplicator < Gitlab::Geo::Replicator')
        expect(content).to include('include ::Geo::Concerns::UploadReplicatorBehavior')
        expect(content).to include('::Geo::VulnerabilityRemediationUpload')
        # carrierwave_uploader is provided by UploadReplicatorBehavior, not redefined here
        expect(content).not_to include('def carrierwave_uploader')
      end
    end

    it 'generates a partition upload registry' do
      assert_file('ee/app/models/geo/vulnerability_remediation_upload_registry.rb') do |content|
        expect(content).to include('include ::Geo::PartitionUploadRegistry')
        expect(content).to include('def self.model_updated_last')
      end
    end

    it 'generates the GraphQL registry type with the replicable name backticked in the description' do
      assert_file('ee/app/graphql/types/geo/vulnerability_remediation_upload_registry_type.rb') do |content|
        expect(content).to include(
          "description 'Represents the Geo replication and verification state of a `vulnerability_remediation_upload`'"
        )
      end
    end

    it 'generates the geo tracking-DB registry migration' do
      content = read_migration('ee/db/geo/migrate', 'create_vulnerability_remediation_upload_registry')
      expect(content).to include('class CreateVulnerabilityRemediationUploadRegistry')
      expect(content).to include('create_table :vulnerability_remediation_upload_registry')
    end

    it 'generates the partition unique index migration before the states migration' do
      index_file = Dir.glob(
        File.join(destination_root, 'db/migrate/*_add_unique_index_on_vulnerability_remediation_uploads_id.rb')
      ).first
      states_file = Dir.glob(
        File.join(destination_root, 'db/migrate/*_create_vulnerability_remediation_upload_states.rb')
      ).first

      expect(File.basename(index_file)).to be < File.basename(states_file)
    end

    it 'generates the states migration with a project_id sharding key and FK' do
      content = read_migration('db/migrate', 'create_vulnerability_remediation_upload_states')
      expect(content).to include('t.bigint :project_id, null: false')
      expect(content).to include(
        'add_concurrent_foreign_key :vulnerability_remediation_upload_states, :projects, ' \
          'column: :project_id, on_delete: :cascade'
      )
      # upload partitions reference the parent uploads table via a separate FK
      expect(content).to include(
        'add_concurrent_foreign_key :vulnerability_remediation_upload_states, ' \
          ':vulnerability_remediation_uploads, column: :vulnerability_remediation_upload_id, on_delete: :cascade'
      )
    end

    it 'generates the sharding-key trigger migration' do
      content = read_migration('db/migrate',
        'add_vulnerability_remediation_upload_states_project_id_sharding_key_trigger')
      expect(content).to include('install_sharding_key_assignment_trigger')
      expect(content).to include('sharding_key: :project_id')
    end

    it 'generates the dictionaries and ops feature flags' do
      assert_file('db/docs/vulnerability_remediation_upload_states.yml') do |content|
        expect(content).to include('gitlab_schema: gitlab_main_org')
        expect(content).to include('project_id: projects')
      end
      assert_file('ee/db/geo/docs/vulnerability_remediation_upload_registry.yml') do |content|
        expect(content).to include('gitlab_schema: gitlab_geo')
      end
      assert_file('ee/config/feature_flags/ops/geo_vulnerability_remediation_upload_replication.yml') do |content|
        expect(content).to include('name: geo_vulnerability_remediation_upload_replication')
        expect(content).to include('type: ops')
      end
    end

    it 'generates the partition model spec and the read-only replicator spec' do
      assert_file('ee/spec/models/geo/vulnerability_remediation_upload_spec.rb') do |content|
        expect(content).to include("include_examples 'Geo Framework selective sync behavior'")
      end
      assert_file('ee/spec/replicators/geo/vulnerability_remediation_upload_replicator_spec.rb') do |content|
        expect(content).to include("include_examples 'a blob replicator with a read-only replicable model'")
      end
    end
  end

  context 'with a standard (non-partition) replicable' do
    before do
      run_generator %w[
        ci_secure_file
        --table-name=ci_secure_files
        --sharding-key=project_id
        --milestone=18.10
        --model-class=Ci::SecureFile
      ]
    end

    it 'does not generate a partition model and references the real model class' do
      assert_no_file('ee/app/models/geo/ci_secure_file.rb')

      assert_file('ee/app/replicators/geo/ci_secure_file_replicator.rb') do |content|
        expect(content).to include('::Ci::SecureFile')
        expect(content).to include('model_record.file')
        expect(content).not_to include('UploadReplicatorBehavior')
      end
    end

    it 'generates a registry without the partition upload concern' do
      assert_file('ee/app/models/geo/ci_secure_file_registry.rb') do |content|
        expect(content).not_to include('PartitionUploadRegistry')
        expect(content).not_to include('model_updated_last')
      end
    end

    it 'generates a standard replicator spec' do
      assert_file('ee/spec/replicators/geo/ci_secure_file_replicator_spec.rb') do |content|
        expect(content).to include("include_examples 'a blob replicator'")
      end
    end

    it 'inlines the FK in create_table (no separate parent-table FK)' do
      content = read_migration('db/migrate', 'create_ci_secure_file_states')
      expect(content).to include('foreign_key: { on_delete: :cascade }')
      expect(content).not_to include('add_concurrent_foreign_key :ci_secure_file_states, :ci_secure_files')
    end
  end

  context 'with --pretend' do
    it 'writes no files' do
      run_generator %w[
        cool_widget --model-class=CoolWidget --table-name=cool_widgets
        --sharding-key=project_id --milestone=19.1 --pretend
      ]

      assert_no_file('ee/app/replicators/geo/cool_widget_replicator.rb')
      assert_no_file('ee/app/models/geo/cool_widget_registry.rb')
    end
  end

  context 'with multiple sharding keys' do
    before do
      run_generator %w[
        ai_vectorizable_file_upload
        --table-name=ai_vectorizable_file_uploads
        --sharding-key namespace_id project_id
        --milestone=18.11
        --upload-partition
      ]
    end

    it 'adds a column, index and FK per key plus a multi-column not-null constraint' do
      content = read_migration('db/migrate', 'create_ai_vectorizable_file_upload_states')
      expect(content).to include('t.bigint :namespace_id')
      expect(content).to include('t.bigint :project_id')
      expect(content).to include('add_concurrent_foreign_key :ai_vectorizable_file_upload_states, :namespaces')
      expect(content).to include('add_concurrent_foreign_key :ai_vectorizable_file_upload_states, :projects')
      expect(content).to include(
        'add_multi_column_not_null_constraint(:ai_vectorizable_file_upload_states, :namespace_id, :project_id)'
      )
    end

    it 'generates one sharding-key trigger migration per key' do
      %w[namespace_id project_id].each do |key|
        content = read_migration('db/migrate', "add_ai_vectorizable_file_upload_states_#{key}_sharding_key_trigger")
        expect(content).to include("sharding_key: :#{key}")
      end
    end
  end

  context 'with the organization_id sharding key' do
    before do
      run_generator %w[
        dependency_list_export_upload
        --table-name=dependency_list_export_uploads
        --sharding-key=organization_id
        --milestone=19.1
        --upload-partition
      ]
    end

    it 'uses the organization_id selective-sync branch and scope' do
      assert_file('ee/app/models/geo/dependency_list_export_upload.rb') do |content|
        expect(content).to include('scope :organization_id_in, ->(ids) { where(organization_id: ids) }')
        expect(content).to include('replicables.organization_id_in(node.organizations.select(:id))')
      end
    end
  end

  context 'with --no-sharding-key (cell-setting / instance-wide upload partition)' do
    before do
      run_generator %w[
        appearance_upload
        --table-name=appearance_uploads
        --milestone=19.2
        --upload-partition
        --no-sharding-key
      ]
    end

    it 'generates an always-replicate selective_sync_scope and no sharding-key scope' do
      assert_file('ee/app/models/geo/appearance_upload.rb') do |content|
        expect(content).to include('override :selective_sync_scope')
        expect(content).to include('always replicated regardless')
        expect(content).not_to include('_id_in')
        expect(content).not_to include('node.selective_sync?')
      end
    end

    it 'generates a states migration with only the parent-table FK and no sharding column' do
      content = read_migration('db/migrate', 'create_appearance_upload_states')

      expect(content).to include(
        'add_concurrent_foreign_key :appearance_upload_states, :appearance_uploads, ' \
          'column: :appearance_upload_id, on_delete: :cascade'
      )
      expect(content.scan('add_concurrent_foreign_key').size).to eq(1)
      expect(content).not_to include('t.bigint')
    end

    it 'generates no sharding-key trigger migration' do
      triggers = Dir.glob(File.join(destination_root, 'db/migrate/*_sharding_key_trigger.rb'))
      expect(triggers).to be_empty
    end

    it 'classifies the states table as gitlab_main_cell_setting with no sharding_key' do
      assert_file('db/docs/appearance_upload_states.yml') do |content|
        expect(content).to include('gitlab_schema: gitlab_main_cell_setting')
        expect(content).not_to include('sharding_key:')
      end
    end

    it 'generates an always-replicated model spec instead of the selective-sync shared example' do
      assert_file('ee/spec/models/geo/appearance_upload_spec.rb') do |content|
        expect(content).to include('is always replicated regardless of selective sync configuration')
        expect(content).not_to include("include_examples 'Geo Framework selective sync behavior'")
      end
    end
  end

  context 'when patching framework files' do
    def write_stub(path, content)
      full = File.join(destination_root, path)
      mkdir_p(File.dirname(full))
      File.write(full, content)
    end

    before do
      # The list stubs are kept alphabetically sorted (as on master after !240465) so the
      # generator's sorted-insertion lands the new entry at the right position. The comma-style
      # lists end before "Vulnerability" to exercise the append + trailing-comma path; the others
      # bracket it to exercise mid-list insertion.
      write_stub('ee/lib/gitlab/geo.rb', <<~RUBY)
        REPLICATOR_CLASSES = [
          ::Geo::AaaReplicator,
          ::Geo::ContainerRepositoryReplicator
        ].freeze
      RUBY
      write_stub('ee/app/graphql/types/geo/geo_node_type.rb', <<~RUBY)
        field :something_else, null: true
        field :verification_max_capacity, GraphQL::Types::Int, null: true, description: 'x'
      RUBY
      write_stub('config/authz/graphql/authorization_todo.txt', "type:AaaRegistry\ntype:ZzzRegistry\n")
      write_stub('config/initializers_before_autoloader/000_inflections.rb',
        "    packages_helm_metadata_cache_registry\n")
      write_stub('ee/spec/support/shared_contexts/graphql/geo/registries_shared_context.rb', <<~RUBY)
        where(:registry_class, :registry_type, :registry_factory) do
          Geo::AaaRegistry                 | Types::Geo::AaaRegistryType                 | :geo_aaa_registry
          Geo::ContainerRepositoryRegistry | Types::Geo::ContainerRepositoryRegistryType | :geo_container_repository_registry
        end
      RUBY
      write_stub('ee/spec/requests/api/graphql/geo/registries_spec.rb', <<~RUBY)
        RSpec.describe 'Gets registries', feature_category: :geo_replication do
          it_behaves_like 'gets registries for', {
            field_name: 'abuseReportUploadRegistries',
            registry_class_name: 'AbuseReportUploadRegistry',
            registry_factory: :geo_abuse_report_upload_registry,
            registry_foreign_key_field_name: 'abuseReportUploadId'
          }

          it_behaves_like 'gets registries for', {
            field_name: 'zzzRegistries',
            registry_class_name: 'ZzzRegistry',
            registry_factory: :geo_zzz_registry,
            registry_foreign_key_field_name: 'zzzId'
          }
        end
      RUBY
      write_stub('ee/spec/workers/geo/secondary/registry_consistency_worker_spec.rb', <<~RUBY)
        RSpec.describe 'worker' do
          it 'creates' do
            abuse_report_upload = create(:geo_abuse_report_upload)

            expect(Geo::AbuseReportUploadRegistry.where(abuse_report_upload_id: abuse_report_upload.id).count).to eq(0)

            subject.perform

            expect(Geo::AbuseReportUploadRegistry.where(abuse_report_upload_id: abuse_report_upload.id).count).to eq(1)
          end
        end
      RUBY
      write_stub('ee/spec/graphql/types/geo/geo_node_type_spec.rb', <<~RUBY)
        expected_fields = %i[
          aaa_registries
          zzz_registries
        ]
      RUBY
      write_stub('ee/spec/graphql/types/geo/registry_class_enum_spec.rb', <<~RUBY)
        %w[
          AAA_REGISTRY
          ZZZ_REGISTRY
        ]
      RUBY
      write_stub('app/assets/javascripts/graphql_shared/possible_types.json',
        %({\n  "Registrable": [\n    "AaaRegistry",\n    "ZzzRegistry"\n  ]\n}\n))
      %w[geo_node_status geo_site_status].each do |name|
        write_stub("ee/spec/fixtures/api/schemas/public_api/v4/#{name}.json",
          %({"required":["git_fetch_event_count_weekly"],) +
          %("properties":{"git_fetch_event_count_weekly":{"type":"integer"}}}))
      end
      %w[geo_nodes geo_sites].each do |name|
        write_stub("doc/api/#{name}.md", %(      "git_fetch_event_count_weekly": 0\n))
      end
      write_stub('doc/administration/monitoring/prometheus/gitlab_metrics.md',
        "| `geo_status_failed_total` | Gauge | 1.0 | `url` | desc |\n")

      run_generator %w[
        vulnerability_remediation_upload
        --table-name=vulnerability_remediation_uploads
        --sharding-key=project_id
        --milestone=19.1
        --upload-partition
      ]
    end

    it 'registers the replicator classes in sorted order, appended with a trailing comma' do
      # New entry sorts after the existing last one: the previous last gains a comma and the
      # new entry becomes the final (comma-less) element.
      expect(read('ee/lib/gitlab/geo.rb')).to match(
        /::Geo::ContainerRepositoryReplicator,\n\s*::Geo::VulnerabilityRemediationUploadReplicator\n\s*\]\.freeze/
      )
    end

    it 'adds the GraphQL field before verification_max_capacity' do
      node_type = read('ee/app/graphql/types/geo/geo_node_type.rb')
      expect(node_type).to match(
        /field :vulnerability_remediation_upload_registries.*field :verification_max_capacity/m
      )
    end

    it 'inserts the geo_node_type_spec field and shared-context row in sorted order' do
      expect(read('ee/spec/graphql/types/geo/geo_node_type_spec.rb')).to match(
        /aaa_registries\n\s*vulnerability_remediation_upload_registries\n\s*zzz_registries/
      )
      expect(read('ee/spec/support/shared_contexts/graphql/geo/registries_shared_context.rb')).to match(
        %r{Geo::ContainerRepositoryRegistry.*\n\s*Geo::VulnerabilityRemediationUploadRegistry.*\n\s*end}
      )
    end

    it 'inserts the authorization todo entry in sorted order' do
      todo = read('config/authz/graphql/authorization_todo.txt')
      expect(todo).to match(
        /type:AaaRegistry\ntype:VulnerabilityRemediationUploadRegistry\ntype:ZzzRegistry/
      )
    end

    it 'adds the inflection (anchored) and the enum entry in sorted order' do
      expect(read('config/initializers_before_autoloader/000_inflections.rb'))
        .to include('vulnerability_remediation_upload_registry')
      expect(read('ee/spec/graphql/types/geo/registry_class_enum_spec.rb')).to match(
        /AAA_REGISTRY\n\s*VULNERABILITY_REMEDIATION_UPLOAD_REGISTRY\n\s*ZZZ_REGISTRY/
      )
    end

    it 'inserts the registries request-spec shared example in sorted order', :aggregate_failures do
      content = read('ee/spec/requests/api/graphql/geo/registries_spec.rb')

      expect(content).to include('registry_factory: :geo_vulnerability_remediation_upload_registry')
      # sorts between AbuseReportUploadRegistry and ZzzRegistry
      expect(content).to match(
        /AbuseReportUploadRegistry.*VulnerabilityRemediationUploadRegistry.*ZzzRegistry/m
      )
    end

    it 'patches the registry consistency worker spec' do
      worker_spec = read('ee/spec/workers/geo/secondary/registry_consistency_worker_spec.rb')
      expect(worker_spec).to include('vulnerability_remediation_upload = create(:geo_vulnerability_remediation_upload)')
      expect(worker_spec).to include(
        'Geo::VulnerabilityRemediationUploadRegistry.where(vulnerability_remediation_upload_id:'
      )
    end

    it 'inserts into the possible_types Registrable array, sorted' do
      list = Gitlab::Json.safe_parse(read('app/assets/javascripts/graphql_shared/possible_types.json'))['Registrable']
      expect(list).to eq(%w[AaaRegistry VulnerabilityRemediationUploadRegistry ZzzRegistry])
    end

    it 'adds the status fields, API doc fields and prometheus metrics' do
      status = Gitlab::Json.safe_parse(read('ee/spec/fixtures/api/schemas/public_api/v4/geo_node_status.json'))
      expect(status['required']).to include('vulnerability_remediation_uploads_count')
      expect(status['properties']).to have_key('vulnerability_remediation_uploads_count')

      expect(read('doc/api/geo_nodes.md')).to include('"vulnerability_remediation_uploads_count": 0')
      expect(read('doc/administration/monitoring/prometheus/gitlab_metrics.md'))
        .to include('geo_vulnerability_remediation_uploads')
    end
  end

  context 'when wiring the domain model (standard mode)' do
    let(:args) do
      %w[cool_widget --table-name=cool_widgets --sharding-key=project_id --milestone=19.1
        --model-class=CoolWidget]
    end

    def write_file(path, content)
      full = File.join(destination_root, path)
      mkdir_p(File.dirname(full))
      File.write(full, content)
    end

    it 'wires the existing model as a Geo replicable by creating its EE concern' do
      run_generator(args)

      assert_file('ee/app/models/ee/cool_widget.rb') do |content|
        expect(content).to include('module EE')
        expect(content).to include('include ::Geo::ReplicableModel')
        expect(content).to include('with_replicator ::Geo::CoolWidgetReplicator')
        expect(content).to include('has_one :cool_widget_state')
        expect(content).to include('override :selective_sync_scope')
      end
    end

    it 'injects the wiring into an existing EE concern, preserving its contents' do
      write_file('ee/app/models/ee/cool_widget.rb', <<~RUBY)
        # frozen_string_literal: true

        module EE
          module CoolWidget
            extend ActiveSupport::Concern

            prepended do
              scope :existing, -> { all }
            end

            class_methods do
              def existing_cm; end
            end
          end
        end
      RUBY

      run_generator(args)

      assert_file('ee/app/models/ee/cool_widget.rb') do |content|
        expect(content).to include('with_replicator ::Geo::CoolWidgetReplicator')
        expect(content).to include('scope :existing, -> { all }')   # preserved
        expect(content).to include('def existing_cm; end')          # preserved
      end
    end

    it 'does not wire a model in upload-partition mode' do
      run_generator %w[vulnerability_remediation_upload --table-name=vulnerability_remediation_uploads
        --sharding-key=project_id --milestone=19.1 --upload-partition]

      assert_no_file('ee/app/models/ee/vulnerability_remediation_upload.rb')
    end
  end

  context 'with --only-post-generate' do
    let(:generator) do
      described_class.new(
        ['vulnerability_remediation_upload'],
        { table_name: 'vulnerability_remediation_uploads', sharding_key: ['project_id'],
          milestone: '19.1', upload_partition: true, only_post_generate: true }
      ).tap { |g| g.destination_root = destination_root }
    end

    before do
      # Pretend we're generating into the real repo so the post-generation tasks run.
      allow(generator).to receive(:generating_into_repo?).and_return(true)
      allow(generator).to receive(:run)
      allow(generator).to receive(:say_status)
    end

    it 're-runs the post-generation tasks' do
      described_class::POST_GENERATION_TASKS.each do |command|
        expect(generator).to receive(:run).with(command).ordered
      end

      generator.invoke_all
    end

    it 'does not create per-replicable files' do
      generator.invoke_all

      assert_no_file('ee/app/replicators/geo/vulnerability_remediation_upload_replicator.rb')
      assert_no_file('ee/app/models/geo/vulnerability_remediation_upload.rb')
      # Framework files are not created here; the patches skip absent targets in the sandbox.
      assert_no_file('ee/lib/gitlab/geo.rb')
    end

    it 're-applies the framework patches to existing files, idempotently', :aggregate_failures do
      geo_path = File.join(destination_root, 'ee/lib/gitlab/geo.rb')
      mkdir_p(File.dirname(geo_path))
      File.write(geo_path, <<~RUBY)
        REPLICATOR_CLASSES = [
          ::Geo::AaaReplicator,
          ::Geo::ContainerRepositoryReplicator
        ].freeze
      RUBY

      generator.invoke_all

      expect(File.read(geo_path)).to include('::Geo::VulnerabilityRemediationUploadReplicator')
      expect(File.read(geo_path).scan('VulnerabilityRemediationUploadReplicator').size).to eq(1)

      # A second patch pass must not duplicate the entry.
      generator.patch_framework_files
      expect(File.read(geo_path).scan('VulnerabilityRemediationUploadReplicator').size).to eq(1)
    end
  end

  context 'with post-generation tasks' do
    it 'does not run rake tasks or autocorrect when generating outside the repo' do
      generator = described_class.new(
        ['foo_upload'],
        { table_name: 'foo_uploads', sharding_key: ['project_id'], milestone: '19.1', upload_partition: true }
      )
      generator.destination_root = destination_root

      expect(generator).not_to receive(:run)

      generator.invoke_all
    end
  end

  context 'with invalid options' do
    # Invoke directly (not via run_generator/Thor.start, which rescues Thor::Error) so the
    # validation error propagates.
    def invoke(name, options)
      described_class.new([name], options).invoke_all
    end

    it 'rejects an unknown sharding key' do
      expect do
        invoke('foo_upload',
          { table_name: 'foo_uploads', sharding_key: ['bogus_id'], milestone: '19.1', upload_partition: true })
      end.to raise_error(Thor::Error, /sharding-key must be one of/)
    end

    it 'requires a sharding key unless --no-sharding-key' do
      expect do
        invoke('foo_upload', { table_name: 'foo_uploads', milestone: '19.1', upload_partition: true })
      end.to raise_error(Thor::Error, /sharding-key must be provided/)
    end

    it 'requires --upload-partition with --no-sharding-key' do
      expect do
        invoke('foo_upload', { table_name: 'foo_uploads', milestone: '19.1', no_sharding_key: true })
      end.to raise_error(Thor::Error, /--no-sharding-key requires --upload-partition/)
    end

    it 'rejects --no-sharding-key combined with --sharding-key' do
      expect do
        invoke('foo_upload',
          { table_name: 'foo_uploads', sharding_key: ['organization_id'], milestone: '19.1',
            upload_partition: true, no_sharding_key: true })
      end.to raise_error(Thor::Error, /--no-sharding-key cannot be combined with --sharding-key/)
    end

    it 'requires --model-class unless --upload-partition' do
      expect do
        invoke('foo', { table_name: 'foos', sharding_key: ['project_id'], milestone: '19.1' })
      end.to raise_error(Thor::Error, /model-class is required/)
    end

    it 'rejects a malformed milestone' do
      expect do
        invoke('foo_upload',
          { table_name: 'foo_uploads', sharding_key: ['project_id'], milestone: "19.1'", upload_partition: true })
      end.to raise_error(Thor::Error, /milestone must be MAJOR\.MINOR/)
    end

    it 'rejects --only-post-generate combined with --skip-post-generate' do
      expect do
        invoke('foo_upload',
          { table_name: 'foo_uploads', sharding_key: ['project_id'], milestone: '19.1', upload_partition: true,
            only_post_generate: true, skip_post_generate: true })
      end.to raise_error(Thor::Error, /only-post-generate cannot be combined with --skip-post-generate/)
    end

    it 'raises when a patch anchor is missing from an existing file' do
      full = File.join(destination_root, 'ee/lib/gitlab/geo.rb')
      mkdir_p(File.dirname(full))
      File.write(full, "# no REPLICATOR_CLASSES list here\n")

      generator = described_class.new(
        ['vulnerability_remediation_upload'],
        { table_name: 'vulnerability_remediation_uploads', sharding_key: ['project_id'],
          milestone: '19.1', upload_partition: true }
      )
      generator.destination_root = destination_root

      expect { generator.invoke_all }.to raise_error(Thor::Error, %r{Anchor not found in ee/lib/gitlab/geo\.rb})
    end

    it 'rejects path traversal in a managed path' do
      generator = described_class.new(
        ['x_upload'],
        { table_name: 'x_uploads', sharding_key: ['project_id'], milestone: '19.1', upload_partition: true }
      )

      expect { generator.send(:destination_path, '../../etc/passwd') }
        .to raise_error(Gitlab::PathTraversal::PathTraversalAttackError)
    end
  end
end
