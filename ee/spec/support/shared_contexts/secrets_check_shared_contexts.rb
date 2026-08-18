# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers -- needed in specs

RSpec.shared_context 'secrets check context' do
  include_context 'secret detection error and log messages context'

  let_it_be(:user, freeze: false) { create(:user) }

  # Project is created with an empty repository, so
  # we create an initial commit to have a commit with some diffs.
  let_it_be(:project, freeze: false) { create(:project, :empty_repo) }
  let_it_be(:repository, freeze: false) { project.repository }
  let_it_be(:initial_commit, freeze: false) do
    # An initial commit to use as the oldrev in `changes` object below.
    repository.commit_files(
      user,
      branch_name: 'master',
      message: 'Initial commit',
      actions: [
        { action: :create, file_path: 'README', content: 'Documentation goes here' },
        { action: :create, file_path: 'old_config.txt', content: 'CONFIG_VALUE=old' },
        { action: :create, file_path: 'to_modify.txt', content: 'VAR=initial' }
      ]
    )
  end

  let_it_be(:new_commit) do
    actions = [
      { action: :create, file_path: '.env', content: 'BASE_URL=https://foo.bar' },
      { action: :move, file_path: 'new_config.txt', previous_path: 'old_config.txt', content: 'CONFIG_VALUE=old' },
      { action: :update, file_path: 'to_modify.txt', content: 'VAR=new' }
    ]
    create_commit_with_actions(actions, 'Add, update and move files', initial_commit)
  end

  # Define blob references as follows:
  #   1. blob 1 reference is used as an existing blob in the repository (left_blob_id in `DiffBlob` objects).
  #   2. blob 2 reference is used as a new blob  in the repository (right_blob_id in `DiffBlob` objects).
  #   3. blob 3 reference is used in several contexts and corresponds to `to_modify.txt`.
  #   4. blob 4 reference is used in several contexts and corresponds to `new_config.txt`.
  #   5. blob 5 reference is used in several contexts and corresponds to `.env`.
  #   6. blob 6 reference is used in several contexts and corresponds to `.test.env`.
  #   7. blob 7 reference is used in several contexts and corresponds to `.dev.env`.
  let(:blob_1_reference) { 'f3ac5ae18d057a11d856951f27b9b5b8043cf1ec' }
  let(:blob_2_reference) { 'da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda' }
  let(:blob_3_reference) { 'ed426f4235de33f1e5b539100c53e0002e143e3f' }
  let(:blob_4_reference) { '5d3962935b09208cd00252b050e632c75f9e7d7d' }
  let(:blob_5_reference) { 'fe29d93da4843da433e62711ace82db601eb4f8f' }
  let(:blob_6_reference) { 'eaf3c09526f50b5e35a096ef70cca033f9974653' }
  let(:blob_7_reference) { '4fbec77313fd240d00fc37e522d0274b8fb54bd1' }

  let(:changes) do
    [
      {
        oldrev: initial_commit,
        newrev: new_commit,
        ref: 'refs/heads/master'
      }
    ]
  end

  let_it_be(:commits) do
    Commit.decorate(
      [
        Gitlab::Git::Commit.find(repository, new_commit)
      ],
      project
    )
  end

  # repository.blank_ref is used to denote a delete commit
  let(:delete_changes) do
    [
      {
        oldrev: initial_commit,
        newrev: repository.blank_ref,
        ref: 'refs/heads/master'
      }
    ]
  end

  # Set up the `changes_access` object to use below.
  let(:protocol) { 'ssh' }
  let(:timeout) { Gitlab::GitAccess::INTERNAL_TIMEOUT }
  let(:logger) { Gitlab::Checks::TimedLogger.new(timeout: timeout) }
  let(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let(:push_options) { nil }
  let(:gitaly_context) { {} }

  let(:changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options,
      gitaly_context: gitaly_context
    )
  end

  let(:changes_access_web) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: 'web',
      logger: logger,
      push_options: push_options,
      gitaly_context: gitaly_context
    )
  end

  let(:changes_access_web_secrets_check_enabled) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: 'web',
      logger: logger,
      push_options: push_options,
      gitaly_context: { 'enable_secrets_check' => true }
    )
  end

  let(:delete_changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      delete_changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options,
      gitaly_context: gitaly_context
    )
  end

  # Used for mocking calls to logger.
  let(:secret_detection_logger) { instance_double(::Gitlab::SecretDetectionLogger) }

  # Used for the flags or state necessary to use the SDS - used to test logging
  let(:sds_ff_enabled) { false }
  let(:saas_feature_enabled) { true }
  let(:is_dedicated) { false }

  # Used for checking logged messages
  let(:log_levels) { %i[info debug warn error fatal unknown] }
  let(:logged_messages) { Hash.new { |hash, key| hash[key] = [] } }

  before do
    allow(::Gitlab::SecretDetectionLogger).to receive(:build).and_return(secret_detection_logger)

    # allow the logger to receive messages of different levels
    log_levels.each do |level|
      allow(secret_detection_logger).to receive(level) { |msg| logged_messages[level] << msg }
    end

    # This fixes a regression when testing locally because scanning in subprocess using the
    # parallel gem calls `Kernel.at_exit` hook in gitaly_setup.rb when a subprocess is killed
    # which in turns kills gitaly/praefect processes midway through the test suite, resulting in
    # connection refused errors because the processes are no longer around.
    #
    # Instead, we set `RUN_IN_SUBPROCESS` to false so that we don't scan in sub-processes at all in tests.
    stub_const('Gitlab::SecretDetection::Scan::RUN_IN_SUBPROCESS', false)
  end

  before_all do
    project.add_developer(user)
  end
