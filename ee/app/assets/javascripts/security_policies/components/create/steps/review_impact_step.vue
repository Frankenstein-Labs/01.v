<script>
import { GlAlert, GlBadge, GlButton, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

const IMPACT_TILES = [
  {
    key: 'projects',
    label: s__('SecurityOrchestration|Projects in initial rollout'),
    value: '247',
    valueClass: '',
    subtitle: s__('SecurityOrchestration|full scope'),
  },
  {
    key: 'mrs',
    label: s__('SecurityOrchestration|MRs that would trigger'),
    value: '34',
    valueClass: '',
    subtitle: s__('SecurityOrchestration|in the last 30 days'),
  },
  {
    key: 'violations',
    label: s__('SecurityOrchestration|Estimated violations'),
    value: '8',
    valueClass: 'gl-text-red-500',
    subtitleParts: [
      { text: s__('SecurityOrchestration|12 critical'), cls: 'gl-text-red-500 gl-font-bold' },
      { text: ' · ' },
      { text: s__('SecurityOrchestration|8 high'), cls: 'gl-text-orange-500 gl-font-bold' },
      { text: s__('SecurityOrchestration| · 3 medium') },
    ],
  },
  {
    key: 'attention',
    label: s__('SecurityOrchestration|Rules needing attention'),
    value: '3',
    valueClass: 'gl-text-orange-500',
    subtitle: s__('SecurityOrchestration|review before expanding scope'),
  },
];

const RECENT_EVENTS = [
  {
    id: 'mr234',
    mr: '!234',
    title: s__('SecurityOrchestration|"Add payment SDK dependency"'),
    description: s__(
      'SecurityOrchestration|Critical CVE in stripe-node 12.0.1 — vulnerability with no available fix on default branch',
    ),
    outcome: 'blocked',
  },
  {
    id: 'mr228',
    mr: '!228',
    title: s__('SecurityOrchestration|"Update auth library"'),
    description: s__(
      'SecurityOrchestration|passport-jwt 4.0.0 not in approved registry — user proceeded after warning',
    ),
    outcome: 'warned',
  },
  {
    id: 'mr219',
    mr: '!219',
    title: s__('SecurityOrchestration|"Feature/new-reporting"'),
    description: s__(
      'SecurityOrchestration|2 high-severity SAST findings introduced — approval requirement not satisfied',
    ),
    outcome: 'blocked',
  },
  {
    id: 'mr201',
    mr: '!201',
    title: s__('SecurityOrchestration|"Hotfix/log4j-patch"'),
    description: s__(
      'SecurityOrchestration|Dependency scan incomplete on protected branch — required scan not executed',
    ),
    outcome: 'warned',
  },
];

const OUTCOME_CONFIG = {
  blocked: { variant: 'danger', icon: 'dash-circle', label: s__('SecurityOrchestration|blocked') },
  warned: { variant: 'warning', icon: 'warning', label: s__('SecurityOrchestration|warned') },
  logged: { variant: 'info', icon: 'doc-text', label: s__('SecurityOrchestration|logged') },
};

const MODE_LABELS = {
  enforce: s__('SecurityOrchestration|Enforce'),
  warn: s__('SecurityOrchestration|Warn'),
  audit: s__('SecurityOrchestration|Audit'),
};

export default {
  name: 'ReviewImpactStep',
  components: { GlAlert, GlBadge, GlButton, GlIcon },
  IMPACT_TILES,
  RECENT_EVENTS,
  OUTCOME_CONFIG,
  props: {
    policyData: { type: Object, required: true },
    policyName: { type: String, required: false, default: '' },
    enforcementMode: { type: String, required: false, default: 'enforce' },
  },
  i18n: {
    impactEstimate: s__('SecurityOrchestration|Impact estimate'),
    impactSubtitle: s__(
      'SecurityOrchestration|Estimated events and violations within the initial rollout scope.',
    ),
    last30Days: s__('SecurityOrchestration|Last 30 days'),
    recentEvents: s__('SecurityOrchestration|Recent events that would have been caught'),
    policyConfig: s__('SecurityOrchestration|Policy configuration'),
    policyConfigSubtitle: s__(
      'SecurityOrchestration|Review your settings before enabling — use the Edit links to go back and make changes.',
    ),
    details: s__('SecurityOrchestration|Details'),
    name: s__('SecurityOrchestration|Name'),
    mode: s__('SecurityOrchestration|Mode'),
    scope: s__('SecurityOrchestration|Scope'),
    initialRollout: s__('SecurityOrchestration|Initial rollout'),
    owner: s__('SecurityOrchestration|Owner'),
    managers: s__('SecurityOrchestration|Managers'),
    triggers: s__('SecurityOrchestration|Triggers'),
    rules: s__('SecurityOrchestration|Rules'),
    actions: s__('SecurityOrchestration|Actions'),
    noneAdded: s__('SecurityOrchestration|None added'),
    none: s__('SecurityOrchestration|None'),
    allProjects: s__('SecurityOrchestration|Default (all projects)'),
    targeted: s__('SecurityOrchestration|Targeted'),
    fullScope: s__('SecurityOrchestration|Full scope — 247 projects'),
    you: s__('SecurityOrchestration|You'),
    editPolicy: s__('SecurityOrchestration|Edit policy'),
    mr: s__('SecurityOrchestration|MR'),
  },
  computed: {
    modeLabel() {
      return MODE_LABELS[this.enforcementMode] || MODE_LABELS.enforce;
    },
    scopeLabel() {
      return this.policyData.scope === 'targeted'
        ? this.$options.i18n.targeted
        : this.$options.i18n.allProjects;
    },
    displayName() {
      return this.policyName || '—';
    },
    alertVariant() {
      const variants = { enforce: 'danger', warn: 'warning', audit: 'info' };
      return variants[this.enforcementMode] || 'danger';
    },
    alertMessage() {
      if (this.enforcementMode === 'enforce') {
        return s__(
          'SecurityOrchestration|This policy will be enabled for 247 projects in Enforce mode. Violations will be blocked — expand to full scope only after reviewing pilot behavior.',
        );
      }
      if (this.enforcementMode === 'warn') {
        return s__(
          'SecurityOrchestration|This policy will be enabled for 247 projects in Warn mode. Users will see warnings but will not be blocked.',
        );
      }
      return s__(
        'SecurityOrchestration|This policy will be enabled for 247 projects in Audit mode. Events will be logged only.',
      );
    },
  },
  methods: {
    outcomeConfig(outcome) {
      return OUTCOME_CONFIG[outcome] || OUTCOME_CONFIG.logged;
    },
  },
};
</script>

<template>
  <div class="gl-mx-auto gl-max-w-3xl gl-p-6">
    <!-- Impact estimate -->
    <div class="gl-mb-2 gl-flex gl-items-center gl-justify-between">
      <div>
        <h2 class="gl-heading-2 gl-mb-1">{{ $options.i18n.impactEstimate }}</h2>
        <p class="gl-mb-0 gl-text-secondary">{{ $options.i18n.impactSubtitle }}</p>
      </div>
      <gl-badge variant="neutral">{{ $options.i18n.last30Days }}</gl-badge>
    </div>

    <div class="gl-mb-6 gl-grid gl-grid-cols-2 gl-gap-3">
      <div
        v-for="tile in $options.IMPACT_TILES"
        :key="tile.key"
        class="gl-border gl-rounded-base gl-border-default gl-p-4"
      >
        <p class="gl-mb-2 gl-text-sm gl-text-secondary">{{ tile.label }}</p>
        <p
          class="gl-mb-1 gl-font-bold"
          :class="tile.valueClass"
          style="font-size: 2.5rem; line-height: 1.1"
        >
          {{ tile.value }}
        </p>
        <p v-if="tile.subtitleParts" class="gl-mb-0 gl-text-sm gl-text-secondary">
          <span v-for="(part, i) in tile.subtitleParts" :key="i" :class="part.cls">{{
            part.text
          }}</span>
        </p>
        <p v-else class="gl-mb-0 gl-text-sm gl-text-secondary">{{ tile.subtitle }}</p>
      </div>
    </div>

    <!-- Recent events -->
    <div class="gl-mb-6">
      <h3 class="gl-heading-5 gl-mb-3">{{ $options.i18n.recentEvents }}</h3>
      <div class="gl-border gl-rounded-base gl-border-default">
        <div
          v-for="(event, index) in $options.RECENT_EVENTS"
          :key="event.id"
          class="gl-flex gl-items-start gl-justify-between gl-px-4 gl-py-3"
          :class="{ 'gl-border-t gl-border-default': index > 0 }"
        >
          <div class="gl-flex gl-min-w-0 gl-flex-1 gl-items-start gl-gap-2">
            <gl-icon
              :name="outcomeConfig(event.outcome).icon"
              :size="14"
              class="gl-mt-1 gl-flex-shrink-0"
              :class="event.outcome === 'blocked' ? 'gl-text-red-500' : 'gl-text-orange-500'"
            />
            <div class="gl-min-w-0">
              <p class="gl-mb-0 gl-text-sm">
                <span class="gl-font-bold">{{ $options.i18n.mr }} {{ event.mr }}</span>
                <span class="gl-text-secondary"> — {{ event.title }}</span>
              </p>
              <p class="gl-mb-0 gl-text-xs gl-text-secondary">{{ event.description }}</p>
            </div>
          </div>
          <gl-badge
            :variant="outcomeConfig(event.outcome).variant"
            size="sm"
            class="gl-ml-3 gl-flex-shrink-0"
          >
            {{ outcomeConfig(event.outcome).label }}
          </gl-badge>
        </div>
      </div>
    </div>

    <!-- Policy configuration -->
    <div class="gl-mb-6">
      <h3 class="gl-heading-5 gl-mb-1">{{ $options.i18n.policyConfig }}</h3>
      <p class="gl-mb-3 gl-text-sm gl-text-secondary">{{ $options.i18n.policyConfigSubtitle }}</p>

      <div class="gl-border gl-rounded-base gl-border-default">
        <!-- Details section -->
        <div class="gl-p-4">
          <p class="gl-mb-3 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary">
            {{ $options.i18n.details }}
          </p>
          <div class="gl-flex gl-flex-col gl-gap-2">
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.name
              }}</span>
              <span class="gl-text-sm gl-font-bold">{{ displayName }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.mode
              }}</span>
              <span class="gl-text-sm">{{ modeLabel }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.scope
              }}</span>
              <span class="gl-text-sm">{{ scopeLabel }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.initialRollout
              }}</span>
              <span class="gl-text-sm">{{ $options.i18n.fullScope }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.owner
              }}</span>
              <span class="gl-text-sm">{{ $options.i18n.you }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.managers
              }}</span>
              <span class="gl-text-sm gl-text-secondary">{{ $options.i18n.none }}</span>
            </div>
          </div>
        </div>

        <div class="gl-border-t gl-border-default gl-p-4">
          <div class="gl-flex gl-flex-col gl-gap-2">
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.triggers
              }}</span>
              <span class="gl-text-sm gl-text-secondary">{{ $options.i18n.noneAdded }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.rules
              }}</span>
              <span class="gl-text-sm gl-text-secondary">{{ $options.i18n.noneAdded }}</span>
            </div>
            <div class="gl-flex gl-items-center gl-gap-4">
              <span class="gl-w-28 gl-flex-shrink-0 gl-text-sm gl-text-secondary">{{
                $options.i18n.actions
              }}</span>
              <span class="gl-text-sm gl-text-secondary">{{ $options.i18n.noneAdded }}</span>
            </div>
          </div>
        </div>

        <div class="gl-border-t gl-border-default gl-px-4 gl-py-3">
          <gl-button size="small">{{ $options.i18n.editPolicy }}</gl-button>
        </div>
      </div>

      <gl-alert :variant="alertVariant" :dismissible="false" class="gl-mt-4">
        {{ alertMessage }}
      </gl-alert>
    </div>
  </div>
</template>
