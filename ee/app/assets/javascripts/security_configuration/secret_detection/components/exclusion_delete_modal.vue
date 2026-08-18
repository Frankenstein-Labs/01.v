<script>
import { GlModal, GlSprintf, GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { EXCLUSION_TYPE_MAP } from '../constants';
import deleteMutation from '../graphql/project_security_exclusion_delete.mutation.graphql';

export default {
  name: 'ExclusionDeleteModal',
  components: {
    GlModal,
    GlSprintf,
  },
  mixins: [GlToastMixin],
  props: {
    exclusion: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    title: s__('SecurityExclusions|Delete exclusion'),
    description: s__(
      'SecurityExclusions|You are about to delete the %{type} `%{value}` from the secret detection exclusions. Are you sure you want to continue?',
    ),
  },
  data() {
    return {
      isDeleting: false,
    };
  },
  computed: {
    typeLabel() {
      return EXCLUSION_TYPE_MAP[this.exclusion.type]?.text.toLowerCase() || '';
    },
    modalActionPrimary() {
      return {
        text: s__('SecurityExclusions|Delete exclusion'),
        attributes: {
          variant: 'danger',
          loading: this.isDeleting,
        },
      };
    },
    modalActionCancel() {
      return {
        text: __('Cancel'),
        attributes: {
          variant: 'default',
        },
      };
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the parent component.
    show() {
      this.$refs.deleteModal.show();
    },
    async deleteExclusion() {
      this.isDeleting = true;
      const { id } = this.exclusion;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteMutation,
          variables: { input: { id } },
          update: (cache) => {
            const cacheId = cache.identify(this.exclusion);
            cache.evict({ id: cacheId });
          },
        });

        const { errors } = data?.projectSecurityExclusionDelete || {};
        if (errors && errors.length > 0) {
          this.onError(new Error(errors.join(' ')));
        } else {
          this.$toast.show(s__('SecurityExclusions|Exclusion deleted successfully.'));
        }
      } catch (error) {
        this.onError(error);
      } finally {
        this.isDeleting = false;
      }
    },
    onError(error) {
      this.loading = false;
      const { message } = error;
      const title = s__('SecurityExclusions|Failed to delete the exclusion:');

      createAlert({ title, message });
      Sentry.captureException(error);
    },
  },
};
</script>

<template>
  <gl-modal
    ref="deleteModal"
    size="sm"
    modal-id="exclusion-delete-modal"
    :action-primary="modalActionPrimary"
    :action-cancel="modalActionCancel"
    :title="$options.i18n.title"
    @primary="deleteExclusion"
  >
    <gl-sprintf :message="$options.i18n.description">
      <template #type>{{ typeLabel }}</template>
      <template #value
        ><strong>{{ exclusion.value }}</strong></template
      >
    </gl-sprintf>
  </gl-modal>
</template>
