import { __, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DOCS_URL } from '~/constants';

export const maxNameLength = 255;
export const maxControlsNumber = 5;
export const maxRequirementsNumber = 50;
export const requirementsDocsUrl = `${DOCS_URL}/user/compliance/compliance_center/compliance_standards_adherence_dashboard.html`;

export const requirementEvents = Object.freeze({
  create: 'create',
  update: 'update',
  delete: 'delete',
});

export const emptyRequirement = {
  name: '',
  description: '',
};
export const requirementDefaultValidationState = {
  name: null,
  description: null,
};
export const i18n = {
  basicInformation: s__('ComplianceFrameworks|Basic information'),
  basicInformationDescription: s__(
    'ComplianceFrameworks|Set basic information for the compliance framework.',
  ),
  nameInputReserved: (name) =>
    sprintf(
      s__(
        'ComplianceFrameworks|"%{name}" is a reserved word and cannot be used as a compliance framework name.',
      ),
      { name },
    ),
  nameInputDuplicate: s__(
    'ComplianceFrameworks|A compliance framework with this name already exists. Please choose a different name.',
  ),
  nameInputDuplicateOnSubmit: (name) =>
    sprintf(
      s__(
        'ComplianceFrameworks|A compliance framework named "%{name}" already exists in this group. Go back to the Basic information step and choose a unique name.',
      ),
      { name },
    ),
  goToBasicInformation: s__('ComplianceFrameworks|Go to Basic information'),

  policies: s__('ComplianceFrameworks|Policies'),
  policiesDescription: s__(
    'ComplianceFrameworks|Create policies and attach them to this framework.',
  ),
  policiesInfoText: s__(
    'ComplianceFrameworks|Go to the %{linkStart}policy management page%{linkEnd} to scope policies for this framework.',
  ),
  policiesTableFields: {
    action: s__('ComplianceFrameworks|Action'),
    name: s__('ComplianceFrameworks|Policy name'),
    description: s__('ComplianceFrameworks|Summary'),
  },
  policiesLinkedTooltip: s__(
    `ComplianceFrameworks|To unlink this policy and framework, edit the policy's scope.`,
  ),
  policiesUnlinkedTooltip: s__(
    `ComplianceFrameworks|To link this policy and framework, edit the policy's scope.`,
  ),

  addFrameworkTitle: s__('ComplianceFrameworks|New compliance framework'),
  editFrameworkTitle: s__('ComplianceFrameworks|Edit compliance framework: %{frameworkName}'),

  submitButtonText: s__('ComplianceFrameworks|Create framework'),

  deleteButtonText: s__('ComplianceFrameworks|Delete framework'),
  deleteButtonLinkedPoliciesDisabledTooltip: s__(
    "ComplianceFrameworks|Compliance frameworks that have a scoped policy can't be deleted",
  ),
  deleteButtonDefaultFrameworkDisabledTooltip: s__(
    "ComplianceFrameworks|The default framework can't be deleted",
  ),
  deleteModalTitle: s__('ComplianceFrameworks|Delete compliance framework %{framework}'),
  deleteModalMessage: s__(
    'ComplianceFrameworks|You are about to permanently delete the compliance framework %{framework} from all projects which currently have it applied, which may remove other functionality. This cannot be undone.',
  ),

  successMessageText: s__('ComplianceFrameworks|Compliance framework created'),
  titleInputLabel: s__('ComplianceFrameworks|Name'),
  titleInputInvalid: s__(
    'ComplianceFrameworks|Name is required, and must be less than 255 characters',
  ),
  descriptionInputLabel: s__('ComplianceFrameworks|Description'),
  descriptionInputInvalid: s__('ComplianceFrameworks|Description is required'),
  pipelineConfigurationInputLabel: s__(
    'ComplianceFrameworks|Compliance pipeline configuration (deprecated)',
  ),
  pipelineConfigurationInputDescription: s__(
    'ComplianceFrameworks|Required format: %{codeStart}path/file.y[a]ml@group-name/project-name%{codeEnd}. %{linkStart}See some examples%{linkEnd}.',
  ),
  pipelineConfigurationInputDisabledPopoverTitle: s__(
    'ComplianceFrameworks|Requires Ultimate subscription',
  ),
  pipelineConfigurationInputDisabledPopoverContent: s__(
    'ComplianceFrameworks|Set compliance pipeline configuration for projects that use this framework. %{linkStart}How do I create the configuration?%{linkEnd}',
  ),
  pipelineConfigurationInputDisabledPopoverLink: helpPagePath(
    'user/compliance/compliance_pipelines',
  ),
  pipelineConfigurationInputInvalidFormat: s__('ComplianceFrameworks|Invalid format'),
  pipelineConfigurationInputUnknownFile: s__('ComplianceFrameworks|Configuration not found'),
  colorInputLabel: s__('ComplianceFrameworks|Background color'),

  editSaveBtnText: __('Update framework'),
  addSaveBtnText: s__('ComplianceFrameworks|Create framework'),
  fetchError: s__(
    'ComplianceFrameworks|Error fetching compliance frameworks data. Please refresh the page or try a different framework',
  ),

  setAsDefault: s__('ComplianceFrameworks|Set as default'),
  setAsDefaultDetails: s__(
    'ComplianceFrameworks|Default framework will be applied automatically to any new project created in the group or sub group.',
  ),
  setAsDefaultOnlyOne: s__('ComplianceFrameworks|There can be only one default framework.'),
  deprecationWarning: {
    title: s__('ComplianceReport|Compliance pipelines are deprecated'),
    message: s__(
      'ComplianceReport|Avoid creating new compliance pipelines and use pipeline execution policies instead. %{linkStart}Pipeline execution policies%{linkEnd} provide the ability to enforce CI/CD jobs, execute security scans, and better manage compliance enforcement in pipelines.',
    ),
    details: s__(
      'ComplianceReport|For more information, see %{linkStart}how to migrate from compliance pipelines to pipeline execution policies%{linkEnd}.',
    ),
    dismiss: s__('ComplianceReport|Dismiss'),
    migratePipelineToPolicy: s__('ComplianceReport|Migrate pipeline to a policy'),
    migratePipelineToPolicyEmpty: s__('ComplianceReport|Create policy'),

    postMigrationMessages: [
      s__(
        `ComplianceReport|This compliance framework's compliance pipeline has been migrated to a pipeline execution policy.`,
      ),
      s__(`ComplianceReport|However, there is still a configured compliance pipeline that must be removed. Otherwise, the compliance pipeline will
continue to take precedence over the new pipeline execution policy.`),
      s__(
        `ComplianceReport|Please remove the compliance pipeline configuration from the compliance framework so that the new pipeline execution policy can take precedence.`,
      ),
    ],
  },

  projects: s__('ComplianceFrameworks|Projects'),
  projectsTableFields: {
    name: s__('ComplianceFrameworks|Project name'),
    description: s__('ComplianceFrameworks|Description'),
    subgroup: s__('ComplianceFrameworks|Subgroup'),
  },
  projectsDescription: s__(
    'ComplianceFrameworks|All selected projects will be covered by the framework’s selected requirements and the policies.',
  ),
  selectedCount: s__('ComplianceFrameworks|Selected projects'),
  showOnlySelected: s__('ComplianceFrameworks|Show only currently selected'),
  projectsInfoText: s__(
    'ComplianceFrameworks|Go to the %{linkStart}compliance center / project page%{linkEnd} to apply projects for this framework.',
  ),
  requirementRemovedMessage: s__('ComplianceFrameworks|Requirement removed.'),
  requirementDeleteError: s__(
    'ComplianceFrameworks|An error occurred while deleting the requirement.',
  ),
  fetchProjectsError: s__('ComplianceFrameworks|Error loading projects.'),
  noProjectsFound: s__('ComplianceFrameworks|No projects found'),
  noProjectsFoundMatchingFilters: s__('ComplianceFrameworks|No projects found that match filters'),
  noProjectsSelected: s__('ComplianceFrameworks|No projects selected'),
};
