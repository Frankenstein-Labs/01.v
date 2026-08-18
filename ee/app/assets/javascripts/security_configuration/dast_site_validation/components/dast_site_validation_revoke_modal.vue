<script>
import { GlModal, GlSprintf, GlAlert, GlLink } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { DAST_SITE_VALIDATION_REVOKE_MODAL_ID } from '../constants';
import dastSiteValidationRevokeMutation from '../graphql/dast_site_validation_revoke.mutation.graphql';

export default {
  name: 'DastSiteValidationRevokeModal',
  DAST_SITE_VALIDATION_REVOKE_MODAL_ID,
  components: {
    GlModal,
    GlSprintf,
    GlAlert,
    GlLink,
    HelpIcon,
  },
  mixins: [glListenersMixin],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    targetUrl: {
      type: String,
      required: true,
    },
    normalizedTargetUrl: {
      type: String,
      required: true,
    },
    profileCount: {
      type: Number,
      required: true,
    },
  },
  emits: ['revoke'],
  data() {
    return {
      isLoading: false,
      hasErrors: false,
    };
  },
  computed: {
    modalProps() {
      return {
        id: DAST_SITE_VALIDATION_REVOKE_MODAL_ID,
        title: s__('DastSiteValidation|Revoke validation'),
        primaryProps: {
          text: s__('DastSiteValidation|Revoke validation'),
          attributes: {
            loading: this.isLoading,
            variant: 'confirm',
            category: 'primary',
            'data-testid': 'revoke-validation-button',
          },
        },
        cancelProps: {
          text: __('Cancel'),
        },
      };
    },
    docsPath() {
      return helpPagePath('user/application_security/dast/profiles', {
        anchor: 'revoke-a-site-profiles-validation-status',
      });
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is a part of the parent component
    show() {
      this.$refs.modal.show();
      this.hasErrors = false;
    },
    async revoke() {
      this.isLoading = true;
      try {
        const {
          data: {
            dastSiteValidationRevoke: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: dastSiteValidationRevokeMutation,
          variables: {
            fullPath: this.fullPath,
            normalizedTargetUrl: this.normalizedTargetUrl,
          },
        });
        if (errors?.length) {
          this.onError();
          return;
        }
        this.$refs.modal.hide();
        this.$emit('revoke');
      } catch (exception) {
        this.onError(exception);
      } finally {
        this.isLoading = false;
      }
    },
    onError(exception = null) {
      if (exception !== null) {
        Sentry.captureException(exception);
      }
      this.hasErrors = true;
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    :modal-id="modalProps.id"
    :action-primary="modalProps.primaryProps"
    :action-cancel="modalProps.cancelProps"
    v-bind="$attrs"
    v-on="glListeners()"
    @primary.prevent="revoke"
  >
    <template #modal-title>
      {{ modalProps.title }}
      <gl-link :href="docsPath" target="_blank" class="gl-ml-2">
        <help-icon />
      </gl-link>
    </template>
    <gl-alert v-if="hasErrors" variant="danger" class="gl-mb-4" :dismissible="false">
      {{ s__('DastSiteValidation|Could not revoke validation. Please try again.') }}
    </gl-alert>

    <gl-sprintf
      :message="s__('DastSiteValidation|You will not be able to run active scans against %{url}.')"
    >
      <template #url>
        <strong>{{ targetUrl }}</strong>
      </template>
    </gl-sprintf>
    <span v-if="profileCount > 0">
      {{
        n__(
          'DastSiteValidation|This will affect %d other profile targeting the same URL.',
          'DastSiteValidation|This will affect %d other profiles targeting the same URL.',
          profileCount,
        )
      }}
    </span>
  </gl-modal>
</template>
