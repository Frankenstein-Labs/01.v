<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import { EMPTY_CATALOGS } from '../../../catalog/catalogs';
import { ENFORCEMENT_ENFORCE, ENFORCEMENT_MODES } from '../constants';

const MODE_MESSAGES = {
  enforce: s__(
    'PolicyStore|This policy will be enabled for %{scope} in Enforce mode. Violations will be blocked.',
  ),
  warn: s__(
    'PolicyStore|This policy will be enabled for %{scope} in Warn mode. Users will see warnings but will not be blocked.',
  ),
  audit: s__(
    'PolicyStore|This policy will be enabled for %{scope} in Audit mode. Events will be logged only.',
  ),
};

export default {
  name: 'ReviewStep',
  components: { GlAlert, GlButton },
  props: {
    policy: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    catalogs: {
      type: Object,
      required: false,
      default: () => EMPTY_CATALOGS,
    },
  },
  emits: ['edit'],
  i18n: {
    policyConfig: s__('PolicyStore|Policy configuration'),
    policyConfigSubtitle: s__(
      'PolicyStore|Review your settings before enabling. Use Edit to go back and make changes.',
    ),
    details: s__('PolicyStore|Details'),
    editPolicy: s__('PolicyStore|Edit policy'),
  },
  computed: {
    policyMode() {
      return this.policy.mode || ENFORCEMENT_ENFORCE;
    },
    selectedMode() {
      return (
        ENFORCEMENT_MODES.find(({ value }) => value === this.policyMode) || ENFORCEMENT_MODES[0]
      );
    },
    policyScope() {
      return this.policy.scope || { mode: 'all', projects: [] };
    },
    displayName() {
      return this.policy.name || '—';
    },
    modeLabel() {
      return this.selectedMode.text;
    },
    isTargeted() {
      return this.policyScope.mode === 'specific';
    },
    scopeLabel() {
      return this.isTargeted
        ? s__('PolicyStore|Targeted')
        : s__('PolicyStore|Default (all projects)');
    },
    projectCount() {
      return n__('%d project', '%d projects', this.policyScope.projects.length);
    },
    projectsAffected() {
      return this.isTargeted ? this.projectCount : s__('PolicyStore|All projects in the group');
    },
    alertScope() {
      return this.isTargeted ? this.projectCount : s__('PolicyStore|all projects in the group');
    },
    alertVariant() {
      return this.selectedMode.variant;
    },
    alertMessage() {
      return sprintf(MODE_MESSAGES[this.policyMode] || MODE_MESSAGES.enforce, {
        scope: this.alertScope,
      });
    },
    detailRows() {
      return [
        { label: s__('PolicyStore|Name'), value: this.displayName, testid: 'detail-name' },
        { label: s__('PolicyStore|Mode'), value: this.modeLabel, testid: 'detail-mode' },
        { label: s__('PolicyStore|Scope'), value: this.scopeLabel, testid: 'detail-scope' },
        {
          label: s__('PolicyStore|Projects affected'),
          value: this.projectsAffected,
          testid: 'detail-projects',
        },
        {
          label: s__('PolicyStore|Owner'),
          value: s__('PolicyStore|You'),
          testid: 'detail-owner',
        },
      ];
    },
    configRows() {
      return [
        {
          label: s__('PolicyStore|Triggers'),
          value: this.summaryFor(
            this.policy.trigger ? [this.policy.trigger] : [],
            this.catalogs.triggers,
          ),
          testid: 'config-triggers',
        },
        {
          label: s__('PolicyStore|Rules'),
          value: this.summaryFor(this.policy.rules, this.catalogs.rules),
          testid: 'config-rules',
        },
        {
          label: s__('PolicyStore|Actions'),
          value: this.summaryFor(this.policy.actions, this.catalogs.actions),
          testid: 'config-actions',
        },
      ];
    },
  },
  methods: {
    onEdit() {
      this.$emit('edit');
    },
    summaryFor(ids, catalog) {
      if (!ids?.length) return s__('PolicyStore|None added');

      return ids.map((id) => catalog.find((entry) => entry.id === id)?.label || id).join(', ');
    },
  },
};
</script>

<template>
  <div class="gl-mx-auto gl-flex gl-max-w-3xl gl-flex-col gl-gap-5">
    <div>
      <h3 class="gl-heading-3 gl-mb-1">{{ $options.i18n.policyConfig }}</h3>
      <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.policyConfigSubtitle }}</p>
    </div>

    <div class="gl-overflow-hidden gl-rounded-base gl-border-1 gl-border-solid gl-border-default">
      <section class="gl-p-5">
        <h4 class="gl-mb-4 gl-text-sm gl-font-bold gl-uppercase gl-text-subtle">
          {{ $options.i18n.details }}
        </h4>
        <dl class="gl-m-0 gl-flex gl-flex-col gl-gap-3">
          <div
            v-for="row in detailRows"
            :key="row.label"
            class="gl-flex gl-gap-4"
            :data-testid="row.testid"
          >
            <dt class="gl-w-32 gl-shrink-0 gl-text-sm gl-font-normal gl-text-subtle">
              {{ row.label }}
            </dt>
            <dd class="gl-m-0 gl-text-sm gl-font-bold">{{ row.value }}</dd>
          </div>
        </dl>
      </section>

      <div class="gl-border-t-1 gl-border-t-default gl-p-5 gl-border-t-solid">
        <dl class="gl-m-0 gl-flex gl-flex-col gl-gap-3">
          <div
            v-for="row in configRows"
            :key="row.label"
            class="gl-flex gl-gap-4"
            :data-testid="row.testid"
          >
            <dt class="gl-w-32 gl-shrink-0 gl-text-sm gl-font-normal gl-text-subtle">
              {{ row.label }}
            </dt>
            <dd class="gl-m-0 gl-text-sm">{{ row.value }}</dd>
          </div>
        </dl>
      </div>

      <div
        class="gl-flex gl-justify-end gl-border-t-1 gl-border-t-default gl-bg-subtle gl-px-5 gl-py-3 gl-border-t-solid"
      >
        <gl-button
          category="tertiary"
          size="small"
          icon="pencil"
          data-testid="edit-policy"
          @click="onEdit"
        >
          {{ $options.i18n.editPolicy }}
        </gl-button>
      </div>
    </div>

    <gl-alert :variant="alertVariant" :dismissible="false" data-testid="impact-alert">
      {{ alertMessage }}
    </gl-alert>
  </div>
</template>
