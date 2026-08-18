<script>
import { GlButton, GlFormRadioGroup, GlFormRadio, GlIcon, GlModal } from '@gitlab/ui';
import { __, s__, n__, sprintf } from '~/locale';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import { SCOPE_ALL, SCOPE_SPECIFIC } from '../constants';

export default {
  name: 'ScopeStep',
  components: {
    GlButton,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlModal,
    GroupProjectsDropdown,
  },
  inject: ['namespacePath'],
  props: {
    scope: {
      type: Object,
      required: false,
      default: () => ({ mode: SCOPE_ALL, projects: [], exclusions: [] }),
    },
  },
  emits: ['update'],
  SCOPE_ALL,
  SCOPE_SPECIFIC,
  modalId: 'policy-store-affected-projects',
  modalPrimary: { text: __('Close') },
  i18n: {
    heading: s__('PolicyStore|Which projects should this policy govern?'),
    subtitle: s__('PolicyStore|Scope sets the target projects. This can be adjusted at any time.'),
    projects: s__('PolicyStore|Projects'),
    allProjects: s__('PolicyStore|All projects'),
    allProjectsHelp: s__('PolicyStore|Every project in this group, including newly created ones'),
    specificProjects: s__('PolicyStore|Specific projects'),
    specificProjectsHelp: s__('PolicyStore|Choose individual projects to govern'),
    selectProjects: s__('PolicyStore|Select projects'),
    exclusions: s__('PolicyStore|Exclusions'),
    exclusionsHelp: s__('PolicyStore|Projects to exempt from this policy'),
    addExclusion: s__('PolicyStore|Add exclusion'),
    viewProjects: s__('PolicyStore|View projects'),
    modalTitle: s__('PolicyStore|Affected projects'),
    modalTruncated: s__('PolicyStore|Showing the first %{shown} of %{total} projects.'),
  },
  apollo: {
    groupProjects: {
      query: getGroupProjects,
      variables() {
        return { fullPath: this.namespacePath, withCount: true };
      },
      update(data) {
        return data?.group?.projects || { nodes: [], count: 0 };
      },
      error() {
        this.groupProjects = { nodes: [], count: 0 };
      },
      skip() {
        // In specific mode the count comes from the selection and the projects
        // come from GroupProjectsDropdown, so this query would just duplicate
        // the dropdown's request. Only "all projects" needs the group total.
        return !this.namespacePath || this.isSpecific;
      },
    },
  },
  data() {
    return {
      mode: this.scope.mode || SCOPE_ALL,
      selectedProjects: this.scope.projects || [],
      exclusions: this.scope.exclusions || [],
      showExclusions: Boolean(this.scope.exclusions?.length),
      showModal: false,
      groupProjects: { nodes: [], count: 0 },
    };
  },
  computed: {
    isSpecific() {
      return this.mode === SCOPE_SPECIFIC;
    },
    selectedProjectIds() {
      return this.selectedProjects.map(({ id }) => id);
    },
    excludedProjectIds() {
      return this.exclusions.map(({ id }) => id);
    },
    baseCount() {
      return this.isSpecific ? this.selectedProjects.length : this.groupProjects.count;
    },
    affectedCount() {
      return Math.max(this.baseCount - this.exclusions.length, 0);
    },
    affectedLabel() {
      return n__('%d project affected', '%d projects affected', this.affectedCount);
    },
    modalProjects() {
      const projects = this.isSpecific ? this.selectedProjects : this.groupProjects.nodes;
      const excludedIds = new Set(this.excludedProjectIds);
      return projects.filter(({ id }) => !excludedIds.has(id));
    },
    modalTruncated() {
      return !this.isSpecific && this.groupProjects.nodes.length < this.groupProjects.count;
    },
    modalNote() {
      return sprintf(this.$options.i18n.modalTruncated, {
        shown: this.modalProjects.length,
        total: this.groupProjects.count,
      });
    },
  },
  methods: {
    cardClass(value) {
      return this.mode === value ? 'gl-border-strong gl-bg-subtle' : 'gl-border-default';
    },
    addExclusion() {
      this.showExclusions = true;
    },
    openModal() {
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
    },
    onModeChange(mode) {
      this.mode = mode;
      this.emitUpdate();
    },
    onProjectsSelect(projects) {
      this.selectedProjects = projects;
      this.emitUpdate();
    },
    onExclusionsSelect(projects) {
      this.exclusions = projects;
      this.emitUpdate();
    },
    emitUpdate() {
      this.$emit('update', {
        mode: this.mode,
        projects: this.selectedProjects,
        exclusions: this.exclusions,
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <div>
      <h3 class="gl-heading-3 gl-mb-1">{{ $options.i18n.heading }}</h3>
      <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.subtitle }}</p>
    </div>

    <div>
      <span class="gl-mb-2 gl-block gl-font-bold">{{ $options.i18n.projects }}</span>
      <gl-form-radio-group :checked="mode" @change="onModeChange">
        <div
          class="gl-mb-3 gl-rounded-base gl-border-1 gl-border-solid gl-p-4"
          :class="cardClass($options.SCOPE_ALL)"
        >
          <gl-form-radio :value="$options.SCOPE_ALL">
            {{ $options.i18n.allProjects }}
            <template #help>{{ $options.i18n.allProjectsHelp }}</template>
          </gl-form-radio>
        </div>
        <div
          class="gl-rounded-base gl-border-1 gl-border-solid gl-p-4"
          :class="cardClass($options.SCOPE_SPECIFIC)"
        >
          <gl-form-radio :value="$options.SCOPE_SPECIFIC">
            {{ $options.i18n.specificProjects }}
            <template #help>{{ $options.i18n.specificProjectsHelp }}</template>
          </gl-form-radio>
        </div>
      </gl-form-radio-group>

      <div v-if="isSpecific" class="gl-mt-3">
        <label class="gl-mb-2 gl-block gl-text-sm gl-text-subtle">
          {{ $options.i18n.selectProjects }}
        </label>
        <group-projects-dropdown
          :group-full-path="namespacePath"
          :selected="selectedProjectIds"
          :state="true"
          @select="onProjectsSelect"
        />
      </div>
    </div>

    <div>
      <span class="gl-font-bold">{{ $options.i18n.exclusions }}</span>
      <span class="gl-ml-2 gl-text-sm gl-text-subtle">{{ $options.i18n.exclusionsHelp }}</span>
      <div class="gl-mt-2">
        <gl-button
          v-if="!showExclusions"
          category="tertiary"
          size="small"
          icon="plus"
          data-testid="add-exclusion"
          @click="addExclusion"
        >
          {{ $options.i18n.addExclusion }}
        </gl-button>
        <group-projects-dropdown
          v-else
          :group-full-path="namespacePath"
          :selected="excludedProjectIds"
          :state="true"
          @select="onExclusionsSelect"
        />
      </div>
    </div>

    <div class="gl-flex gl-items-center gl-justify-between">
      <span class="gl-flex gl-items-center gl-gap-2 gl-text-sm gl-text-subtle">
        <gl-icon name="project" :size="14" />
        <span data-testid="affected-count">{{ affectedLabel }}</span>
      </span>
      <gl-button variant="link" data-testid="view-projects" @click="openModal">
        {{ $options.i18n.viewProjects }}
      </gl-button>
    </div>

    <gl-modal
      :modal-id="$options.modalId"
      :visible="showModal"
      :title="$options.i18n.modalTitle"
      :action-primary="$options.modalPrimary"
      @primary="closeModal"
      @hidden="closeModal"
    >
      <ul class="gl-m-0 gl-list-none gl-p-0">
        <li
          v-for="project in modalProjects"
          :key="project.id"
          class="gl-border-b-1 gl-border-b-default gl-py-2 gl-border-b-solid last:gl-border-b-0"
        >
          <span class="gl-block gl-text-sm">{{ project.fullPath }}</span>
        </li>
      </ul>
      <p v-if="modalTruncated" class="gl-mb-0 gl-mt-3 gl-text-sm gl-text-subtle">{{ modalNote }}</p>
    </gl-modal>
  </div>
</template>
