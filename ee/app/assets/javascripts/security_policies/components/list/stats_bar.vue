<script>
import { GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'StatsBar',
  components: { GlIcon },
  props: {
    activePolicies: {
      type: Object,
      required: false,
      default: () => ({ total: 0, enforcing: 0, warning: 0, audit: 0 }),
    },
    actionsThisWeek: {
      type: Object,
      required: false,
      default: () => ({ blocked: 0, warned: 0, logged: 0 }),
    },
    catching: {
      type: Object,
      required: false,
      default: () => ({ count: 0 }),
    },
    needsAttention: {
      type: Object,
      required: false,
      default: () => ({ total: 0, drafts: 0, disabled: 0, pendingApproval: 0 }),
    },
  },
  emits: [
    'filter-catching',
    'filter-needs-attention',
    'filter-blocked',
    'filter-warned',
    'filter-logged',
  ],
  i18n: {
    activePolicies: s__('SecurityOrchestration|Active policies'),
    actionsThisWeek: s__('SecurityOrchestration|Actions this week'),
    catching: s__('SecurityOrchestration|Catching, not blocking'),
    catchingDesc: s__('SecurityOrchestration|warn/log policies with findings this week'),
    needsAttention: s__('SecurityOrchestration|Needs attention'),
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-bg-subtle gl-p-4">
      <p class="gl-mb-3 gl-text-sm gl-font-bold gl-uppercase gl-text-secondary">
        {{ $options.i18n.activePolicies }}
      </p>
      <p class="gl-mb-1 gl-font-bold" style="font-size: 2rem; line-height: 1.2">
        {{ activePolicies.total }}
      </p>
      <p class="gl-mb-0 gl-text-sm gl-text-secondary">
        {{ activePolicies.enforcing }} {{ s__('SecurityOrchestration|enforcing') }} ·
        {{ activePolicies.warning }} {{ s__('SecurityOrchestration|warning') }} ·
        {{ activePolicies.audit }} {{ s__('SecurityOrchestration|audit') }}
      </p>
    </div>

    <div class="gl-border gl-flex-1 gl-rounded-base gl-border-default gl-bg-subtle gl-p-4">
      <p class="gl-mb-3 gl-text-sm gl-font-bold gl-uppercase gl-text-secondary">
        {{ $options.i18n.actionsThisWeek }}
      </p>
      <div class="gl-flex gl-gap-5">
        <button
          class="gl-flex gl-cursor-pointer gl-flex-col gl-items-start gl-border-0 gl-bg-transparent gl-p-0"
          @click="$emit('filter-blocked')"
        >
          <span
            class="gl-flex gl-items-center gl-gap-1 gl-font-bold"
            style="font-size: 1.5rem; line-height: 1.2"
          >
            <gl-icon name="dash-circle" class="gl-text-red-500" :size="16" />
            +{{ actionsThisWeek.blocked }}
          </span>
          <span class="gl-text-sm gl-text-secondary">{{
            s__('SecurityOrchestration|blocked')
          }}</span>
        </button>
        <button
          class="gl-flex gl-cursor-pointer gl-flex-col gl-items-start gl-border-0 gl-bg-transparent gl-p-0"
          @click="$emit('filter-warned')"
        >
          <span
            class="gl-flex gl-items-center gl-gap-1 gl-font-bold"
            style="font-size: 1.5rem; line-height: 1.2"
          >
            <gl-icon name="warning" class="gl-text-orange-500" :size="16" />
            +{{ actionsThisWeek.warned }}
          </span>
          <span class="gl-text-sm gl-text-secondary">{{
            s__('SecurityOrchestration|warned')
          }}</span>
        </button>
        <button
          class="gl-flex gl-cursor-pointer gl-flex-col gl-items-start gl-border-0 gl-bg-transparent gl-p-0"
          @click="$emit('filter-logged')"
        >
          <span
            class="gl-flex gl-items-center gl-gap-1 gl-font-bold"
            style="font-size: 1.5rem; line-height: 1.2"
          >
            <gl-icon name="doc-text" class="gl-text-blue-500" :size="16" />
            +{{ actionsThisWeek.logged }}
          </span>
          <span class="gl-text-sm gl-text-secondary">{{
            s__('SecurityOrchestration|logged')
          }}</span>
        </button>
      </div>
    </div>

    <button
      class="gl-border gl-flex-1 gl-cursor-pointer gl-rounded-base gl-border-default gl-bg-subtle gl-p-4 gl-text-left hover:gl-border-blue-300"
      @click="$emit('filter-catching')"
    >
      <p class="gl-mb-3 gl-text-sm gl-font-bold gl-uppercase gl-text-secondary">
        {{ $options.i18n.catching }}
      </p>
      <p class="gl-mb-1 gl-font-bold" style="font-size: 2rem; line-height: 1.2">
        {{ catching.count }}
      </p>
      <p class="gl-mb-0 gl-text-sm gl-text-secondary">{{ $options.i18n.catchingDesc }}</p>
    </button>

    <button
      class="gl-border gl-flex-1 gl-cursor-pointer gl-rounded-base gl-border-default gl-bg-subtle gl-p-4 gl-text-left hover:gl-border-blue-300"
      @click="$emit('filter-needs-attention')"
    >
      <p class="gl-mb-3 gl-text-sm gl-font-bold gl-uppercase gl-text-secondary">
        {{ $options.i18n.needsAttention }}
      </p>
      <p class="gl-mb-1 gl-font-bold" style="font-size: 2rem; line-height: 1.2">
        {{ needsAttention.total }}
      </p>
      <p class="gl-mb-0 gl-text-sm gl-text-secondary">
        {{ needsAttention.drafts }} {{ s__('SecurityOrchestration|drafts') }} ·
        {{ needsAttention.disabled }} {{ s__('SecurityOrchestration|disabled') }} ·
        {{ needsAttention.pendingApproval }} {{ s__('SecurityOrchestration|pending approval') }}
      </p>
    </button>
  </div>
</template>
