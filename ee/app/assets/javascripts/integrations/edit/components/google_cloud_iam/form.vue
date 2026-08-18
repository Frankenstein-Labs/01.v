<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'GoogleCloudIAMForm',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    Configuration,
  },
  mixins: [glListenersMixin],
  props: {
    fields: {
      type: Array,
      required: true,
    },
    suggestedPoolId: {
      type: String,
      required: false,
      default: 'gitlab-wlif',
    },
    integrationLevel: {
      type: String,
      required: false,
      default: 'group',
    },
  },
  computed: {
    avoidCollisionMessage() {
      return this.integrationLevel === 'project'
        ? s__(
            'GoogleCloud|To avoid collisions, use unique IDs like this GitLab project ID: %{suggested}',
          )
        : s__(
            'GoogleCloud|To avoid collisions, use unique IDs like this GitLab group ID: %{suggested}',
          );
    },
    gcProjectFields() {
      return this.fields.filter((field) => field.name.includes('workload_identity_federation'));
    },
    workloadIdentityFields() {
      return this.fields.filter((field) => field.name.includes('workload_identity_pool'));
    },
  },
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mt-6">{{ s__('GoogleCloud|Google Cloud project') }}</h3>
    <p>
      <gl-sprintf
        :message="
          s__(
            'GoogleCloud|Project for the workload identity pool and provider. %{linkStart}Where are my project ID and project number?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link
            href="https://cloud.google.com/resource-manager/docs/creating-managing-projects#identifying_projects"
            target="_blank"
            >{{ content }}
            <gl-icon name="external-link" :aria-label="__('(external link)')" />
          </gl-link>
        </template>
      </gl-sprintf>
    </p>

    <configuration
      :fields="gcProjectFields"
      field-class="gl-grow gl-basis-0"
      class="gl-mb-4 gl-flex-row gl-gap-5 @md/panel:gl-flex"
      v-on="glListeners()"
    />

    <h3 class="gl-heading-3">{{ s__('GoogleCloud|Workload identity federation') }}</h3>
    <p>
      <gl-sprintf :message="avoidCollisionMessage">
        <template #suggested>
          <code>{{ suggestedPoolId }}</code>
        </template>
      </gl-sprintf>
    </p>

    <configuration
      :fields="workloadIdentityFields"
      field-class="gl-grow gl-basis-0"
      class="gl-mb-6 gl-flex-row gl-gap-5 @md/panel:gl-flex"
      v-on="glListeners()"
    />
  </div>
</template>
