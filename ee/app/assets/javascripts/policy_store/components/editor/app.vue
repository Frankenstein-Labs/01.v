<script>
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { fetchPolicy, createPolicy, updatePolicy } from '../../policies';
import { serializePolicyParams } from './serializer';
import StepWizard from './step_wizard.vue';

export default {
  name: 'PolicyStoreEditorRoot',
  components: {
    GlAlert,
    GlLoadingIcon,
    StepWizard,
  },
  i18n: {
    policyError: s__(
      'PolicyStore|The policy could not be loaded from the Policy Store API. Refresh the page to try again.',
    ),
    saveError: s__('PolicyStore|The policy could not be saved. Try again.'),
  },
  inject: {
    organizationId: {},
    policyId: { default: '' },
    listPath: { default: '' },
  },
  data() {
    return {
      editingPolicy: null,
      policyLoading: false,
      policyError: false,
      saving: false,
    };
  },
  created() {
    // The blank "new" page has no policy to resolve, so only edit fetches one.
    if (this.policyId) this.loadPolicy();
  },
  methods: {
    // The wizard reads its policy prop once, on mount, so the editor renders
    // only after this settles rather than mounting empty and never refilling.
    async loadPolicy() {
      this.policyLoading = true;

      try {
        this.editingPolicy = await fetchPolicy(this.organizationId, this.policyId);
      } catch (error) {
        Sentry.captureException(error);
        this.policyError = true;
      } finally {
        this.policyLoading = false;
      }
    },
    async onSave(wizardState) {
      this.saving = true;

      const params = serializePolicyParams(wizardState);

      // An untouched Scope step is not sent on update, so a scope authored
      // through the API (hand-written Rego, groups, frameworks) is not
      // overwritten by the wizard's project-only view of it.
      if (this.policyId && !wizardState.scopeChanged) delete params.policy_scope;

      try {
        if (this.policyId) {
          await updatePolicy(this.organizationId, this.policyId, params);
        } else {
          await createPolicy(this.organizationId, params);
        }

        this.returnToList();
      } catch (error) {
        Sentry.captureException(error);
        createAlert({ message: this.saveErrorMessage(error) });
        this.saving = false;
      }
    },
    // A 400 carries the reason the store rejected the save (e.g. a duplicate
    // name) under `message`, or under `error` for Grape param validation, so
    // show that over the generic alert.
    saveErrorMessage(error) {
      const data = error?.response?.data;

      return (
        [data?.message, data?.error].find((reason) => typeof reason === 'string') ||
        this.$options.i18n.saveError
      );
    },
    returnToList() {
      if (this.listPath) visitUrl(this.listPath);
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
  <step-wizard
    v-else
    :policy="editingPolicy"
    :saving="saving"
    @cancel="returnToList"
    @save="onSave"
  />
</template>
