<script>
import {
  GlAlert,
  GlBadge,
  GlDrawer,
  GlButton,
  GlLabel,
  GlLink,
  GlLoadingIcon,
  GlSprintf,
  GlPopover,
  GlToastMixin,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { isTopLevelGroup, getControls, getPolicyUrl } from '../../utils';
import { POLICY_SCOPES_DOCS_URL, EXTERNAL_CONTROL_LABEL, i18n as mainI18n } from '../../constants';
import DrawerAccordion from '../shared/drawer_accordion.vue';
import complianceRequirementControlsQuery from '../../graphql/compliance_requirement_controls.query.graphql';
import projectsInNamespaceWithFrameworkQuery from './graphql/projects_in_namespace_with_framework.query.graphql';

export default {
  name: 'FrameworkInfoDrawer',
  components: {
    GlAlert,
    GlBadge,
    GlDrawer,
    GlButton,
    GlLabel,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    GlPopover,
    HelpIcon,
    DrawerAccordion,
  },
  mixins: [GlToastMixin],
  inject: ['groupSecurityPoliciesPath', 'canAccessRootAncestorComplianceCenter'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    framework: {
      type: Object,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  emits: ['edit', 'close', 'load-more-policies'],
  data() {
    return {
      after: null,
      controls: [],
      projects: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
        },
        count: 0,
      },
      error: null,
    };
  },
  apollo: {
    projects: {
      query: projectsInNamespaceWithFrameworkQuery,
      skip() {
        return !this.framework?.id || !this.groupPath;
      },
      variables() {
        return {
          fullPath: this.groupPath,
          frameworkId: this.framework?.id,
          after: this.after,
        };
      },
      update(data) {
        const isInitialLoad = !this.after;
        const incomingProjects = data.namespace.projects;

        if (isInitialLoad) {
          return incomingProjects;
        }
        const existingIds = new Set(this.projects.nodes.map((node) => node.id));
        const newUniqueNodes = incomingProjects.nodes.filter((node) => !existingIds.has(node.id));

        return {
          ...incomingProjects,
          nodes: [...this.projects.nodes, ...newUniqueNodes],
        };
      },
    },
    controls: {
      query: complianceRequirementControlsQuery,
      update: (data) => data.complianceRequirementControls.controlExpressions || [],
      error(error) {
        this.error = s__(
          'ComplianceFrameworks|Error fetching compliance requirements controls data. Please refresh the page.',
        );
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    editDisabled() {
      return !isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    showDrawer() {
      return Boolean(this.framework);
    },
    getContentWrapperHeight() {
      return getContentWrapperHeight();
    },
    defaultFramework() {
      return Boolean(this.framework.default);
    },
    associatedProjectsTitle() {
      return this.$options.i18n.associatedProjects;
    },
    associatedProjectsCount() {
      return this.projects.count;
    },
    policies() {
      return this.framework.securityPolicies.nodes;
    },
    hasMorePolicies() {
      return this.framework.securityPolicies.pageInfo?.hasNextPage;
    },
    policiesTitle() {
      return this.$options.i18n.policies;
    },
    policiesCount() {
      return this.hasMorePolicies ? `${this.policies.length}+` : this.policies.length;
    },
    normalisedFrameworkId() {
      return getIdFromGraphQLId(this.framework.id);
    },
    controlsForRequirement() {
      return (requirementControls) => {
        return this.getControls(requirementControls, this.controls);
      };
    },
    orderedRequirements() {
      const requirements = [...(this.framework.complianceRequirements?.nodes || [])];
      return (
        requirements.sort((a, b) => {
          const idA = getIdFromGraphQLId(a.id);
          const idB = getIdFromGraphQLId(b.id);
          return Number(idA) - Number(idB);
        }) || []
      );
    },
  },
  watch: {
    framework: {
      handler(newFramework, oldFramework) {
        const oldId = oldFramework?.id ?? null;
        const newId = newFramework?.id ?? null;

        if (oldId !== newId) {
          this.projects = {
            nodes: [],
            pageInfo: {
              hasNextPage: false,
            },
            count: 0,
          };
          this.after = null;
        }
      },
      immediate: false,
    },
  },
  methods: {
    getPolicyEditUrl(policy) {
      return getPolicyUrl(policy, this.groupPath, this.groupSecurityPoliciesPath);
    },
    loadMoreProjects() {
      this.after = this.projects.pageInfo.endCursor;
    },
    loadMorePolicies() {
      this.$emit('load-more-policies', {
        frameworkId: this.framework.id,
        after: this.framework.securityPolicies.pageInfo.endCursor,
      });
    },
    async copyFrameworkIdToClipboard() {
      await copyToClipboard(String(this.normalisedFrameworkId));
      this.$toast.show(this.$options.i18n.copyFrameworkIdToastText);
    },
    async copyControlIdToClipboard(control) {
      await copyToClipboard(String(getIdFromGraphQLId(control.id)));
      this.$toast.show(this.$options.i18n.copyControlIdToastText);
    },
    getControls(expression) {
      return getControls(expression, this.controls);
    },
    isExternalControl(control) {
      return control.controlType === this.$options.CONTROL_TYPE_EXTERNAL;
    },
  },
  DRAWER_Z_INDEX,
  POLICY_SCOPES_DOCS_URL,
  EXTERNAL_CONTROL_LABEL,
  CONTROL_TYPE_EXTERNAL: 'external',
  i18n: {
    defaultFramework: s__('ComplianceFrameworksReport|Default'),
    editFramework: s__('ComplianceFrameworksReport|Edit framework'),
    editFrameworkButtonMessage: s__(
      'ComplianceFrameworks|You must edit the compliance framework in top-level group %{linkStart}namespace%{linkEnd}',
    ),
    tooltipMessageNoAccess: mainI18n.tooltipMessageNoAccess,
    frameworkIdTitle: s__('ComplianceFrameworksReport|Compliance framework ID'),
    frameworkIdPopoverTitle: s__('ComplianceFrameworksReport|Using the ID'),
    frameworkIdPopoverText: s__(
      'ComplianceFrameworksReport|Use the compliance framework ID in configuration or API requests. %{linkStart}Learn more.%{linkEnd}',
    ),
    copyIdButtonText: s__('ComplianceFrameworksReport|Copy ID'),
    copyFrameworkIdToastText: s__('ComplianceFrameworksReport|Framework ID copied to clipboard.'),
    copyControlIdToastText: s__('ComplianceFrameworksReport|Control ID copied to clipboard.'),
    frameworkDescription: s__('ComplianceFrameworksReport|Description'),
    associatedProjects: s__('ComplianceFrameworksReport|Associated Projects'),
    policies: s__('ComplianceFrameworksReport|Policies'),
    complianceRequirements: s__('ComplianceFrameworksReport|Requirements'),
    controls: s__('ComplianceFrameworksReport|Controls'),
    noControlsText: s__('ComplianceFrameworksReport|No controls'),
  },
};
</script>

<template>
  <gl-drawer
    :open="showDrawer"
    :header-height="getContentWrapperHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template v-if="framework" #title>
      <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-4">
        <h2 class="gl-heading-2" data-testid="framework-name">
          {{ framework.name }}
        </h2>
        <gl-label
          v-if="defaultFramework"
          class="gl-mb-5"
          :background-color="framework.color"
          :title="$options.i18n.defaultFramework"
        />
      </div>
    </template>

    <template v-if="framework" #header>
      <gl-popover
        v-if="editDisabled"
        target="framework-info-drawer-edit-button"
        placement="left"
        boundary="viewport"
        data-testid="edit-framework-popover"
      >
        <gl-sprintf
          v-if="canAccessRootAncestorComplianceCenter"
          :message="$options.i18n.editFrameworkButtonMessage"
        >
          <template #link>
            <gl-link :href="rootAncestor.complianceCenterPath">{{ rootAncestor.name }}</gl-link>
          </template>
        </gl-sprintf>
        <gl-sprintf v-else :message="$options.i18n.tooltipMessageNoAccess">
          <template #strong>
            <strong>{{ rootAncestor.name }}</strong>
          </template>
        </gl-sprintf>
      </gl-popover>
      <span id="framework-info-drawer-edit-button">
        <gl-button
          :disabled="editDisabled"
          category="primary"
          variant="confirm"
          data-testid="edit-framework-btn"
          @click="$emit('edit', framework)"
        >
          {{ $options.i18n.editFramework }}
        </gl-button>
      </span>
    </template>

    <template v-if="framework" #default>
      <div class="-gl-mx-5 gl-flex gl-flex-col">
        <div data-testid="sidebar-id" class="gl-mb-5 gl-px-5">
          <div class="gl-flex gl-items-baseline">
            <h3 class="gl-heading-3" data-testid="sidebar-id-title">
              {{ $options.i18n.frameworkIdTitle }}
            </h3>
            <help-icon id="framework-id-info" class="gl-mb-5 gl-ml-3" />
            <gl-popover
              target="framework-id-info"
              placement="top"
              boundary="viewport"
              :title="$options.i18n.frameworkIdPopoverTitle"
            >
              <gl-sprintf :message="$options.i18n.frameworkIdPopoverText">
                <template #link="{ content }">
                  <gl-link
                    :href="$options.POLICY_SCOPES_DOCS_URL"
                    target="blank"
                    rel="noopener noreferrer nofollow"
                  >
                    {{ content }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </gl-popover>
          </div>
          <div class="gl-flex">
            <span data-testid="framework-id">{{ normalisedFrameworkId }}</span>
            <gl-button
              class="gl-ml-3"
              variant="link"
              data-testid="copy-framework-id-button"
              @click="copyFrameworkIdToClipboard"
              >{{ $options.i18n.copyIdButtonText }}</gl-button
            >
          </div>
        </div>
        <div class="gl-border-t gl-mb-5 gl-px-5">
          <h3 class="gl-heading-3 gl-mt-5" data-testid="sidebar-description-title">
            {{ $options.i18n.frameworkDescription }}
          </h3>
          <span data-testid="sidebar-description">
            {{ framework.description }}
          </span>
        </div>
        <div data-testid="requirements">
          <gl-alert v-if="error" variant="danger" @dismiss="error = null"> {{ error }} </gl-alert>
          <div class="gl-border-t gl-mb-5">
            <div class="gl-flex gl-items-center gl-gap-1">
              <h3 data-testid="sidebar-requirements-title" class="gl-heading-3 gl-mt-5 gl-px-5">
                {{ $options.i18n.complianceRequirements }}
              </h3>
              <gl-badge class="gl-ml-2" variant="neutral" data-testid="requirements-count-badge">
                <template v-if="$apollo.queries.controls.loading">
                  <gl-loading-icon size="sm" />
                </template>
                <template v-else>{{ framework.complianceRequirements.nodes.length }}</template>
              </gl-badge>
            </div>
            <drawer-accordion :items="orderedRequirements" class="!gl-p-0">
              <template #header="{ item: requirement }">
                <h4 class="gl-heading-4 gl-mb-3">{{ requirement.name }}</h4>
              </template>
              <template #default="{ item: requirement }">
                <template v-if="requirement.complianceRequirementsControls.nodes.length">
                  <h4 class="gl-font-bold gl-text-default">{{ $options.i18n.controls }}:</h4>
                  <ul class="-gl-ml-6">
                    <li
                      v-for="control in controlsForRequirement(
                        requirement.complianceRequirementsControls.nodes,
                      )"
                      :key="control.id"
                    >
                      {{ control.displayValue }}
                      <gl-badge v-if="isExternalControl(control)">
                        {{ $options.EXTERNAL_CONTROL_LABEL }}
                      </gl-badge>
                      <gl-button
                        v-if="isExternalControl(control)"
                        class="gl-ml-3"
                        variant="link"
                        data-testid="copy-control-id-button"
                        @click="copyControlIdToClipboard(control)"
                      >
                        {{ $options.i18n.copyIdButtonText }}
                      </gl-button>
                    </li>
                  </ul>
                </template>
                <template v-else>
                  <p class="gl-mt-3 gl-text-subtle">{{ $options.i18n.noControlsText }}</p>
                </template>
              </template>
            </drawer-accordion>
          </div>
        </div>
        <div v-if="framework.projects" class="gl-border-t gl-px-5" data-testid="sidebar-projects">
          <div class="gl-flex gl-items-center gl-gap-1">
            <h3 data-testid="sidebar-projects-title" class="gl-heading-3 gl-mt-5">
              {{ associatedProjectsTitle }}
            </h3>
            <gl-badge class="gl-ml-3" variant="neutral">
              <template v-if="!associatedProjectsCount && $apollo.queries.projects.loading">
                <gl-loading-icon size="sm" />
              </template>
              <template v-else>{{ associatedProjectsCount }}</template>
            </gl-badge>
          </div>
          <ul v-if="projects.nodes.length" class="gl-pl-5">
            <li
              v-for="associatedProject in projects.nodes"
              :key="associatedProject.id"
              class="gl-mt-1"
            >
              <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link>
            </li>
          </ul>
          <gl-button
            v-if="projects.pageInfo.hasNextPage"
            class="gl-mb-5"
            category="tertiary"
            variant="confirm"
            size="small"
            :loading="$apollo.queries.projects.loading"
            @click="loadMoreProjects"
          >
            {{ __('Load more') }}
          </gl-button>
        </div>
        <div class="gl-border-t gl-px-5" data-testid="sidebar-policies">
          <div class="gl-flex gl-items-center gl-gap-1">
            <h3 data-testid="sidebar-policies-title" class="gl-heading-3 gl-mt-5">
              {{ policiesTitle }}
            </h3>
            <gl-badge class="gl-ml-3" variant="neutral">{{ policiesCount }}</gl-badge>
          </div>
          <ul v-if="policies.length" class="gl-pl-5">
            <li v-for="(policy, idx) in policies" :key="idx" class="gl-mt-1">
              <gl-link :href="getPolicyEditUrl(policy)">{{ policy.name }}</gl-link>
            </li>
          </ul>
          <gl-button
            v-if="hasMorePolicies"
            class="gl-mb-5"
            category="tertiary"
            variant="confirm"
            size="small"
            @click="loadMorePolicies"
          >
            {{ __('Show more') }}
          </gl-button>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
