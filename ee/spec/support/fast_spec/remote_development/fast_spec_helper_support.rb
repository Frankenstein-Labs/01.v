# frozen_string_literal: true

# External gem/library requires
require 'json_schemer'
require 'devfile'
require 'oj'

# The order of imports is important because overrides from EE modules are prepended to their corresponding CE file.
# In other words, if the EE file is not loaded before CE file then the EE module will not override the CE one.
# Thus, we group all of the EE requires first (in alphabetical filesystem order), then all of the CE requires.

### Do all EE requires BEFORE CE requires ###
require_relative '../../../../app/models/remote_development/enums/workspace_variable'
require_relative '../../../../app/models/remote_development/workspace_state_helpers'
require_relative '../../../../app/validators/ee/json_schema_validator'
require_relative '../../../../app/validators/remote_development/desired_config_array_validator'
require_relative '../../../../lib/remote_development/files'
require_relative '../../../../lib/remote_development/remote_development_constants'
require_relative '../../../../lib/remote_development/workspace_operations/create/create_constants'
require_relative '../../../../lib/remote_development/workspace_operations/workspace_operations_constants'
require_relative '../../../support/helpers/remote_development/fixture_file_erb_binding'
require_relative '../../../support/helpers/remote_development/fixture_file_helpers'
require_relative '../../../support/shared_contexts/remote_development/agent_info_status_fixture_not_implemented_error'
require_relative '../../../support/shared_contexts/remote_development/constant_modules_context'
require_relative '../../../support/shared_contexts/remote_development/remote_development_shared_contexts'

### Do all CE requires AFTER EE requires ###
require_relative '../../../../../app/validators/json_schema_validator'
require_relative '../../../../../lib/gitlab/fp/result'
require_relative '../../../../../spec/support/matchers/be_valid_json'