end

RSpec.shared_context 'secret detection error and log messages context' do
  let(:error_messages) { ::Gitlab::Checks::SecretPushProtection::ResponseHandler::ERROR_MESSAGES }
  let(:log_messages) { ::Gitlab::Checks::SecretPushProtection::ResponseHandler::LOG_MESSAGES }

  # Error messsages with formatting
  let(:failed_to_scan_regex_error) do
    format(error_messages[:failed_to_scan_regex_error], { payload_id: blob_7_reference })
  end

  let(:blob_timed_out_error) do
    format(error_messages[:blob_timed_out_error], { payload_id: blob_6_reference })
  end

  # Log messages with formatting
  let(:finding_path) { '.env' }
  let(:finding_line_number) { 1 }
  let(:finding_description) { 'GitLab personal access token' }
  let(:finding_message_header) { format(log_messages[:finding_message_occurrence_header], { sha: new_commit }) }
  let(:finding_message_path) { format(log_messages[:finding_message_occurrence_path], { path: finding_path }) }

  let(:finding_message_occurrence_line) do
    format(
      log_messages[:finding_message_occurrence_line],
      {
        line_number: finding_line_number,
        description: finding_description
      }
    )
  end

  let(:finding_message_multiple_occurrence_lines) do
    variables = {
      line_number: finding_line_number,
      description: finding_description
    }

    finding_message_path + format(log_messages[:finding_message_occurrence_line], variables) +
      finding_message_path + format(log_messages[:finding_message_occurrence_line],
        variables.merge(line_number: finding_line_number + 1))
  end

  let(:finding_message_multiple_hunks_in_same_diff) do
    variables = {
      line_number: finding_line_number,
      description: finding_description
    }

    finding_message_path + format(log_messages[:finding_message_occurrence_line], variables) +
      finding_message_path + format(log_messages[:finding_message_occurrence_line],
        variables.merge(line_number: finding_line_number + 10))
  end

  let(:found_secrets_docs_link) do
    format(
      log_messages[:found_secrets_docs_link],
      {
        path: Rails.application.routes.url_helpers.help_page_url(
          'user/application_security/secret_detection/secret_push_protection/_index.md',
          anchor: 'resolve-a-blocked-push'
        )
      }
    )
  end
end

# In response to Incident 19090 (https://gitlab.com/gitlab-com/gl-infra/production/-/issues/19090)
RSpec.shared_context 'special characters table' do
  using RSpec::Parameterized::TableSyntax

  where(:special_character, :description) do
    (+'—').force_encoding('ASCII-8BIT')  | 'em-dash'
    (+'™').force_encoding('ASCII-8BIT')  | 'trademark'
    (+'☀').force_encoding('ASCII-8BIT')  | 'sun'
    (+'♫').force_encoding('ASCII-8BIT')  | 'beamed eighth notes'
    (+'⚡').force_encoding('ASCII-8BIT') | 'high voltage sign'
    (+'⚔').force_encoding('ASCII-8BIT')  | 'crossed swords'
    (+'⚖').force_encoding('ASCII-8BIT')  | 'scales'
    (+'⚛').force_encoding('ASCII-8BIT')  | 'atom symbol'
    (+'⚜').force_encoding('ASCII-8BIT')  | 'fleur-de-lis'
    (+'⚽').force_encoding('ASCII-8BIT') | 'soccer ball'
    (+'⛄').force_encoding('ASCII-8BIT') | 'snowman without snow'
    (+'⛅').force_encoding('ASCII-8BIT') | 'sun behind cloud'
    (+'⛎').force_encoding('ASCII-8BIT') | 'ophiuchus'
    (+'⛔').force_encoding('ASCII-8BIT') | 'no entry'
    (+'⛪').force_encoding('ASCII-8BIT') | 'church'
    (+'⛵').force_encoding('ASCII-8BIT') | 'sailboat'
    (+'⛺').force_encoding('ASCII-8BIT') | 'tent'
    (+'⛽').force_encoding('ASCII-8BIT') | 'fuel pump'
    (+'✈').force_encoding('ASCII-8BIT')  | 'airplane'
    (+'❄').force_encoding('ASCII-8BIT')  | 'snowflake'
  end
end

def create_commit(blobs, message = 'Add a file', initial_commit = nil)
  actions = blobs.map do |path, content|
    { action: :create, file_path: path, content: content }
  end
  create_commit_with_actions(actions, message, initial_commit)
end

def create_commit_with_actions(actions, message = 'Add a file', initial_commit = nil)
  commit = repository.commit_files(
    user,
    branch_name: 'a-new-branch',
    message: message,
    start_sha: initial_commit,
    actions: actions
  )

  # `list_all_commits` only returns unreferenced blobs because it is used for hooks, so we have
  # to delete the branch since Gitaly does not allow us to create loose objects via the RPC.
  repository.delete_branch('a-new-branch')

  commit
end

def finding_message(sha, path, line_number, description)
  message = format(log_messages[:finding_message_occurrence_header], { sha: sha })
  message += format(log_messages[:finding_message_occurrence_path], { path: path })
  message += format(
    log_messages[:finding_message_occurrence_line],
    {
      line_number: line_number,
      description: description
    }
  )
  message
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
