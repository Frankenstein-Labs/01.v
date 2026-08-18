<script>
import { GlAlert, GlBadge, GlButton, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { s__, __, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { ACTIONS } from '../../catalog/actions';
import { RULES } from '../../catalog/rules';
import { TRIGGERS } from '../../catalog/triggers';
import { POLICY_STATUS_ACTIVE, POLICY_STATUS_DISABLED } from '../../constants';
import { fetchPolicy, updatePolicy, deletePolicy } from '../../policies';
import { deserializePolicyData } from '../editor/serializer';
import { modeLabel, modeVariant, statusLabel, statusVariant, scopeLabel } from '../list/utils';
import SummarySection from './summary_section.vue';

export default {
  name: 'PolicyStoreDetailRoot',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlLoadingIcon,
    SummarySection,
  },
  i18n: {
    policyError: s__(
      'PolicyStore|The policy could not be loaded from the Policy Store API. Refresh the page to try again.',
    ),
    deleteError: s__('PolicyStore|The policy could not be deleted. Try again.'),
    deleteConfirmTitle: s__('PolicyStore|Delete policy?'),
    deleteConfirmMessage: s__(
      'PolicyStore|Are you sure you want to delete %{name}? This action cannot be undone.',
    ),
    deleteConfirmButton: __('Delete'),
    editPolicy: s__('PolicyStore|Edit policy'),
    disablePolicy: s__('PolicyStore|Disable'),
    enablePolicy: s__('PolicyStore|Enable'),
    toggleStatusError: s__('PolicyStore|The policy could not be updated. Try again.'),
    trigger: s__('PolicyStore|Trigger'),
    rules: s__('PolicyStore|Rules'),
    actions: s__('PolicyStore|Actions'),
    scope: s__('PolicyStore|Scope'),
  },
  inject: {
    organizationId: {},
    policyId: {},
    listPath: { default: '' },
    editPath: { default: '' },
  },
  data() {
    return {
      policy: null,
      policyLoading: false,
      policyError: false,
      deleting: false,
      toggling: false,
    };
  },
  computed: {
    isActive() {
      return this.policy.status === POLICY_STATUS_ACTIVE;
    },
    toggleStatusLabel() {
      return this.isActive ? this.$options.i18n.disablePolicy : this.$options.i18n.enablePolicy;
    },
    // The catalog files supply the presentation for the persisted ids, the same
    // lookup the editor and the list use.
    sections() {
      const { trigger, rules, actions } = deserializePolicyData(this.policy);

      return [
        {
          testid: 'trigger',
          label: this.$options.i18n.trigger,
          ids: trigger ? [trigger] : [],
          catalog: TRIGGERS,
        },
        { testid: 'rules', label: this.$options.i18n.rules, ids: rules, catalog: RULES },
        { testid: 'actions', label: this.$options.i18n.actions, ids: actions, catalog: ACTIONS },
      ].map(({ testid, label, ids, catalog }) => ({
        testid,
        label,
        entries: ids.map((id) => this.entryFor(catalog, id)),
      }));
    },
  },
  created() {
    this.loadPolicy();
  },
  methods: {
    modeLabel,
    modeVariant,
    statusLabel,
    statusVariant,
    scopeLabel,
    // A persisted id the catalog no longer knows still renders as its raw id
    // rather than disappearing from the summary.
    entryFor(catalog, id) {
      return (
        catalog.find((entry) => entry.id === id) ?? {
          id,
          label: id,
          description: '',
          icon: 'question-o',
        }
      );
    },
    async loadPolicy() {
      this.policyLoading = true;

      try {
        this.policy = await fetchPolicy(this.organizationId, this.policyId);
      } catch (error) {
        Sentry.captureException(error);
        this.policyError = true;
      } finally {
        this.policyLoading = false;
      }
    },
    async onToggleStatus() {
      this.toggling = true;

      const lifecycleState = this.isActive ? POLICY_STATUS_DISABLED : POLICY_STATUS_ACTIVE;

      try {
        this.policy = await updatePolicy(this.organizationId, this.policyId, {
          lifecycle_state: lifecycleState,
        });
      } catch (error) {
        Sentry.captureException(error);
        createAlert({ message: this.toggleStatusErrorMessage(error) });
      } finally {
        this.toggling = false;
      }
    },
    // A 400 carries the reason the store rejected the update under `message`,
    // or under `error` for Grape param validation, so show that over the
    // generic alert.
    toggleStatusErrorMessage(error) {
      const data = error?.response?.data;

      return (
        [data?.message, data?.error].find((reason) => typeof reason === 'string') ||
        this.$options.i18n.toggleStatusError
      );
    },
    async onDelete() {
      // Guards re-entrancy: the confirm dialog is awaited before any request,
      // so without this a double-click would open two confirmation flows.
      if (this.deleting) return;

      this.deleting = true;

      const confirmed = await confirmAction(
        sprintf(this.$options.i18n.deleteConfirmMessage, { name: this.policy.name }),
        {
          title: this.$options.i18n.deleteConfirmTitle,
          primaryBtnText: this.$options.i18n.deleteConfirmButton,
          primaryBtnVariant: 'danger',
        },
      );

      if (!confirmed) {
        this.deleting = false;
        return;
      }

      try {
        await deletePolicy(this.organizationId, this.policyId);
        if (this.listPath) {
          visitUrl(this.listPath);
        } else {
          this.deleting = false;
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({ message: this.$options.i18n.deleteError });
        this.deleting = false;
      }
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="policyLoading" size="lg" class="gl-mt-6" data-testid="policy-loading" />
  <gl-alert
    v-else-if="policyError"
    variant="danger"
    :dismissible="false"
    class="gl-mt-4"
    data-testid="policy-error"
  >
    {{ $options.i18n.policyError }}
  </gl-alert>
  <div v-else-if="policy" class="gl-flex gl-flex-col gl-gap-5 gl-pt-6">
    <div class="gl-flex gl-flex-wrap gl-items-start gl-justify-between gl-gap-4">
      <div class="gl-min-w-0">
        <h1 class="gl-heading-1 gl-mb-2" data-testid="policy-name">{{ policy.name }}</h1>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <gl-badge variant="neutral" data-testid="policy-type">{{ policy.type }}</gl-badge>
          <gl-badge :variant="modeVariant(policy.mode)" data-testid="policy-mode">
            {{ modeLabel(policy.mode) }}
          </gl-badge>
          <gl-badge :variant="statusVariant(policy.status)" data-testid="policy-status">
            {{ statusLabel(policy.status) }}
          </gl-badge>
        </div>
        <p
          v-if="policy.description"
          class="gl-mb-0 gl-mt-3 gl-text-subtle"
          data-testid="policy-description"
        >
          {{ policy.description }}
        </p>
      </div>
      <div class="gl-flex gl-flex-shrink-0 gl-gap-3">
        <gl-button :href="editPath" data-testid="edit-policy-button">
          {{ $options.i18n.editPolicy }}
        </gl-button>
        <gl-button :loading="toggling" data-testid="toggle-status-button" @click="onToggleStatus">
          {{ toggleStatusLabel }}
        </gl-button>
        <gl-button
          category="secondary"
          variant="danger"
          :loading="deleting"
          data-testid="delete-policy-button"
          @click="onDelete"
        >
          {{ $options.i18n.deleteConfirmButton }}
        </gl-button>
      </div>
    </div>

    <summary-section
      v-for="section in sections"
      :key="section.testid"
      :label="section.label"
      :entries="section.entries"
      :testid="section.testid"
    />

    <summary-section :label="$options.i18n.scope" testid="scope">
      <p class="gl-mb-0">{{ scopeLabel(policy.scopedProjectsCount) }}</p>
    </summary-section>
  </div>
</template>
