<script>
import { isEmpty } from 'lodash-es';
import {
  GlAlert,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { isProject, isGroup } from 'ee/security_orchestration/components/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import LoaderWithMessage from '../../loader_with_message.vue';
import ComplianceFrameworkSelector from './compliance_framework_selector.vue';
import AttributeRows from './attribute_rows.vue';
import SectionAlert from './section_alert.vue';
import GroupSelector from './group_selector.vue';
import ProjectSelector from './project_selector.vue';
import {
  CSP_SCOPE_TYPE_LISTBOX_ITEMS,
  CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS,
  CSP_SCOPE_TYPE_TEXTS,
  PROJECTS_WITH_FRAMEWORK,
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  PROJECT_SCOPE_TYPE_TEXTS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  WITHOUT_EXCEPTIONS,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  EXCEPT_GROUPS,
  EXCEPT_PERSONAL_PROJECTS,
  ALL_PROJECTS_IN_GROUP,
  INCLUDING,
  EXCLUDING,
  COMPLIANCE_FRAMEWORKS_KEY,
  PROJECTS_KEY,
  ALL_PROJECTS_IN_LINKED_GROUPS,
  GROUPS_KEY,
  SECURITY_CATEGORIES,
  SUPPORTED_SECURITY_CATEGORY_KEYS,
} from './constants';

export default {
  COMPLIANCE_FRAMEWORK_PATH: helpPagePath('user/compliance/compliance_frameworks/_index'),
  SCOPE_HELP_PATH: helpPagePath('user/application_security/policies/_index.md'),
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  i18n: {
    policyScopeLoadingText: s__('SecurityOrchestration|Fetching the scope information.'),
    policyScopeErrorText: s__(
      'SecurityOrchestration|Failed to fetch the scope information. Please refresh the page to try again.',
    ),
    policyScopeFrameworkCopyProject: s__(
      'SecurityOrchestration|Apply this policy to current project.',
    ),
    defaultModeTitle: s__('SecurityOrchestration|Use default mode for scoping'),
    defaultModeDescription: s__(
      'SecurityOrchestration|Enforce policy on all groups, subgroups, and projects linked to the security policy project. %{linkStart}How does scoping work?%{linkEnd}',
    ),
    defaultModePopover: s__('SecurityOrchestration|Turn off default mode to edit scope.'),
    policyScopeFrameworkCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType}named %{frameworkSelector}`,
    ),
    policyScopeProjectCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType} %{projectSelector}`,
    ),
    policyScopeCategoriesCopy: s__(
      'SecurityOrchestration|Apply this policy to %{projectScopeType}',
    ),
    groupProjectErrorDescription: s__('SecurityOrchestration|Failed to load group projects'),
    complianceFrameworkErrorDescription: s__(
      'SecurityOrchestration|Failed to load compliance frameworks',
    ),
    securityAttributeErrorDescription: s__(
      'SecurityOrchestration|Failed to load security categories',
    ),
    complianceFrameworkPopoverTitle: __('Information'),
    complianceFrameworkPopoverContent: s__(
      'SecurityOrchestration|A compliance framework is a label to identify that your project has certain compliance requirements. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'ScopeSection',
  components: {
    ComplianceFrameworkSelector,
    GlAlert,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlIcon,
    GlLink,
    GlSprintf,
    LoaderWithMessage,
    PolicyPopover,
    AttributeRows,
    SectionAlert,
    GroupSelector,
    ProjectSelector,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const linkedProjects = data?.project?.securityPolicyProjectLinkedProjects?.nodes || [];
        const linkedGroups = data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];
        const items = [...linkedProjects, ...linkedGroups];

        if (this.shouldSetDefaultScope(items)) {
          this.setDefaultScope();
        }

        return items;
      },
      error() {
        this.showLinkedSppItemsError = true;
      },
      skip() {
        return this.isGroupLevel;
      },
    },
  },
  inject: [
    'assignedPolicyProject',
    'designatedAsCsp',
    'enabledExperiments',
    'existingPolicy',
    'namespacePath',
    'namespaceType',
    'rootNamespacePath',
  ],
  props: {
    policyScope: {
      type: Object,
      required: true,
      default: () => ({}),
    },
  },
  emits: ['changed', 'remove'],
  data() {
    return {
      useDefaultScope: isEmpty(this.policyScope),
      selectedExceptionType: this.getInitialExceptionType(),
      selectedProjectScopeType: this.getInitialProjectScopeType(),
      selectedGroupExceptionType: this.getInitialGroupExceptionType(),
      projectsPayloadKey: this.getInitialPayloadKey(),
      showAlert: false,
      errorDescription: '',
      linkedSppItems: [],
      showLinkedSppItemsError: false,
      isFormDirty: false,
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.isGroupLevel ? this.assignedPolicyProject?.fullPath || '' : this.namespacePath;
    },
    hasGroups() {
      return Boolean(this.policyScope.groups?.including);
    },
    hasScopedFrameworks() {
      return Boolean(this.policyScope?.compliance_frameworks?.length);
    },
    hasScopedGroups() {
      const groups = this.policyScope?.groups;
      return Boolean(groups?.including?.length) || Boolean(groups?.excluding?.length);
    },
    hasScopedProjects() {
      const projects = this.policyScope?.projects;
      return Boolean(projects?.including?.length) || Boolean(projects?.excluding?.length);
    },
    isPolicyScopeEmpty() {
      return !this.hasScopedProjects && !this.hasScopedGroups && !this.hasScopedFrameworks;
    },
    showScopeGroupSelector() {
      return this.hasGroups || this.selectedProjectScopeType === ALL_PROJECTS_IN_LINKED_GROUPS;
    },
    hasExistingPolicy() {
      return Boolean(this.existingPolicy);
    },
    isGroupLevel() {
      return isGroup(this.namespaceType);
    },
    isProjectLevel() {
      return isProject(this.namespaceType);
    },
    isAllProjects() {
      return this.selectedProjectScopeType === ALL_PROJECTS_IN_GROUP;
    },
    isSecurityCategoriesScope() {
      return this.selectedProjectScopeType === SECURITY_CATEGORIES && this.showAttributeSelector;
    },
    isNewCSPPolicy() {
      return this.designatedAsCsp && !this.existingPolicy;
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    disableScopeSelector() {
      return (
        this.isProjectLevel &&
        this.hasMultipleProjectsLinked &&
        this.hasExistingPolicy &&
        this.useDefaultScope
      );
    },
    showDefaultScopeSelector() {
      return this.isProjectLevel && this.hasExistingPolicy;
    },
    groups() {
      return this.policyScope?.groups || {};
    },
    projects() {
      return this.policyScope?.projects || {};
    },
    projectIds() {
      /**
       * Protection from manual yaml input as objects
       * Filter out items without id (e.g., { type: 'personal' })
       * @type {*|*[]}
       */
      const projects = Array.isArray(this.policyScope?.projects?.[this.projectsPayloadKey])
        ? this.policyScope?.projects?.[this.projectsPayloadKey]
        : [];

      return (
        projects
          ?.filter(({ id }) => Boolean(id))
          ?.map(({ id }) => convertToGraphQLId(TYPENAME_PROJECT, id)) || []
      );
    },
    groupIds() {
      return this.policyScope?.groups?.including || [];
    },
    complianceFrameworksIds() {
      /**
       * Protection from manual yam input as objects
       * @type {*|*[]}
       */
      const frameworks = Array.isArray(this.policyScope?.compliance_frameworks)
        ? this.policyScope?.compliance_frameworks
        : [];
      return frameworks?.map(({ id }) => id) || [];
    },
    selectedProjectScopeText() {
      return this.designatedAsCsp
        ? CSP_SCOPE_TYPE_TEXTS[this.selectedProjectScopeType]
        : PROJECT_SCOPE_TYPE_TEXTS[this.selectedProjectScopeType];
    },
    showAttributeSelector() {
      return this.isAttributeScopeEnabled();
    },
    showScopeSelector() {
      return this.isGroupLevel || this.hasMultipleProjectsLinked;
    },
    showExceptionTypeDropdown() {
      return this.isAllProjects;
    },
    showGroupProjectsDropdown() {
      return (
        (this.showExceptionTypeDropdown && this.selectedExceptionType === EXCEPT_PROJECTS) ||
        this.selectedProjectScopeType === SPECIFIC_PROJECTS ||
        this.isAllProjects
      );
    },
    payloadKey() {
      if ([ALL_PROJECTS_IN_GROUP, SPECIFIC_PROJECTS].includes(this.selectedProjectScopeType)) {
        return PROJECTS_KEY;
      }

      if (this.selectedProjectScopeType === ALL_PROJECTS_IN_LINKED_GROUPS) {
        return GROUPS_KEY;
      }

      return COMPLIANCE_FRAMEWORKS_KEY;
    },
    policyScopeCopy() {
      if (this.isSecurityCategoriesScope) {
        return this.$options.i18n.policyScopeCategoriesCopy;
      }
      return this.selectedProjectScopeType === PROJECTS_WITH_FRAMEWORK
        ? this.$options.i18n.policyScopeFrameworkCopy
        : this.$options.i18n.policyScopeProjectCopy;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && !this.isGroupLevel;
    },
    isProjectsWithoutExceptions() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS;
    },
    projectsEmpty() {
      // If we're excluding personal projects, that's a valid non-empty state
      if (this.selectedExceptionType === EXCEPT_PERSONAL_PROJECTS) {
        return false;
      }
      return this.projectIds.length === 0;
    },
    groupsEmpty() {
      return this.groupIds.length === 0;
    },
    complianceFrameworksEmpty() {
      return this.complianceFrameworksIds.length === 0;
    },
    complianceFrameworksValidState() {
      return this.complianceFrameworksEmpty && this.isFormDirty;
    },
    scopeDropdownItems() {
      let items;

      if (!this.designatedAsCsp) {
        items = PROJECT_SCOPE_TYPE_LISTBOX_ITEMS;
      } else if (this.hasGroups) {
        items = CSP_SCOPE_TYPE_LISTBOX_ITEMS;
      } else {
        // CSP without groups: exclude "all projects in linked groups" option
        items = CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS;
      }

      if (!this.showAttributeSelector) {
        return items.filter((item) => item.value !== SECURITY_CATEGORIES);
      }

      return items;
    },
  },
  mounted() {
    // For new policies in CSP namespace, automatically set the default scope
    if (this.isPolicyScopeEmpty && this.isNewCSPPolicy) {
      this.setDefaultScope();
    }
  },
  methods: {
    isAttributeScopeExperimentEnabled() {
      return (this.enabledExperiments || []).includes('security_attributes_policy_scope');
    },
    isAttributeScopeEnabled() {
      return (
        Boolean(this.glFeatures.securityAttributesPolicyScope) &&
        this.isAttributeScopeExperimentEnabled()
      );
    },
    getInitialProjectScopeType() {
      const scope = this.policyScope || {};
      const { projects = {}, groups = {} } = scope;

      if (scope.compliance_frameworks) {
        return PROJECTS_WITH_FRAMEWORK;
      }

      if (groups.including) {
        return ALL_PROJECTS_IN_LINKED_GROUPS;
      }

      if (projects.including && !groups.including?.length) {
        return SPECIFIC_PROJECTS;
      }

      const hasOnlyCategoryKeys =
        Object.keys(scope).length > 0 &&
        Object.keys(scope).every((key) => SUPPORTED_SECURITY_CATEGORY_KEYS.includes(key));

      if (hasOnlyCategoryKeys && this.isAttributeScopeEnabled()) {
        return SECURITY_CATEGORIES;
      }

      return ALL_PROJECTS_IN_GROUP;
    },
    getInitialExceptionType() {
      const { projects = {} } = this.policyScope || {};

      const hasPersonalExclusion = projects.excluding?.some(({ type }) => type === 'personal');

      if (hasPersonalExclusion) {
        return EXCEPT_PERSONAL_PROJECTS;
      }

      if (projects.excluding?.length > 0) {
        return EXCEPT_PROJECTS;
      }

      // Default for new CSP policies
      // Cannot use computed property this.isNewCSPPolicy here because it is called
      // before computed properties are defined
      if (this.designatedAsCsp && !this.existingPolicy) {
        return EXCEPT_PERSONAL_PROJECTS;
      }

      return WITHOUT_EXCEPTIONS;
    },
    getInitialGroupExceptionType() {
      const { groups = {} } = this.policyScope || {};

      if (groups.excluding?.length > 0) {
        return EXCEPT_GROUPS;
      }

      return WITHOUT_EXCEPTIONS;
    },

    getInitialPayloadKey() {
      const { projects = {}, groups = {} } = this.policyScope || {};

      if (projects.including && !groups.including?.length) {
        return INCLUDING;
      }

      return EXCLUDING;
    },

    shouldSetDefaultScope(items) {
      // Don't set default scope if these conditions aren't met
      if (this.isGroupLevel || this.hasExistingPolicy || items.length <= 1) {
        return false;
      }

      // Only set default scope if policy scope is completely empty
      return isEmpty(this.policyScope) && this.isPolicyScopeEmpty;
    },
    resetPolicyScope() {
      // For security categories, emit an empty scope so `<attribute-rows>` mounts
      // with one fresh empty row. Switching the other direction (away from
      // security categories) is handled by the structural branch below — the
      // structural payload fully replaces the previous scope, dropping category keys.
      if (this.isSecurityCategoriesScope) {
        this.$emit('changed', {});
        return;
      }

      const internalPayload =
        this.payloadKey === COMPLIANCE_FRAMEWORKS_KEY ? [] : { [this.projectsPayloadKey]: [] };
      const payload = {
        [this.payloadKey]: internalPayload,
      };

      this.$emit('changed', payload);
    },
    selectProjectScopeType(scopeType) {
      this.isFormDirty = false;

      this.selectedProjectScopeType = scopeType;
      this.projectsPayloadKey = this.isAllProjects ? EXCLUDING : INCLUDING;
      this.resetPolicyScope();
    },
    selectExceptionType(type) {
      this.isFormDirty = false;

      this.selectedExceptionType = type;
    },
    selectGroupExceptionType(type) {
      this.isFormDirty = false;

      this.selectedGroupExceptionType = type;
    },
    setSelectedItems(payload) {
      this.isFormDirty = true;
      this.triggerChanged(payload);
    },
    setAttributeScope(payload) {
      this.isFormDirty = true;
      // Security categories are mutually exclusive with structural keys, so the
      // payload from `<attribute-rows>` is the full scope — emit it as-is.
      this.$emit('changed', payload);
    },
    setSelectedFrameworkIds(ids) {
      this.isFormDirty = true;

      const payload = ids.map((id) => ({ id }));
      this.triggerChanged({ compliance_frameworks: payload });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.policyScope, ...value });
    },
    setShowAlert(errorDescription) {
      this.showAlert = true;
      this.errorDescription = errorDescription;
    },
    setDefaultScope() {
      // For CSP namespaces, default to excluding personal projects
      const payload = this.isNewCSPPolicy ? [{ type: 'personal' }] : [];
      this.triggerChanged({ projects: { excluding: payload } });
    },
    setDefaultSelectorValues() {
      this.selectedProjectScopeType = ALL_PROJECTS_IN_GROUP;
      // For CSP namespaces, default to excluding personal projects
      this.selectedExceptionType = this.isNewCSPPolicy
        ? EXCEPT_PERSONAL_PROJECTS
        : WITHOUT_EXCEPTIONS;
      this.projectsPayloadKey = EXCLUDING;
    },
    updateScopeSelection(value) {
      if (value) {
        this.$emit('remove');
        this.setDefaultSelectorValues();
      } else {
        this.setDefaultScope();
      }
    },
  },
};
</script>

