<script>
import { GlBadge, GlButton, GlFormCheckbox, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
const COMPLIANCE_FRAMEWORKS = [
  'PCI-DSS',
  'SOC 2 Type II',
  'ISO 27001',
  'HIPAA',
  'FedRAMP',
  'GDPR',
  'NIST CSF',
];
/* eslint-enable @gitlab/require-i18n-strings */

const CRITICALITY_OPTIONS = [
  s__('SecurityOrchestration|Critical'),
  s__('SecurityOrchestration|High'),
  s__('SecurityOrchestration|Medium'),
  s__('SecurityOrchestration|Low'),
];
const EXPOSURE_OPTIONS = [
  s__('SecurityOrchestration|Public'),
  s__('SecurityOrchestration|Internal'),
  s__('SecurityOrchestration|Private'),
];
const CLASSIFICATION_OPTIONS = [
  s__('SecurityOrchestration|Restricted'),
  s__('SecurityOrchestration|Confidential'),
  s__('SecurityOrchestration|Internal'),
  s__('SecurityOrchestration|Public'),
];

const AFFECTED_COUNTS = {
  security_attributes: '150',
  groups: '183',
  compliance_frameworks: '95',
  projects: '12',
};

export default {
  name: 'ScopeStep',
  SCOPE_ALL: 'all',
  SCOPE_TARGETED: 'targeted',
  TARGET_BY_OPTIONS: [
    {
      value: 'security_attributes',
      label: s__('SecurityOrchestration|Security Attributes'),
      description: s__(
        'SecurityOrchestration|Target by business criticality, data classification, or external exposure',
      ),
      recommended: true,
    },
    {
      value: 'groups',
      label: s__('SecurityOrchestration|Groups'),
      description: s__('SecurityOrchestration|All projects within one or more groups or subgroups'),
    },
    {
      value: 'compliance_frameworks',
      label: s__('SecurityOrchestration|Compliance Frameworks'),
      description: s__('SecurityOrchestration|Projects assigned to specific compliance frameworks'),
    },
    {
      value: 'projects',
      label: s__('SecurityOrchestration|Projects'),
      description: s__('SecurityOrchestration|Specify individual projects directly'),
    },
  ],
  COMPLIANCE_FRAMEWORKS,
  CRITICALITY_OPTIONS,
  EXPOSURE_OPTIONS,
  CLASSIFICATION_OPTIONS,
  components: { GlBadge, GlButton, GlFormCheckbox, GlIcon },
  props: {
    policyData: {
      type: Object,
      required: true,
    },
  },
  emits: ['update'],
  i18n: {
    title: s__('SecurityOrchestration|Where should this policy apply?'),
    subtitle: s__(
      'SecurityOrchestration|Choose which projects this policy will apply to. This can be adjusted at any time.',
    ),
    allProjects: s__('SecurityOrchestration|All projects'),
    allProjectsDesc: s__(
      'SecurityOrchestration|Applied to every project, including newly created ones',
    ),
    targeted: s__('SecurityOrchestration|Targeted'),
    targetedDesc: s__(
      'SecurityOrchestration|Specify projects using attributes, frameworks, groups, or names',
    ),
    targetBy: s__('SecurityOrchestration|Target by'),
    targetByPlaceholder: s__(
      'SecurityOrchestration|Select a targeting method above to configure scope',
    ),
    exclusions: s__('SecurityOrchestration|Exclusions'),
    exclusionsSubtitle: s__('SecurityOrchestration|Temporary exceptions to scope'),
    addExclusion: s__('SecurityOrchestration|Add exclusion'),
    viewProjects: s__('SecurityOrchestration|View projects'),
    projectsAffected: s__('SecurityOrchestration|projects affected'),
    rollout: s__('SecurityOrchestration|Start with a phased rollout'),
    rolloutDesc: s__(
      'SecurityOrchestration|Pilot on a subset of projects before expanding to full scope',
    ),
    recommended: s__('SecurityOrchestration|Recommended'),
    filterBySecurityAttributes: s__('SecurityOrchestration|Filter by security attributes'),
    businessCriticality: s__('SecurityOrchestration|Business criticality'),
    externalExposure: s__('SecurityOrchestration|External exposure'),
    dataClassification: s__('SecurityOrchestration|Data classification'),
    selectGroups: s__('SecurityOrchestration|Select groups'),
    searchGroups: s__('SecurityOrchestration|Search groups…'),
    includeSubgroups: s__('SecurityOrchestration|Include subgroups'),
    selectComplianceFrameworks: s__('SecurityOrchestration|Select compliance frameworks'),
    selectProjects: s__('SecurityOrchestration|Select projects'),
    searchProjects: s__('SecurityOrchestration|Search projects…'),
  },
  data() {
    return {
      scopeMode: this.policyData.scope || this.$options.SCOPE_ALL,
      targetByMode: '',
      phasedRollout: false,
      selectedCriticality: [],
      selectedExposure: [],
      selectedClassification: [],
      groupSearch: '',
      includeSubgroups: true,
      selectedFrameworks: [],
      projectSearch: '',
    };
  },
  computed: {
    affectedCount() {
      if (this.scopeMode === this.$options.SCOPE_ALL) return '247';
      return AFFECTED_COUNTS[this.targetByMode] || '0';
    },
  },
  methods: {
    selectScope(value) {
      this.scopeMode = value;
      this.targetByMode = '';
      this.emitUpdate();
    },
    selectTargetBy(value) {
      this.targetByMode = value;
    },
    toggleFilter(list, value) {
      const idx = list.indexOf(value);
      if (idx === -1) list.push(value);
      else list.splice(idx, 1);
    },
    emitUpdate() {
      this.$emit('update', { scope: this.scopeMode });
    },
  },
};
</script>

<template>
  <div class="gl-mx-auto gl-max-w-2xl gl-p-6">
    <h2 class="gl-heading-2 gl-mb-1">{{ $options.i18n.title }}</h2>
    <p class="gl-mb-6 gl-text-secondary">{{ $options.i18n.subtitle }}</p>

    <!-- All projects / Targeted cards -->
    <div class="gl-mb-4">
      <div
        class="gl-border gl-mb-3 gl-cursor-pointer gl-rounded-base gl-border-default gl-p-4"
        :class="{ 'gl-border-blue-500 gl-bg-blue-50': scopeMode === $options.SCOPE_ALL }"
        @click="selectScope($options.SCOPE_ALL)"
      >
        <div class="gl-flex gl-items-center gl-gap-2">
          <div
            class="gl-border gl-flex gl-h-4 gl-w-4 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-full"
            :class="
              scopeMode === $options.SCOPE_ALL
                ? 'gl-border-blue-500 gl-bg-blue-500'
                : 'gl-border-gray-400'
            "
          >
            <div
              v-if="scopeMode === $options.SCOPE_ALL"
              style="width: 6px; height: 6px; border-radius: 50%; background: white"
            ></div>
          </div>
          <span class="gl-font-bold">{{ $options.i18n.allProjects }}</span>
        </div>
        <p class="gl-mb-0 gl-mt-1 gl-pl-6 gl-text-sm gl-text-secondary">
          {{ $options.i18n.allProjectsDesc }}
        </p>
      </div>

      <div
        class="gl-border gl-cursor-pointer gl-rounded-base gl-border-default gl-p-4"
        :class="{ 'gl-border-blue-500 gl-bg-blue-50': scopeMode === $options.SCOPE_TARGETED }"
        @click="selectScope($options.SCOPE_TARGETED)"
      >
        <div class="gl-flex gl-items-center gl-gap-2">
          <div
            class="gl-border gl-flex gl-h-4 gl-w-4 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-full"
            :class="
              scopeMode === $options.SCOPE_TARGETED
                ? 'gl-border-blue-500 gl-bg-blue-500'
                : 'gl-border-gray-400'
            "
          >
            <div
              v-if="scopeMode === $options.SCOPE_TARGETED"
              style="width: 6px; height: 6px; border-radius: 50%; background: white"
            ></div>
          </div>
          <span class="gl-font-bold">{{ $options.i18n.targeted }}</span>
        </div>
        <p class="gl-mb-0 gl-mt-1 gl-pl-6 gl-text-sm gl-text-secondary">
          {{ $options.i18n.targetedDesc }}
        </p>
      </div>
    </div>

    <!-- Target by options -->
    <div v-if="scopeMode === $options.SCOPE_TARGETED" class="gl-mb-4">
      <h3 class="gl-heading-5 gl-mb-3">{{ $options.i18n.targetBy }}</h3>

      <div
        v-for="opt in $options.TARGET_BY_OPTIONS"
        :key="opt.value"
        class="gl-border gl-mb-2 gl-cursor-pointer gl-rounded-base gl-border-default gl-p-3"
        :class="{ 'gl-border-blue-500 gl-bg-blue-50': targetByMode === opt.value }"
        @click="selectTargetBy(opt.value)"
      >
        <div class="gl-flex gl-items-center gl-gap-2">
          <div
            class="gl-border gl-flex gl-h-4 gl-w-4 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-full"
            :class="
              targetByMode === opt.value
                ? 'gl-border-blue-500 gl-bg-blue-500'
                : 'gl-border-gray-400'
            "
          >
            <div
              v-if="targetByMode === opt.value"
              style="width: 6px; height: 6px; border-radius: 50%; background: white"
            ></div>
          </div>
          <span class="gl-font-bold">{{ opt.label }}</span>
          <gl-badge v-if="opt.recommended" variant="warning" size="sm">
            {{ $options.i18n.recommended }}
          </gl-badge>
        </div>
        <p class="gl-mb-0 gl-mt-1 gl-pl-6 gl-text-sm gl-text-secondary">{{ opt.description }}</p>
      </div>

      <!-- Configuration panel -->
      <div class="gl-border gl-mt-3 gl-rounded-base gl-border-default gl-p-4">
        <!-- No selection -->
        <div
          v-if="!targetByMode"
          class="gl-flex gl-flex-col gl-items-center gl-justify-center gl-py-6 gl-text-secondary"
        >
          <gl-icon name="filter" :size="24" class="gl-mb-2" />
          <p class="gl-mb-0 gl-text-sm">{{ $options.i18n.targetByPlaceholder }}</p>
        </div>

        <!-- Security Attributes -->
        <div v-else-if="targetByMode === 'security_attributes'">
          <p class="gl-mb-3 gl-text-sm gl-font-bold">
            {{ $options.i18n.filterBySecurityAttributes }}
          </p>

          <div class="gl-mb-3">
            <p class="gl-mb-2 gl-text-sm gl-text-secondary">
              {{ $options.i18n.businessCriticality }}
            </p>
            <div class="gl-flex gl-flex-wrap gl-gap-2">
              <button
                v-for="opt in $options.CRITICALITY_OPTIONS"
                :key="opt"
                class="gl-border gl-cursor-pointer gl-rounded-full gl-px-3 gl-py-1 gl-text-sm"
                :class="
                  selectedCriticality.includes(opt)
                    ? 'gl-border-blue-500 gl-bg-blue-500 gl-text-white'
                    : 'gl-border-default gl-bg-default'
                "
                @click="toggleFilter(selectedCriticality, opt)"
              >
                {{ opt }}
              </button>
            </div>
          </div>

          <div class="gl-mb-3">
            <p class="gl-mb-2 gl-text-sm gl-text-secondary">{{ $options.i18n.externalExposure }}</p>
            <div class="gl-flex gl-flex-wrap gl-gap-2">
              <button
                v-for="opt in $options.EXPOSURE_OPTIONS"
                :key="opt"
                class="gl-border gl-cursor-pointer gl-rounded-full gl-px-3 gl-py-1 gl-text-sm"
                :class="
                  selectedExposure.includes(opt)
                    ? 'gl-border-blue-500 gl-bg-blue-500 gl-text-white'
                    : 'gl-border-default gl-bg-default'
                "
                @click="toggleFilter(selectedExposure, opt)"
              >
                {{ opt }}
              </button>
            </div>
          </div>

          <div>
            <p class="gl-mb-2 gl-text-sm gl-text-secondary">
              {{ $options.i18n.dataClassification }}
            </p>
            <div class="gl-flex gl-flex-wrap gl-gap-2">
              <button
                v-for="opt in $options.CLASSIFICATION_OPTIONS"
                :key="opt"
                class="gl-border gl-cursor-pointer gl-rounded-full gl-px-3 gl-py-1 gl-text-sm"
                :class="
                  selectedClassification.includes(opt)
                    ? 'gl-border-blue-500 gl-bg-blue-500 gl-text-white'
                    : 'gl-border-default gl-bg-default'
                "
                @click="toggleFilter(selectedClassification, opt)"
              >
                {{ opt }}
              </button>
            </div>
          </div>
        </div>

        <!-- Groups -->
        <div v-else-if="targetByMode === 'groups'">
          <p class="gl-mb-2 gl-text-sm gl-font-bold">{{ $options.i18n.selectGroups }}</p>
          <div
            class="gl-border gl-mb-3 gl-flex gl-items-center gl-gap-2 gl-rounded-base gl-border-default gl-px-3 gl-py-2"
          >
            <gl-icon name="search" :size="14" class="gl-text-secondary" />
            <input
              v-model="groupSearch"
              class="gl-w-full gl-border-0 gl-bg-transparent gl-text-sm gl-outline-none"
              :placeholder="$options.i18n.searchGroups"
            />
          </div>
          <gl-form-checkbox v-model="includeSubgroups">
            <span class="gl-text-sm">{{ $options.i18n.includeSubgroups }}</span>
          </gl-form-checkbox>
        </div>

        <!-- Compliance Frameworks -->
        <div v-else-if="targetByMode === 'compliance_frameworks'">
          <p class="gl-mb-3 gl-text-sm gl-font-bold">
            {{ $options.i18n.selectComplianceFrameworks }}
          </p>
          <div class="gl-grid gl-gap-2" style="grid-template-columns: 1fr 1fr">
            <gl-form-checkbox
              v-for="fw in $options.COMPLIANCE_FRAMEWORKS"
              :key="fw"
              v-model="selectedFrameworks"
              :value="fw"
            >
              <span class="gl-text-sm">{{ fw }}</span>
            </gl-form-checkbox>
          </div>
        </div>

        <!-- Projects -->
        <div v-else-if="targetByMode === 'projects'">
          <p class="gl-mb-2 gl-text-sm gl-font-bold">{{ $options.i18n.selectProjects }}</p>
          <div
            class="gl-border gl-flex gl-items-center gl-gap-2 gl-rounded-base gl-border-default gl-px-3 gl-py-2"
          >
            <gl-icon name="search" :size="14" class="gl-text-secondary" />
            <input
              v-model="projectSearch"
              class="gl-w-full gl-border-0 gl-bg-transparent gl-text-sm gl-outline-none"
              :placeholder="$options.i18n.searchProjects"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Exclusions -->
    <div class="gl-mb-4">
      <div class="gl-mb-2 gl-flex gl-items-center gl-gap-2">
        <h3 class="gl-heading-5 gl-mb-0">{{ $options.i18n.exclusions }}</h3>
        <span class="gl-text-sm gl-text-secondary">{{ $options.i18n.exclusionsSubtitle }}</span>
      </div>
      <gl-button category="tertiary" size="small" prepend-icon="plus">
        {{ $options.i18n.addExclusion }}
      </gl-button>
    </div>

    <div class="gl-flex gl-items-center gl-justify-between gl-py-2">
      <span class="gl-flex gl-items-center gl-gap-1 gl-text-sm gl-text-secondary">
        <gl-icon name="project" :size="14" />
        <span class="gl-font-bold gl-text-default">{{ affectedCount }}</span>
        {{ $options.i18n.projectsAffected }}
      </span>
      <gl-button category="tertiary" size="small">{{ $options.i18n.viewProjects }}</gl-button>
    </div>

    <div class="gl-border gl-mt-4 gl-rounded-base gl-border-default gl-p-4">
      <gl-form-checkbox v-model="phasedRollout">
        <span class="gl-font-bold">{{ $options.i18n.rollout }}</span>
      </gl-form-checkbox>
      <p class="gl-mb-0 gl-mt-1 gl-pl-6 gl-text-sm gl-text-secondary">
        {{ $options.i18n.rolloutDesc }}
      </p>
    </div>
  </div>
</template>
