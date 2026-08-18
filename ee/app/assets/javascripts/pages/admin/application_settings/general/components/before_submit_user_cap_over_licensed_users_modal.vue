<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'UserCapOverLicensedUsersModal',
  components: {
    GlModal,
    GlSprintf,
    HelpPageLink,
  },
  expose: ['show', 'hide'],
  inject: ['addBeforeSubmitHook', 'beforeSubmitHookContexts'],
  props: {
    id: {
      type: String,
      required: true,
    },
    licensedUserCount: {
      type: Number,
      required: true,
    },
    userCap: {
      type: Number,
      required: true,
    },
  },
  emits: ['hide', 'primary', 'secondary'],
  mounted() {
    this.addBeforeSubmitHook(this.shouldUserApproveUserCapSettings);
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
    hide() {
      this.$refs.modal.hide();
    },
    shouldUserApproveUserCapSettings() {
      const context = this.beforeSubmitHookContexts[this.id];
      if (!context?.shouldPreventSubmit) return false;
      try {
        const shouldPrevent = context.shouldPreventSubmit();
        if (shouldPrevent) this.show();
        return shouldPrevent;
      } catch (error) {
        Sentry.captureException(error);
        return false;
      }
    },
  },
  modal: {
    actionPrimary: {
      text: s__('ApplicationSettings|Proceed'),
      attributes: { variant: 'confirm' },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="id"
    :action-cancel="$options.modal.actionCancel"
    :action-primary="$options.modal.actionPrimary"
    :title="s__('ApplicationSettings|Proposed user cap exceeds licensed user count')"
    :no-focus-on-show="true"
    @hide="$emit('hide')"
    @primary="$emit('primary')"
    @secondary="$emit('secondary')"
    ><gl-sprintf
      :message="
        s__(
          'ApplicationSettings|Changing the user cap to %{userCap} would exceed the licensed user count of %{licensedUserCount}, which may result in %{linkStart}seat overages%{linkEnd}. Are you sure you want to proceed with the change?',
        )
      "
      ><template #licensedUserCount>{{ licensedUserCount }}</template
      ><template #userCap>{{ userCap }}</template
      ><template #link="{ content }">
        <help-page-link href="subscriptions/quarterly_reconciliation">{{ content }}</help-page-link>
      </template>
    </gl-sprintf>
  </gl-modal>
</template>