<template>
  <div>
    <section-alert
      :compliance-frameworks-empty="complianceFrameworksEmpty"
      :is-dirty="isFormDirty"
      :is-projects-without-exceptions="isProjectsWithoutExceptions"
      :project-scope-type="selectedProjectScopeType"
      :project-empty="projectsEmpty"
      :groups-empty="groupsEmpty"
    />

    <gl-alert v-if="showAlert" class="gl-mb-5" variant="danger" :dismissible="false">
      {{ errorDescription }}
    </gl-alert>

    <loader-with-message v-if="showLoader" />

    <div v-else class="gl-mt-2 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <template v-if="showLinkedSppItemsError">
        <div data-testid="policy-scope-project-error" class="gl-flex gl-items-center gl-gap-3">
          <gl-icon name="status_warning" variant="danger" />
          <p data-testid="policy-scope-project-error-text" class="gl-m-0 gl-text-danger">
            {{ $options.i18n.policyScopeErrorText }}
          </p>
        </div>
      </template>

      <template v-else-if="showScopeSelector">
        <div
          :class="{ 'gl-text-disabled': disableScopeSelector }"
          class="gl-flex gl-flex-wrap gl-items-center gl-gap-3"
        >
          <gl-sprintf :message="policyScopeCopy">
            <template #projectScopeType>
              <gl-collapsible-listbox
                id="project-scope-type"
                v-gl-tooltip="{
                  title: $options.i18n.defaultModePopover,
                  disabled: !disableScopeSelector,
                }"
                fluid-width
                data-testid="project-scope-type"
                :items="scopeDropdownItems"
                :selected="selectedProjectScopeType"
                :toggle-text="selectedProjectScopeText"
                :disabled="disableScopeSelector"
                @select="selectProjectScopeType"
              />
            </template>

            <template #frameworkSelector>
              <div class="gl-inline-flex gl-flex-wrap gl-items-center gl-gap-3">
                <compliance-framework-selector
                  with-items-count
                  :disabled="disableScopeSelector"
                  :selected-framework-ids="complianceFrameworksIds"
                  :full-path="rootNamespacePath"
                  :show-error="complianceFrameworksValidState"
                  @framework-query-error="
                    setShowAlert($options.i18n.complianceFrameworkErrorDescription)
                  "
                  @select="setSelectedFrameworkIds"
                />

                <policy-popover
                  :content="$options.i18n.complianceFrameworkPopoverContent"
                  :href="$options.COMPLIANCE_FRAMEWORK_PATH"
                  :title="$options.i18n.complianceFrameworkPopoverTitle"
                  target="compliance-framework-icon"
                />
              </div>
            </template>

            <template #projectSelector>
              <group-selector
                v-if="showScopeGroupSelector"
                class="gl-basis-full"
                :is-dirty="isFormDirty"
                :exception-type="selectedExceptionType"
                :groups="groups"
                :projects="projects"
                :disabled="disableScopeSelector"
                :full-path="assignedPolicyProjectPath"
                @select-exception-type="selectExceptionType"
                @changed="setSelectedItems"
              />
              <project-selector
                v-if="showGroupProjectsDropdown"
                :disabled="disableScopeSelector"
                :is-dirty="isFormDirty"
                :exception-type="selectedExceptionType"
                :group-exception-type="selectedGroupExceptionType"
                :project-scope-type="selectedProjectScopeType"
                :projects="projects"
                :groups="groups"
                :group-full-path="rootNamespacePath"
                @error="setShowAlert($options.i18n.groupProjectErrorDescription)"
                @select-exception-type="selectExceptionType"
                @select-group-exception-type="selectGroupExceptionType"
                @changed="setSelectedItems"
              />
            </template>
          </gl-sprintf>
        </div>
        <attribute-rows
          v-if="isSecurityCategoriesScope"
          class="gl-mt-3 gl-basis-full"
          :disabled="disableScopeSelector"
          :is-dirty="isFormDirty"
          :policy-scope="policyScope"
          @changed="setAttributeScope"
          @error="setShowAlert($options.i18n.securityAttributeErrorDescription)"
        />
        <template v-if="showDefaultScopeSelector">
          <gl-form-checkbox
            v-model="useDefaultScope"
            class="gl-mt-3"
            data-testid="default-scope-selector"
            @change="updateScopeSelection"
          >
            {{ $options.i18n.defaultModeTitle }}
            <template #help>
              <gl-sprintf :message="$options.i18n.defaultModeDescription">
                <template #link="{ content }">
                  <gl-link :href="$options.SCOPE_HELP_PATH">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </template>
          </gl-form-checkbox>
        </template>
      </template>
      <template v-else>
        <p data-testid="policy-scope-project-text" class="gl-mb-0">
          {{ $options.i18n.policyScopeFrameworkCopyProject }}
        </p>
      </template>
    </div>
  </div>
</template>
