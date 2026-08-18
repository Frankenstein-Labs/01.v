<script>
import { defineComponent } from 'vue';
import { GlAlert, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import { s__, sprintf } from '~/locale';
import orbitUpdateMutation from '../graphql/mutations/orbit_update.mutation.graphql';

const GENERIC_ERROR_MESSAGE = s__('Orbit|Failed to enable GitLab Orbit. Please try again.');

export default defineComponent({
  name: 'TurnOnIndexingModal',
  compatConfig: { MODE: 3 },
  components: {
    GlAlert,
    GlLink,
    GlModal,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    group: {
      type: Object,
      required: false,
      default: null,
    },
    modalId: {
      type: String,
      required: false,
      default: 'orbit-turn-on-indexing-modal',
    },
  },
  emits: ['enabled', 'hidden'],
  data() {
    return {
      enabling: false,
      visible: false,
      errorMessage: '',
      confirmed: false,
    };
  },
  computed: {
    title() {
      if (!this.group) return '';
      return sprintf(s__('Orbit|Turn on GitLab Orbit for %{groupName}'), {
        groupName: this.group.name,
      });
    },
    primaryAction() {
      return {
        text: s__('Orbit|Turn on GitLab Orbit'),
        attributes: { variant: 'confirm', loading: this.enabling },
      };
    },
    cancelAction() {
      return {
        text: s__('Orbit|Cancel'),
        attributes: { disabled: this.enabling },
      };
    },
  },
  watch: {
    group: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.confirmed = false;
        }
        this.visible = Boolean(newVal);
        this.resetError();
      },
    },
  },
  methods: {
    onChange(value) {
      this.visible = value;
    },
    onHidden() {
      if (this.enabling) return;
      this.resetError();
      if (!this.confirmed) {
        this.trackEvent('dismiss_orbit_turn_on_modal');
      }
      this.$emit('hidden');
    },
    resetError() {
      this.errorMessage = '';
    },
    async onPrimary() {
      if (!this.group || this.enabling) return;
      this.enabling = true;
      this.resetError();

      try {
        const { data } = await this.$apollo.mutate({
          mutation: orbitUpdateMutation,
          variables: {
            input: { groupPath: this.group.fullPath, enabled: true },
          },
        });

        const { errors } = data.orbitUpdate;
        if (errors.length) {
          [this.errorMessage] = errors;
          return;
        }

        this.confirmed = true;
        this.$emit('enabled', this.group);
        this.visible = false;
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = GENERIC_ERROR_MESSAGE;
      } finally {
        this.enabling = false;
      }
    },
  },
});
</script>

<template>
  <gl-modal
    :visible="visible"
    :modal-id="modalId"
    :title="title"
    :action-primary="primaryAction"
    :action-cancel="cancelAction"
    data-testid="orbit-turn-on-indexing-modal"
    @change="onChange"
    @primary.prevent="onPrimary"
    @hidden="onHidden"
  >
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      class="gl-mb-4"
      data-testid="orbit-turn-on-error"
      @dismiss="resetError"
    >
      {{ errorMessage }}
    </gl-alert>
    <p>
      {{
        s__(
          'Orbit|All content from this group, its subgroups, and projects will be indexed by GitLab Orbit. Your existing role-based access controls still apply. Users can access only the data they have permission to see in GitLab.',
        )
      }}
    </p>
    <p>
      <gl-sprintf
        :message="
          s__(
            'Orbit|%{boldStart}The initial scan can take some time depending on the amount of content.%{boldEnd} After that, updated content is automatically re-indexed. You can turn off GitLab Orbit at any time.',
          )
        "
      >
        <template #bold="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </p>
    <div class="gl-mt-5 gl-flex gl-flex-col gl-gap-2 gl-rounded-lg gl-bg-strong gl-p-4">
      <p class="gl-mb-0 gl-font-bold">{{ s__('Orbit|GitLab Orbit is in beta.') }}</p>
      <span>
        <gl-sprintf
          :message="
            s__(
              'Orbit|By turning on this feature, you accept the %{linkStart}GitLab Testing Agreement%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link
              href="https://handbook.gitlab.com/handbook/legal/testing-agreement/"
              target="_blank"
              rel="noopener noreferrer"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </span>
    </div>
  </gl-modal>
</template>
