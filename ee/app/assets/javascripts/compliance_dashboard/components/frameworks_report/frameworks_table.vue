<script>
import {
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlTable,
  GlLink,
  GlSprintf,
  GlButton,
  GlAlert,
  GlDisclosureDropdown,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import FrameworkBadge from '../shared/framework_badge.vue';
import {
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_EXPORT_FRAMEWORK,
  CREATE_FRAMEWORKS_DOCS_URL,
} from '../../constants';
import { isTopLevelGroup, convertFrameworkIdToGraphQl } from '../../utils';
import updateComplianceFrameworkMutation from '../../graphql/mutations/update_compliance_framework.mutation.graphql';
import FrameworkInfoDrawer from './framework_info_drawer.vue';
import DeleteModal from './wizard/components/delete_modal.vue';

export default {
  name: 'FrameworksTable',
  components: {
    DeleteModal,
    FrameworkInfoDrawer,
    FrameworkBadge,
    GlLoadingIcon,
    GlSearchBoxByClick,
    GlTable,
    GlLink,
    GlAlert,
    GlDisclosureDropdown,
    GlButton,
    GlSprintf,
    TimeAgo,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  inject: ['policyDisplayLimit'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
    frameworks: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    namespaceId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['delete-framework', 'search', 'sort-changed', 'update-frameworks', 'load-more-policies'],
  data() {
    return {
      frameworkToDeleteName: null,
      frameworkToDeleteId: null,
    };
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    hasSearch() {
      // Search is not supported for project frameworks
      return !this.projectPath;
    },
    selectedFramework() {
      return this.$route.query.id
        ? this.frameworks.find(
            (framework) => framework.id === convertFrameworkIdToGraphQl(this.$route.query.id),
          )
        : null;
    },
    showNoFrameworksAlert() {
      return !this.frameworks.length && !this.isLoading && !this.isTopLevelGroup;
    },
    tableFields() {
      const omittedFields = [];
      if (this.projectPath || !this.isTopLevelGroup) {
        omittedFields.push('associatedProjects');
      }

      return omittedFields.length === 0
        ? this.$options.fields
        : this.$options.fields.filter((f) => !omittedFields.includes(f.key));
    },
  },
  methods: {
    getIdFromGraphQLId,
    async toggleDrawer(item) {
      this.closeDrawer();

      if (this.selectedFramework?.id !== item.id) {
        await this.$nextTick();
        this.openDrawer(item);
      }
    },
    async copyFrameworkId(id) {
      await copyToClipboard(String(getIdFromGraphQLId(id)));
      this.$toast.show(this.$options.i18n.copyIdToastText);
      this.$refs[`framework-dropdown-${id}`].closeAndFocus();
    },
    showDeleteModal(framework) {
      this.frameworkToDeleteName = framework.name;
      this.frameworkToDeleteId = framework.id;
      this.$refs.deleteModal.show();
    },
    openDrawer(item) {
      this.$router.push({ query: { id: getIdFromGraphQLId(item.id) } });
    },
    closeDrawer() {
      this.$router.push({ query: null });
    },
    isLastItem(index, arr) {
      return index >= arr.length - 1;
    },
    showPolicySeparator(index, securityPolicies) {
      return (
        !this.isLastItem(index, securityPolicies.nodes) || securityPolicies.pageInfo?.hasNextPage
      );
    },
    editFramework({ id }) {
      this.$router.push({ name: ROUTE_EDIT_FRAMEWORK, params: { id: getIdFromGraphQLId(id) } });
    },
    async updateDefaultFramework({ framework, isDefault }) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateComplianceFrameworkMutation,
          variables: {
            input: {
              id: framework.id,
              params: {
                default: isDefault,
              },
            },
          },
        });
        const errors = data?.updateComplianceFramework?.errors;

        if (errors && errors.length) {
          throw new Error(errors.join(', '));
        }

        this.$emit('update-frameworks');

        this.$toast.show(
          isDefault
            ? this.$options.i18n.setAsDefaultFrameworkSuccess
            : this.$options.i18n.removeAsDefaultFrameworkSuccess,
        );
      } catch (error) {
        this.$toast.show(
          isDefault
            ? this.$options.i18n.setAsDefaultFrameworkError
            : this.$options.i18n.removeAsDefaultFrameworkError,
        );
        Sentry.captureException(error, {
          tags: {
            vue_component: 'frameworks_table',
          },
        });
      }
    },
    async exportFramework(framework) {
      try {
        const frameworkId = getIdFromGraphQLId(framework.id);
        const downloadUrl = this.$router.resolve({
          name: ROUTE_EXPORT_FRAMEWORK,
          params: {
            id: frameworkId,
          },
        }).href;
        window.location.href = downloadUrl;
        this.$refs[`framework-dropdown-${framework.id}`].closeAndFocus();
      } catch (error) {
        this.$toast.show(s__('ComplianceFrameworksReport|Failed to export framework'));
        Sentry.captureException(error, {
          tags: {
            vue_component: 'frameworks_table',
          },
        });
      }
    },
    getSetAsDefaultActionTooltipTitle(framework) {
      if (framework.default) {
        return this.$options.i18n.removeAsDefaultFrameworkTooltip;
      }
      return this.$options.i18n.setAsDefaultFrameworkTooltip;
    },
    shouldDisableDeleteAction(framework) {
      const isInherited =
        this.getIdFromGraphQLId(framework.namespaceId) !==
        this.getIdFromGraphQLId(this.namespaceId);
      const hasPolicies =
        framework.securityPolicies.nodes.length > 0 ||
        Boolean(framework.securityPolicies.pageInfo?.hasNextPage);
      return framework.default || hasPolicies || isInherited;
    },
    getDeleteActionTooltipTitle(framework) {
      if (this.shouldDisableDeleteAction(framework)) {
        return framework.default
          ? this.$options.i18n.deleteButtonDefaultFrameworkDisabledTooltip
          : this.$options.i18n.deleteButtonLinkedPoliciesDisabledTooltip;
      }
      return '';
    },
    remainingProjectsCount(projects) {
      return projects.count - projects.nodes.length;
    },
    remainingRequirementsCount(requirements) {
      return requirements.nodes.length - this.policyDisplayLimit;
    },
    lastVisiblePolicyIndex(requirements) {
      return Math.min(requirements.length, this.policyDisplayLimit) - 1;
    },
    isFrameworkInherited(framework) {
      if (!framework.namespaceId || !this.namespaceId) {
        return false;
      }
      return (
        this.getIdFromGraphQLId(framework.namespaceId) !== this.getIdFromGraphQLId(this.namespaceId)
      );
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Frameworks'),
      thClass: '@md/panel:gl-max-w-26 !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'source',
      label: __('Source'),
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'requirements',
      label: __('Requirements'),
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'associatedProjects',
      label: __('Associated projects'),
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'policies',
      label: __('Policies'),
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer gl-break-words',
      sortable: false,
    },
    {
      key: 'updatedAt',
      label: __('Last updated'),
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: '@md/panel:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'action',
      label: __('Action'),
      thAlignRight: true,
      thClass: '@md/panel:gl-max-w-26 gl-whitespace-nowrap',
      tdClass: '@md/panel:gl-max-w-26 !gl-text-right gl-cursor-pointer',
      sortable: false,
    },
  ],
  i18n: {
    dropdownTitle: __('Manage framework'),
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),
    noFrameworksText: s__(
      'ComplianceFrameworks|No frameworks found. Create a framework in top-level group',
    ),
    learnMore: __('Learn more'),
    copyIdToastText: s__('ComplianceFrameworksReport|Framework ID copied to clipboard.'),
    actionCopyId: s__('ComplianceFrameworksReport|Copy ID'),
    copyIdExplanation: s__(
      'ComplianceFrameworksReport|Use the compliance framework ID in configuration or API requests.',
    ),
    actionEdit: __('Edit'),
    actionExport: __('Export as a JSON file'),
    actionDelete: __('Delete'),
    actionSetAsDefault: __('Set as default'),
    actionRemoveAsDefault: __('Remove as default'),
    toggleText: __('Actions for'),
    deleteButtonLinkedPoliciesDisabledTooltip: s__(
      "ComplianceFrameworks|Compliance frameworks that are linked to an active policy can't be deleted",
    ),
    deleteButtonDefaultFrameworkDisabledTooltip: s__(
      "ComplianceFrameworks|The default framework can't be deleted",
    ),
    andMore: s__('ComplianceReport|and %{count} more'),
    policiesAndMore: s__('ComplianceReport|, and more'),
    setAsDefaultFrameworkSuccess: s__(
      'ComplianceFrameworksReport|Default framework set successfully',
    ),
    setAsDefaultFrameworkError: s__('ComplianceFrameworksReport|Failed to set default framework'),
    setAsDefaultFrameworkTooltip: s__('ComplianceFrameworksReport|Set as default framework'),
    removeAsDefaultFrameworkSuccess: s__(
      'ComplianceFrameworksReport|Default framework removed successfully',
    ),
    removeAsDefaultFrameworkError: s__(
      'ComplianceFrameworksReport|Failed to remove default framework',
    ),
    removeAsDefaultFrameworkTooltip: s__('ComplianceFrameworksReport|Remove as default framework'),
    sourceThisGroupText: __('This group'),
    sourceCspGroupText: __('CSP group'),
  },
  CREATE_FRAMEWORKS_DOCS_URL,
};
</script>
<template>
  <section>
    <div v-if="hasSearch" class="gl-flex gl-gap-4 gl-bg-subtle gl-p-4">
      <gl-search-box-by-click
        class="gl-grow"
        @submit="$emit('search', $event)"
        @clear="$emit('search', '')"
      />
    </div>
    <gl-alert
      v-if="showNoFrameworksAlert"
      variant="info"
      data-testid="no-frameworks-alert"
      :dismissible="false"
    >
      <div>
        {{ $options.i18n.noFrameworksText }}
        <gl-link :href="rootAncestor.complianceCenterPath"> {{ rootAncestor.name }}</gl-link
        >.
        <gl-link :href="$options.CREATE_FRAMEWORKS_DOCS_URL"
          >{{ $options.i18n.learnMore }}.</gl-link
        >
      </div>
    </gl-alert>
    <gl-table
      :fields="tableFields"
      :busy="isLoading"
      :items="frameworks"
      no-local-sorting
      show-empty
      stacked="md"
      hover
      @row-clicked="toggleDrawer"
      @sort-changed="$emit('sort-changed', $event)"
    >
      <template #cell(name)="{ item }">
        <framework-badge
          :framework="item"
          :popover-mode="isTopLevelGroup ? 'edit' : 'details'"
          :show-default="!isFrameworkInherited(item)"
        />
      </template>
      <template #cell(source)="{ item }">
        <span v-if="!isFrameworkInherited(item)">
          {{ $options.i18n.sourceThisGroupText }}
        </span>
        <span v-else>
          {{ $options.i18n.sourceCspGroupText }}
        </span>
      </template>
      <template #cell(requirements)="{ item: { complianceRequirements: requirements } }">
        <div
          v-for="(requirement, index) in requirements.nodes.slice(0, policyDisplayLimit)"
          :key="requirement.id"
          class="gl-inline-block"
          data-testid="requirement-item"
        >
          {{ requirement.name
          }}<span v-if="index < lastVisiblePolicyIndex(requirements.nodes)">,&nbsp;</span>
        </div>
        <template v-if="remainingRequirementsCount(requirements) > 0">
          <gl-sprintf :message="$options.i18n.andMore">
            <template #count>{{ remainingRequirementsCount(requirements) }}</template>
          </gl-sprintf>
        </template>
      </template>
      <template #cell(associatedProjects)="{ item: { projects } }">
        <div
          v-for="(associatedProject, index) in projects.nodes"
          :key="associatedProject.id"
          class="gl-inline-block"
        >
          <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link
          ><span v-if="!isLastItem(index, projects.nodes)">,&nbsp;</span>
        </div>
        <template v-if="projects.pageInfo.hasNextPage">
          <gl-sprintf :message="$options.i18n.andMore">
            <template #count>{{ remainingProjectsCount(projects) }}</template>
          </gl-sprintf>
        </template>
      </template>
      <template #cell(policies)="{ item: { securityPolicies } }">
        <span
          v-for="(policy, index) in securityPolicies.nodes"
          :key="policy.name"
          class="gl-inline-block"
          >{{ policy.name
          }}<template v-if="showPolicySeparator(index, securityPolicies)">, </template></span
        >
        <span v-if="securityPolicies.pageInfo?.hasNextPage">{{
          $options.i18n.policiesAndMore
        }}</span>
      </template>
      <template #cell(updatedAt)="{ item }">
        <time-ago :time="item.updatedAt" />
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #cell(action)="{ item }">
        <gl-disclosure-dropdown
          :ref="`framework-dropdown-${item.id}`"
          icon="ellipsis_v"
          :toggle-text="`${$options.i18n.toggleText} ${item.name}`"
          text-sr-only
          category="tertiary"
          placement="bottom-end"
          no-caret
        >
          <template #header>
            <div class="gl-border-b gl-border-b-dropdown gl-p-4 gl-text-left">
              <span class="gl-font-bold">
                {{ $options.i18n.dropdownTitle }}
              </span>
            </div>
          </template>
          <template v-if="!isTopLevelGroup">
            <div class="gl-mx-2">
              <gl-button
                v-gl-tooltip.left.viewport
                data-testid="action-copy-id"
                :title="$options.i18n.copyIdExplanation"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="copyFrameworkId(item.id)"
              >
                {{ $options.i18n.actionCopyId }}: {{ getIdFromGraphQLId(item.id) }}
              </gl-button>
            </div>
          </template>
          <template v-if="isTopLevelGroup">
            <div class="gl-mx-2">
              <gl-button
                v-if="isTopLevelGroup"
                data-testid="action-edit"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="editFramework({ id: item.id })"
              >
                {{ $options.i18n.actionEdit }}
              </gl-button>
            </div>
            <div
              v-if="isTopLevelGroup"
              v-gl-tooltip.left.viewport
              class="gl-mx-2"
              data-testid="set-as-default-tooltip"
              :title="getSetAsDefaultActionTooltipTitle(item)"
            >
              <gl-button
                data-testid="action-set-as-default"
                class="!gl-justify-start !gl-border-none"
                category="tertiary"
                :block="true"
                :disabled="isFrameworkInherited(item)"
                @click="updateDefaultFramework({ framework: item, isDefault: !item.default })"
              >
                {{
                  item.default
                    ? $options.i18n.actionRemoveAsDefault
                    : $options.i18n.actionSetAsDefault
                }}
              </gl-button>
            </div>
            <div class="gl-mx-2">
              <gl-button
                v-gl-tooltip.left.viewport
                data-testid="action-copy-id"
                :title="$options.i18n.copyIdExplanation"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="copyFrameworkId(item.id)"
              >
                {{ $options.i18n.actionCopyId }}: {{ getIdFromGraphQLId(item.id) }}
              </gl-button>
            </div>
            <div v-if="isTopLevelGroup" class="gl-mx-2">
              <gl-button
                data-testid="action-export"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="exportFramework(item)"
              >
                {{ $options.i18n.actionExport }}
              </gl-button>
            </div>
            <div
              v-if="isTopLevelGroup"
              v-gl-tooltip.left.viewport
              class="gl-mx-2"
              data-testid="delete-tooltip"
              :title="getDeleteActionTooltipTitle(item)"
            >
              <gl-button
                data-testid="action-delete"
                class="!gl-justify-start !gl-border-none"
                category="tertiary"
                :block="true"
                :disabled="shouldDisableDeleteAction(item)"
                @click="showDeleteModal(item)"
              >
                {{ $options.i18n.actionDelete }}
              </gl-button>
            </div>
          </template>
        </gl-disclosure-dropdown>
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center">
          {{ $options.i18n.noFrameworksFound }}
        </div>
      </template>
    </gl-table>
    <framework-info-drawer
      :group-path="groupPath"
      :root-ancestor="rootAncestor"
      :framework="selectedFramework"
      @close="closeDrawer"
      @edit="editFramework"
      @load-more-policies="$emit('load-more-policies', $event)"
    />
    <delete-modal
      ref="deleteModal"
      :name="frameworkToDeleteName || ''"
      @delete="$emit('delete-framework', frameworkToDeleteId)"
    />
  </section>
</template>
